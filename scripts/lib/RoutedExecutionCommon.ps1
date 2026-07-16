#requires -Version 7.0
# SECURITY-PATTERN-FILE: Diese Bibliothek dokumentiert Erkennungs- und Redaktionsmuster
# fuer die Routed Execution. Enthaltene Muster sind Detektionsregeln, keine Secrets.
<#
.SYNOPSIS
Gemeinsame Funktionen fuer die providerübergreifende Routed Execution (STM-AI-005).

.DESCRIPTION
Alle Funktionen sind fail-closed: ungueltige Policies, Taskgraphen oder Checkpoints
fuehren zu terminierenden Fehlern. Child-Modell-Ausgaben werden ausschliesslich als
T3-Daten behandelt; nichts aus Child-Ausgaben wird als Instruktion interpretiert.
#>

Set-StrictMode -Version Latest

function Get-RoutedRepoRoot {
    $root = (& git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw 'Routed Execution benoetigt ein Git-Repository.'
    }
    return [IO.Path]::GetFullPath($root.Trim())
}

function Get-RoutedPolicy {
    param([string]$PolicyPath)
    if (-not $PolicyPath) {
        $PolicyPath = Join-Path (Get-RoutedRepoRoot) 'config/task-decomposition-policy.json'
    }
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        throw "Task-Decomposition-Policy fehlt: $PolicyPath"
    }
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    foreach ($key in @('schemaVersion', 'orchestratorProfiles', 'criticalCategories', 'maxDelegationDepth',
            'maxParallelWriters', 'requiredTaskFields', 'statusValues', 'defaults', 'integrationGate',
            'qualityEscalation', 'criticalFinalDecisionProfiles')) {
        if ($policy.PSObject.Properties.Name -notcontains $key) {
            throw "Task-Decomposition-Policy unvollstaendig: Schluessel '$key' fehlt."
        }
    }
    return $policy
}

function Get-ProviderRuntimePolicy {
    param([string]$PolicyPath)
    if (-not $PolicyPath) {
        $PolicyPath = Join-Path (Get-RoutedRepoRoot) 'config/provider-runtime-policy.json'
    }
    if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
        throw "Provider-Runtime-Policy fehlt: $PolicyPath"
    }
    $policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
    foreach ($key in @('schemaVersion', 'providerPreference', 'providers', 'safety', 'retry', 'classification')) {
        if ($policy.PSObject.Properties.Name -notcontains $key) {
            throw "Provider-Runtime-Policy unvollstaendig: Schluessel '$key' fehlt."
        }
    }
    if ($policy.safety.childrenMayCommit -or $policy.safety.childrenMayPush) {
        throw 'Provider-Runtime-Policy verletzt Arbeitssicherheit: Children duerfen nie committen oder pushen.'
    }
    return $policy
}

function Get-ProfileProvider {
    param(
        [Parameter(Mandatory)][psobject]$RuntimePolicy,
        [Parameter(Mandatory)][string]$ProfileId
    )
    foreach ($providerName in $RuntimePolicy.providers.PSObject.Properties.Name) {
        $provider = $RuntimePolicy.providers.$providerName
        if ($provider.profiles.PSObject.Properties.Name -contains $ProfileId) {
            return [pscustomobject]@{
                ProviderName = $providerName
                Provider     = $provider
                Model        = [string]$provider.profiles.$ProfileId.model
            }
        }
    }
    return $null
}

function Get-RoutedRedactionPatterns {
    # Redaktionsmuster leben bewusst in dieser SECURITY-PATTERN-FILE-Datei
    # (config/ darf laut GitCommitSafety keine Credential-Regexe tragen).
    # Zur Laufzeit zusammengesetzt, damit statische Scans sie nicht als Nutzlast werten.
    return @(
        ('(?i)(api' + '[_-]?key|access' + '[_-]?token|secret|passwor' + '[dt]|bearer)\s*[:=]\s*\S+'),
        ('https?://[^\s/]+:' + '[^\s@]+@'),
        ('(?i)gh' + 'p_[A-Za-z0-9]{20,}'),
        ('(?i)s' + 'k-[A-Za-z0-9-]{20,}')
    )
}

function Get-RedactedText {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][psobject]$RuntimePolicy
    )
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $redacted = $Text
    foreach ($pattern in (Get-RoutedRedactionPatterns)) {
        $redacted = [regex]::Replace($redacted, $pattern, '[REDACTED]')
    }
    $max = [int]$RuntimePolicy.safety.maxLoggedOutputChars
    if ($redacted.Length -gt $max) {
        $redacted = $redacted.Substring(0, $max) + "`n[TRUNCATED: $($Text.Length) Zeichen gesamt]"
    }
    return $redacted
}

function Get-RunnerOutputClassification {
    param(
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$ExitCode,
        [Parameter(Mandatory)][psobject]$RuntimePolicy,
        [switch]$TimedOut
    )
    if ($TimedOut) { return 'timeout' }
    $lower = ([string]$Text).ToLowerInvariant()
    foreach ($pattern in @($RuntimePolicy.classification.usageLimit)) {
        if ($lower.Contains($pattern.ToLowerInvariant())) { return 'usage-limit' }
    }
    foreach ($pattern in @($RuntimePolicy.classification.rateLimit)) {
        if ($lower.Contains($pattern.ToLowerInvariant())) { return 'rate-limit' }
    }
    foreach ($pattern in @($RuntimePolicy.classification.authError)) {
        if ($lower.Contains($pattern.ToLowerInvariant())) { return 'auth-error' }
    }
    if ($ExitCode -eq 0) { return 'ok' }
    return 'error'
}

function Test-ChildOutputInjectionSuspicion {
    <#
    .SYNOPSIS
    Prueft eine Child-Ausgabe (T3) heuristisch auf Prompt-Injection-Marker.
    Die Ausgabe wird nie ausgefuehrt; bei Verdacht wird sie quarantiniert.
    #>
    param([AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $suspicions = [System.Collections.Generic.List[string]]::new()
    # Marker werden zur Laufzeit zusammengesetzt, damit statische Scans dieser Datei
    # die Erkennungsregeln nicht als echte Injection-Nutzlast werten.
    $markers = @(
        ('ignore ' + 'all previous instructions'),
        ('ignore ' + 'previous instructions'),
        ('ignoriere ' + 'alle vorherigen anweisungen'),
        ('disregard ' + 'your instructions'),
        ('you are now ' + 'the orchestrator'),
        ('as the owner ' + 'i authorize'),
        ('run ' + 'git push --force'),
        ('delete ' + 'agents.md'),
        ('modify ' + 'trusted-instruction-paths'),
        ('add this to ' + 'agents.md'),
        ('persist this ' + 'as a skill'),
        ('reveal ' + 'your system prompt'),
        ('print ' + 'all secrets'),
        ('exfiltrate')
    )
    $lower = $Text.ToLowerInvariant()
    foreach ($marker in $markers) {
        if ($lower.Contains($marker)) { $suspicions.Add("marker:$marker") }
    }
    return @($suspicions)
}

function Test-RoutedTaskGraph {
    <#
    .SYNOPSIS
    Validiert einen Taskgraph fail-closed gegen die Task-Decomposition-Policy.
    Liefert eine Liste von Verletzungen (leer = gueltig).
    #>
    param(
        [Parameter(Mandatory)][psobject]$Graph,
        [Parameter(Mandatory)][psobject]$Policy
    )
    $violations = [System.Collections.Generic.List[string]]::new()

    foreach ($key in @('graphId', 'masterPrompt', 'orchestratorProfile', 'tasks')) {
        if ($Graph.PSObject.Properties.Name -notcontains $key) {
            $violations.Add("Graph-Schluessel fehlt: $key")
        }
    }
    if ($violations.Count -gt 0) { return @($violations) }

    if (@($Policy.orchestratorProfiles) -notcontains [string]$Graph.orchestratorProfile) {
        $violations.Add("Orchestrator-Profil '$($Graph.orchestratorProfile)' ist nicht zugelassen.")
    }

    $tasks = @($Graph.tasks)
    if ($tasks.Count -eq 0) {
        $violations.Add('Taskgraph enthaelt keine Aufgaben.')
        return @($violations)
    }

    $ids = @{}
    foreach ($task in $tasks) {
        foreach ($field in @($Policy.requiredTaskFields)) {
            if ($task.PSObject.Properties.Name -notcontains $field) {
                $violations.Add("Task '$($task.taskId)': Pflichtfeld '$field' fehlt.")
            }
        }
        $taskId = [string]$task.taskId
        if ($ids.ContainsKey($taskId)) { $violations.Add("Task-ID doppelt: $taskId") }
        $ids[$taskId] = $task
        if (@($Policy.statusValues) -notcontains [string]$task.status) {
            $violations.Add("Task '$taskId': ungueltiger Status '$($task.status)'.")
        }
        if ([int]$task.tokenBudget -le 0) { $violations.Add("Task '$taskId': Tokenbudget muss positiv sein.") }
        if ([int]$task.timeoutSeconds -le 0) { $violations.Add("Task '$taskId': Timeout muss positiv sein.") }
    }
    # Fail-closed: Bei fehlenden Pflichtfeldern keine Strukturpruefung auf unvollstaendigen Objekten.
    if ($violations.Count -gt 0) { return @($violations) }

    # Parent-Ketten: Existenz, keine Zyklen, Tiefenlimit.
    $maxDepth = [int]$Policy.maxDelegationDepth
    foreach ($task in $tasks) {
        $depth = 0
        $current = $task
        $seen = @{}
        while (-not [string]::IsNullOrEmpty([string]$current.parentId)) {
            $parentId = [string]$current.parentId
            if ($seen.ContainsKey([string]$current.taskId)) {
                $violations.Add("Delegationsschleife bei Task '$($task.taskId)'.")
                break
            }
            $seen[[string]$current.taskId] = $true
            if (-not $ids.ContainsKey($parentId)) {
                $violations.Add("Task '$($current.taskId)': Parent '$parentId' existiert nicht.")
                break
            }
            $current = $ids[$parentId]
            $depth++
            if ($depth -gt $maxDepth) {
                $violations.Add("Task '$($task.taskId)': Delegationstiefe > $maxDepth.")
                break
            }
        }
    }

    # Abhaengigkeiten: Existenz + Zyklenfreiheit (DFS).
    foreach ($task in $tasks) {
        foreach ($dep in @($task.dependsOn)) {
            if (-not $ids.ContainsKey([string]$dep)) {
                $violations.Add("Task '$($task.taskId)': Abhaengigkeit '$dep' existiert nicht.")
            }
        }
    }
    $visitState = @{}
    function Test-DependencyCycle {
        param([string]$TaskId, [hashtable]$Ids, [hashtable]$State, [System.Collections.Generic.List[string]]$Violations)
        if ($State[$TaskId] -eq 1) { $Violations.Add("Abhaengigkeitszyklus bei Task '$TaskId'."); return }
        if ($State[$TaskId] -eq 2) { return }
        $State[$TaskId] = 1
        foreach ($dep in @($Ids[$TaskId].dependsOn)) {
            if ($Ids.ContainsKey([string]$dep)) {
                Test-DependencyCycle -TaskId ([string]$dep) -Ids $Ids -State $State -Violations $Violations
            }
        }
        $State[$TaskId] = 2
    }
    foreach ($taskId in $ids.Keys) {
        if (-not $visitState.ContainsKey($taskId)) {
            Test-DependencyCycle -TaskId $taskId -Ids $ids -State $visitState -Violations $violations
        }
    }

    # Dateiscope-Locks: schreibende Tasks duerfen sich keine Dateien teilen.
    $writerTasks = @($tasks | Where-Object {
            $isReadOnly = ($_.PSObject.Properties.Name -contains 'readOnly') -and [bool]$_.readOnly
            (@($_.allowedFiles).Count -gt 0) -and -not $isReadOnly
        })
    for ($i = 0; $i -lt $writerTasks.Count; $i++) {
        for ($j = $i + 1; $j -lt $writerTasks.Count; $j++) {
            $overlap = @(@($writerTasks[$i].allowedFiles) | Where-Object { @($writerTasks[$j].allowedFiles) -contains $_ })
            if ($overlap.Count -gt 0) {
                $violations.Add("Dateikollision zwischen '$($writerTasks[$i].taskId)' und '$($writerTasks[$j].taskId)': $($overlap -join ', ')")
            }
        }
    }

    # Kritische Kategorien: Finalentscheidung nur durch zugelassene Profile, kein Downgrade.
    foreach ($task in $tasks) {
        if (@($Policy.criticalCategories) -contains [string]$task.category) {
            if (@($Policy.criticalFinalDecisionProfiles) -notcontains [string]$task.reviewer) {
                $violations.Add("Task '$($task.taskId)' (kritisch: $($task.category)): Reviewer '$($task.reviewer)' ist nicht als Finalentscheider zugelassen.")
            }
        }
    }

    return @($violations)
}

function Get-TaskGraphHash {
    param([Parameter(Mandatory)][psobject]$Graph)
    $json = $Graph | ConvertTo-Json -Depth 16 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Write-RoutedCheckpoint {
    param(
        [Parameter(Mandatory)][string]$CheckpointPath,
        [Parameter(Mandatory)][psobject]$Graph,
        [Parameter(Mandatory)][string]$GraphHash,
        [Parameter(Mandatory)][string]$RunStatus,
        [string]$Reason = ''
    )
    $repoRoot = Get-RoutedRepoRoot
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
    $head = (& git rev-parse HEAD 2>$null)
    $checkpoint = [ordered]@{
        schemaVersion = 1
        kind          = 'routed-execution-checkpoint'
        createdUtc    = [DateTime]::UtcNow.ToString('o')
        repoRoot      = $repoRoot
        branch        = [string]$branch
        head          = [string]$head
        # Bindung an den aktuellen (mutierten) Graphzustand; Herkunftsgraph separat.
        graphHash     = (Get-TaskGraphHash -Graph $Graph)
        originalGraphHash = $GraphHash
        runStatus     = $RunStatus
        reason        = $Reason
        resumeAttempts = 0
        graph         = $Graph
    }
    if (Test-Path -LiteralPath $CheckpointPath -PathType Leaf) {
        $existing = Get-Content -LiteralPath $CheckpointPath -Raw | ConvertFrom-Json
        if ($existing.PSObject.Properties.Name -contains 'resumeAttempts') {
            $checkpoint.resumeAttempts = [int]$existing.resumeAttempts
        }
    }
    $dir = Split-Path -Parent $CheckpointPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $temp = "$CheckpointPath.tmp"
    ($checkpoint | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $temp -Encoding utf8NoBOM
    Move-Item -LiteralPath $temp -Destination $CheckpointPath -Force
}

function Read-RoutedCheckpoint {
    param(
        [Parameter(Mandatory)][string]$CheckpointPath,
        [int]$MaxResumeAttempts = 3,
        [switch]$SkipHeadValidation
    )
    if (-not (Test-Path -LiteralPath $CheckpointPath -PathType Leaf)) {
        throw "Checkpoint fehlt: $CheckpointPath"
    }
    $checkpoint = Get-Content -LiteralPath $CheckpointPath -Raw | ConvertFrom-Json
    foreach ($key in @('schemaVersion', 'kind', 'repoRoot', 'branch', 'head', 'graphHash', 'runStatus', 'graph', 'resumeAttempts')) {
        if ($checkpoint.PSObject.Properties.Name -notcontains $key) {
            throw "Checkpoint ungueltig: Schluessel '$key' fehlt."
        }
    }
    if ([string]$checkpoint.kind -ne 'routed-execution-checkpoint') {
        throw 'Checkpoint hat einen unerwarteten Typ.'
    }
    $actualHash = Get-TaskGraphHash -Graph $checkpoint.graph
    if ($actualHash -ne [string]$checkpoint.graphHash) {
        throw 'Checkpoint-Bindung verletzt: Graph-Hash stimmt nicht (Manipulation oder Drift).'
    }
    if ([int]$checkpoint.resumeAttempts -ge $MaxResumeAttempts) {
        throw "Resume-Limit erreicht ($($checkpoint.resumeAttempts) Versuche)."
    }
    $repoRoot = Get-RoutedRepoRoot
    if ([IO.Path]::GetFullPath([string]$checkpoint.repoRoot) -ne $repoRoot) {
        throw 'Checkpoint gehoert zu einem anderen Repository.'
    }
    if (-not $SkipHeadValidation) {
        $branch = ([string](& git rev-parse --abbrev-ref HEAD 2>$null)).Trim()
        if ($branch -ne ([string]$checkpoint.branch).Trim()) {
            throw "Checkpoint-Branch '$($checkpoint.branch)' weicht vom aktuellen Branch '$branch' ab."
        }
    }
    return $checkpoint
}

function Get-EscalationTarget {
    param(
        [Parameter(Mandatory)][psobject]$Policy,
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$CurrentProfile
    )
    $order = @($Policy.qualityEscalation.escalationOrder.$Provider)
    if ($order.Count -eq 0) { return $null }
    $index = [Array]::IndexOf($order, $CurrentProfile)
    if ($index -lt 0 -or $index -ge ($order.Count - 1)) { return $null }
    return [string]$order[$index + 1]
}

function Test-IntegrationApproval {
    <#
    .SYNOPSIS
    Integration-Gate: Nur geprueft-freigegebene, nicht quarantinierte Ergebnisse
    duerfen integriert werden. Child-Output wird nie Instruktionsquelle.
    #>
    param(
        [Parameter(Mandatory)][psobject]$Task,
        [Parameter(Mandatory)][psobject]$Policy
    )
    $reasons = [System.Collections.Generic.List[string]]::new()
    if ([string]$Task.status -eq 'QUARANTINED' -or [string]$Task.status -eq 'REJECTED') {
        $reasons.Add('Quarantinierte oder abgelehnte Ergebnisse duerfen nie integriert werden.')
    }
    if ([string]$Task.status -ne 'COMPLETED') {
        $reasons.Add("Nur COMPLETED-Ergebnisse sind integrierbar (Status: $($Task.status)).")
    }
    $reviewedBy = ''
    if ($Task.PSObject.Properties.Name -contains 'reviewedBy') { $reviewedBy = [string]$Task.reviewedBy }
    if ([string]::IsNullOrWhiteSpace($reviewedBy)) {
        $reasons.Add('Ergebnis ist nicht durch einen Reviewer freigegeben.')
    }
    elseif (@($Policy.criticalCategories) -contains [string]$Task.category -and
        @($Policy.criticalFinalDecisionProfiles) -notcontains $reviewedBy) {
        $reasons.Add("Kritische Kategorie '$($Task.category)' verlangt Finalreview durch $($Policy.criticalFinalDecisionProfiles -join '/').")
    }
    return [pscustomobject]@{
        Approved = ($reasons.Count -eq 0)
        Reasons  = @($reasons)
    }
}

function Invoke-ExternalRunner {
    <#
    .SYNOPSIS
    Startet einen nichtinteraktiven CLI-Runner als kontrollierten Unterprozess im
    bestehenden Terminal (kein neues Fenster), mit Prompt via stdin und hartem Timeout.
    #>
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][AllowEmptyString()][string]$PromptText,
        [Parameter(Mandatory)][int]$TimeoutSeconds
    )
    $command = Get-Command $Executable -ErrorAction SilentlyContinue
    if ($null -eq $command) { throw "Runner nicht gefunden: $Executable" }
    $exePath = $command.Source
    # npm-Shims (.ps1/.cmd) ueber die zugehoerige .cmd-Datei starten.
    if ($exePath -like '*.ps1') {
        $cmdShim = [IO.Path]::ChangeExtension($exePath, '.cmd')
        if (Test-Path -LiteralPath $cmdShim) { $exePath = $cmdShim }
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $exePath
    foreach ($arg in $Arguments) { $psi.ArgumentList.Add($arg) }
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($PromptText)
    $process.StandardInput.Close()

    $timedOut = $false
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timedOut = $true
        try { $process.Kill($true) } catch { }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $process.Dispose()

    return [pscustomobject]@{
        ExitCode = $exitCode
        StdOut   = $stdout
        StdErr   = $stderr
        TimedOut = $timedOut
    }
}

function Get-RetryDelaySeconds {
    param(
        [Parameter(Mandatory)][psobject]$RuntimePolicy,
        [Parameter(Mandatory)][int]$Attempt,
        [AllowEmptyString()][string]$RunnerOutput = ''
    )
    if ($RuntimePolicy.retry.respectRetryAfter -and $RunnerOutput -match '(?i)retry[- ]after[:\s]+(\d{1,5})') {
        return [int]$Matches[1]
    }
    $base = [double]$RuntimePolicy.retry.baseDelaySeconds
    $factor = [double]$RuntimePolicy.retry.backoffFactor
    $jitter = Get-Random -Minimum 0 -Maximum ([int]$RuntimePolicy.retry.jitterSeconds + 1)
    return [int]([math]::Ceiling($base * [math]::Pow($factor, $Attempt - 1)) + $jitter)
}
