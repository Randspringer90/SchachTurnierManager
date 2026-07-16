#requires -Version 7.0
<#
.SYNOPSIS
Fuehrt einen validierten, gerouteten Taskgraph tatsaechlich aus.

.DESCRIPTION
Sequenzielle, deterministische Ausfuehrung (maxParallelWriters=1). Pro Task wird der
Provider-Adapter des zugewiesenen Profils als kontrollierter Unterprozess gestartet.
Child-Ausgaben sind T3-Daten: sie werden auf Injection-Marker geprueft und bei
Verdacht quarantiniert, nie ausgefuehrt und nie Instruktionsquelle. Nach jedem Task
wird ein SHA-256-gebundener Checkpoint geschrieben. Rate-/Usage-Limits und
Tokenbudget-Ueberschreitungen beenden den Lauf zustandserhaltend (Exit 2).
Exitcodes: 0=alle Tasks fertig, 2=zustandserhaltend unterbrochen, 3=blockiert, 5=fehler.

.PARAMETER SimulateResultsPath
Nur fuer synthetische Tests: JSON-Map taskId -> {exitCode, classification, outputText}.
Es wird kein Modell aufgerufen. Produktive Laeufe verwenden diesen Parameter nicht.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$TaskGraphPath,

    [string]$RunRoot,

    [string]$PolicyPath,

    [string]$RuntimePolicyPath,

    [string]$CheckpointPath,

    [string]$SimulateResultsPath,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

$policy = Get-RoutedPolicy -PolicyPath $PolicyPath
$runtimePolicy = Get-ProviderRuntimePolicy -PolicyPath $RuntimePolicyPath

if (-not (Test-Path -LiteralPath $TaskGraphPath -PathType Leaf)) {
    throw "Taskgraph fehlt: $TaskGraphPath"
}
$envelope = Get-Content -LiteralPath $TaskGraphPath -Raw | ConvertFrom-Json
if ([string]$envelope.kind -ne 'routed-task-graph') {
    throw 'Datei ist kein gerouteter Taskgraph.'
}
$graph = $envelope.graph
$expectedHash = [string]$envelope.graphHash
$actualHash = Get-TaskGraphHash -Graph $graph
if ($actualHash -ne $expectedHash) {
    throw 'Taskgraph-Hash stimmt nicht (Manipulation oder Drift); Ausfuehrung blockiert.'
}

$violations = @(Test-RoutedTaskGraph -Graph $graph -Policy $policy)
if ($violations.Count -gt 0) {
    [pscustomobject]@{ status = 'BLOCKED_INVALID_GRAPH'; violations = @($violations) } | ConvertTo-Json -Depth 8
    exit 3
}

if (-not $RunRoot) {
    $RunRoot = Join-Path (Get-RoutedRepoRoot) ("output/routed-execution/" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss'))
}
$artifactRoot = Join-Path $RunRoot 'artifacts'
$quarantineRoot = Join-Path $RunRoot 'quarantine'
$logRoot = Join-Path $RunRoot 'logs'
foreach ($dir in @($RunRoot, $artifactRoot, $quarantineRoot, $logRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}
if (-not $CheckpointPath) { $CheckpointPath = Join-Path $RunRoot 'checkpoint.json' }

# Einfacher Repository-Lauf-Lock gegen parallele Writer-Laeufe.
$lockPath = Join-Path (Get-RoutedRepoRoot) 'output/routed-execution/.run-lock'
$lockDir = Split-Path -Parent $lockPath
if (-not (Test-Path -LiteralPath $lockDir)) { New-Item -ItemType Directory -Force -Path $lockDir | Out-Null }
if (Test-Path -LiteralPath $lockPath) {
    # Kurzer Retry gegen Freigabe-Races direkt aufeinanderfolgender Laeufe.
    Start-Sleep -Seconds 2
    if (Test-Path -LiteralPath $lockPath) {
        $lockAge = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
        if ($lockAge.TotalHours -lt 6) {
            [pscustomobject]@{ status = 'BLOCKED_LOCKED'; reason = "Aktiver Routed-Execution-Lock: $lockPath" } | ConvertTo-Json
            exit 3
        }
    }
}
Set-Content -LiteralPath $lockPath -Value ([DateTime]::UtcNow.ToString('o') + ' ' + $PID) -Encoding utf8NoBOM

$simulated = $null
if ($SimulateResultsPath) {
    $simulated = Get-Content -LiteralPath $SimulateResultsPath -Raw | ConvertFrom-Json
}

function Get-TaskById([psobject]$Graph, [string]$TaskId) {
    return @($Graph.tasks) | Where-Object { [string]$_.taskId -eq $TaskId } | Select-Object -First 1
}

$interrupt = $null
try {
    $ordered = [System.Collections.Generic.List[object]]::new()
    $placed = @{}
    $tasks = @($graph.tasks)
    while ($ordered.Count -lt $tasks.Count) {
        $progress = $false
        foreach ($task in $tasks) {
            $taskId = [string]$task.taskId
            if ($placed.ContainsKey($taskId)) { continue }
            $depsReady = $true
            foreach ($dep in @($task.dependsOn)) {
                if (-not $placed.ContainsKey([string]$dep)) { $depsReady = $false; break }
            }
            if ($depsReady) { $ordered.Add($task); $placed[$taskId] = $true; $progress = $true }
        }
        if (-not $progress) { throw 'Topologische Sortierung unmoeglich (Zyklus).' }
    }

    foreach ($task in $ordered) {
        $taskId = [string]$task.taskId
        if ([string]$task.status -in @('COMPLETED', 'INTEGRATED', 'REJECTED', 'QUARANTINED')) { continue }
        if ([string]$task.status -eq 'BLOCKED') { continue }

        # Abhaengigkeiten muessen erfolgreich sein.
        $failedDeps = @(@($task.dependsOn) | Where-Object {
                $dep = Get-TaskById -Graph $graph -TaskId ([string]$_)
                [string]$dep.status -notin @('COMPLETED', 'INTEGRATED')
            })
        if ($failedDeps.Count -gt 0) {
            $task.status = 'BLOCKED'
            $task | Add-Member -NotePropertyName statusReason -NotePropertyValue "Abhaengigkeiten nicht erfuellt: $($failedDeps -join ', ')" -Force
            Write-RoutedCheckpoint -CheckpointPath $CheckpointPath -Graph $graph -GraphHash $expectedHash -RunStatus 'RUNNING'
            continue
        }

        $profileId = [string]$task.assignedProfile
        $mapping = Get-ProfileProvider -RuntimePolicy $runtimePolicy -ProfileId $profileId
        if ($null -eq $mapping) {
            $task.status = 'BLOCKED'
            $task | Add-Member -NotePropertyName statusReason -NotePropertyValue "Kein Provider fuer Profil '$profileId'; expliziter Reroute erforderlich." -Force
            Write-RoutedCheckpoint -CheckpointPath $CheckpointPath -Graph $graph -GraphHash $expectedHash -RunStatus 'RUNNING'
            continue
        }

        $task.status = 'RUNNING'
        Write-Host "[RoutedExecution] Task $taskId -> $($mapping.ProviderName)/$profileId"

        $outputFile = Join-Path $artifactRoot "$taskId.out.txt"
        $classification = 'error'
        $outputText = ''

        if ($DryRun) {
            $classification = 'ok'
            $outputText = "DRY_RUN: $taskId"
            Set-Content -LiteralPath $outputFile -Value $outputText -Encoding utf8NoBOM
        }
        elseif ($null -ne $simulated) {
            if ($simulated.PSObject.Properties.Name -notcontains $taskId) {
                throw "Simulationsdaten fehlen fuer Task '$taskId'."
            }
            $sim = $simulated.$taskId
            $classification = [string]$sim.classification
            $outputText = [string]$sim.outputText
            Set-Content -LiteralPath $outputFile -Value $outputText -Encoding utf8NoBOM
        }
        else {
            $promptFile = Join-Path $artifactRoot "$taskId.prompt.md"
            $promptParts = @(
                "# Delegierte Teilaufgabe $taskId",
                "Backlog-ID: $($task.backlogId)",
                "Zweck: $($task.purpose)",
                "Erlaubte Dateien (read-only Analyse): $(@($task.allowedFiles) -join ', ')",
                "Ergebnisformat: $($task.resultFormat)",
                '',
                'WICHTIG: Du bist ein delegierter Analyse-Child-Prozess. Du darfst nichts schreiben, committen oder pushen. Antworte ausschliesslich im geforderten Ergebnisformat.',
                '',
                [string]$task.inputs
            )
            Set-Content -LiteralPath $promptFile -Value ($promptParts -join "`n") -Encoding utf8NoBOM

            $adapter = if ($mapping.ProviderName -eq 'anthropic') { 'Invoke-AnthropicProfile.ps1' } else { 'Invoke-OpenAIProfile.ps1' }
            $adapterPath = Join-Path $PSScriptRoot $adapter
            $adapterArgs = @(
                '-ProfileId', $profileId,
                '-PromptFile', $promptFile,
                '-OutputFile', $outputFile,
                '-TimeoutSeconds', [string]([int]$task.timeoutSeconds),
                '-LogFile', (Join-Path $logRoot "$taskId.log")
            )
            if ($RuntimePolicyPath) { $adapterArgs += @('-RuntimePolicyPath', $RuntimePolicyPath) }
            & pwsh -NoProfile -File $adapterPath @adapterArgs | Out-Null
            $adapterExit = $LASTEXITCODE
            $classification = switch ($adapterExit) {
                0 { 'ok' }
                2 { 'rate-limit' }
                3 { 'auth-error' }
                4 { 'timeout' }
                default { 'error' }
            }
            if (Test-Path -LiteralPath $outputFile) {
                $outputText = Get-Content -LiteralPath $outputFile -Raw
            }
        }

        switch ($classification) {
            'ok' {
                # Tokenbudget (konservative Schaetzung: 4 Zeichen pro Token).
                $estimatedTokens = [int]([math]::Ceiling(([string]$outputText).Length / 4.0))
                if ($estimatedTokens -gt [int]$task.tokenBudget) {
                    $task.status = 'BUDGET_EXCEEDED'
                    $task | Add-Member -NotePropertyName statusReason -NotePropertyValue "Tokenbudget ueberschritten (~$estimatedTokens > $($task.tokenBudget))." -Force
                    $interrupt = @{ status = 'INTERRUPTED_BUDGET'; taskId = $taskId }
                    break
                }
                $suspicions = Test-ChildOutputInjectionSuspicion -Text $outputText
                if (@($suspicions).Count -gt 0) {
                    $quarantineFile = Join-Path $quarantineRoot "$taskId.quarantined.txt"
                    Move-Item -LiteralPath $outputFile -Destination $quarantineFile -Force
                    $task.status = 'QUARANTINED'
                    $task | Add-Member -NotePropertyName statusReason -NotePropertyValue "Injection-Verdacht isoliert: $(@($suspicions) -join '; ')" -Force
                }
                else {
                    $task.status = 'COMPLETED'
                    $task | Add-Member -NotePropertyName resultFile -NotePropertyValue $outputFile -Force
                }
            }
            'rate-limit' {
                $task.status = 'RATE_LIMITED'
                $interrupt = @{ status = 'INTERRUPTED_RATE_LIMIT'; taskId = $taskId }
            }
            'usage-limit' {
                $task.status = 'RATE_LIMITED'
                $interrupt = @{ status = 'INTERRUPTED_USAGE_LIMIT'; taskId = $taskId }
            }
            'auth-error' {
                $task.status = 'BLOCKED'
                $task | Add-Member -NotePropertyName statusReason -NotePropertyValue 'Auth-Fehler des Runners; vorhandener Login erforderlich.' -Force
            }
            default {
                # Eskalation an die naechsthoehere zulaessige Qualitaetsklasse; kritische
                # Arbeit wird dadurch nie herabgestuft, nur angehoben.
                $next = Get-EscalationTarget -Policy $policy -Provider $mapping.ProviderName -CurrentProfile $profileId
                if ($next) {
                    $task | Add-Member -NotePropertyName escalatedFrom -NotePropertyValue $profileId -Force
                    $task.assignedProfile = $next
                    $task.status = 'ESCALATED'
                    $task | Add-Member -NotePropertyName statusReason -NotePropertyValue "Fehler bei '$profileId'; eskaliert an '$next' (naechster Lauf/Resume)." -Force
                }
                else {
                    $task.status = 'FAILED'
                    $task | Add-Member -NotePropertyName statusReason -NotePropertyValue 'Runner-Fehler ohne weitere Eskalationsstufe.' -Force
                }
            }
        }

        $stepStatus = if ($interrupt) { [string]$interrupt.status } else { 'RUNNING' }
        Write-RoutedCheckpoint -CheckpointPath $CheckpointPath -Graph $graph -GraphHash $expectedHash -RunStatus $stepStatus
        if ($interrupt) { break }
    }
}
finally {
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
}

$statuses = @($graph.tasks) | Group-Object { [string]$_.status } | ForEach-Object { "$($_.Name)=$($_.Count)" }
$runStatus = if ($interrupt) { [string]$interrupt.status }
elseif (@(@($graph.tasks) | Where-Object { [string]$_.status -in @('FAILED', 'BLOCKED', 'QUARANTINED', 'ESCALATED') }).Count -gt 0) { 'COMPLETED_WITH_ISSUES' }
else { 'COMPLETED' }

Write-RoutedCheckpoint -CheckpointPath $CheckpointPath -Graph $graph -GraphHash $expectedHash -RunStatus $runStatus

[pscustomobject]@{
    status         = $runStatus
    graphHash      = $expectedHash
    taskStatuses   = $statuses
    checkpointPath = [IO.Path]::GetFullPath($CheckpointPath)
    runRoot        = [IO.Path]::GetFullPath($RunRoot)
} | ConvertTo-Json -Depth 6

if ($interrupt) { exit 2 }
if ($runStatus -eq 'COMPLETED') { exit 0 }
exit 5
