#requires -Version 7.0
# SECURITY-PATTERN-FILE: Defensive Daten-, Pfad- und Secret-Muster; Eingaben werden nie ausgefuehrt.
Set-StrictMode -Version Latest

function Get-NightlyCanonicalRoot {
    return [IO.Path]::GetFullPath((Split-Path (Split-Path $PSScriptRoot -Parent) -Parent))
}

function Get-NightlyPolicy {
    $canonicalRoot = Get-NightlyCanonicalRoot
    $policyPath = Join-Path $canonicalRoot 'config/nightly-run.json'
    if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
        throw 'Nightly-Policy fehlt.'
    }
    $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
    if ($policy.schemaVersion -ne 1 -or $policy.'$schema' -ne './nightly-run.schema.json') {
        throw 'Nightly-Policy besitzt eine unbekannte Schema-Version.'
    }
    if ($policy.registrationStatus -ne 'READY_FOR_ACTIVATION' -or [bool]$policy.automaticExecutionEnabled) {
        throw 'Nightly-Policy erlaubt keinen sicheren Plan-only-Betrieb.'
    }
    if ($policy.projectKey -ne 'SchachTurnierManager' -or $policy.defaultBranch -ne 'development') {
        throw 'Nightly-Policy besitzt eine unbekannte Projekt- oder Branchbindung.'
    }
    if ($policy.checkpointRoot -ne 'output/nightly-runs' -or $policy.registrationOutputRoot -ne 'output/nightly-registration') {
        throw 'Nightly-Policy besitzt einen unbekannten Ausgabepfad.'
    }
    if ([int]$policy.maxResumeAttempts -lt 1 -or [int]$policy.maxResumeAttempts -gt 5 -or
        -not [bool]$policy.requireCleanWorktree -or -not [bool]$policy.requireExactBranch -or -not [bool]$policy.requireExactHead) {
        throw 'Nightly-Policy schwaecht eine Resume-Grenze ab.'
    }
    foreach ($property in 'gitMutationAllowed', 'networkMutationAllowed', 'schedulerMutationAllowed', 'externalWriteAllowed', 'automaticInstructionActivationAllowed') {
        if ([bool]$policy.controls.$property) { throw "Nightly-Control $property muss false bleiben." }
    }
    return $policy
}

function Assert-NightlyPathWithoutReparsePoint {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Boundary
    )

    $full = [IO.Path]::GetFullPath($Path)
    $limit = [IO.Path]::GetFullPath($Boundary)
    $prefix = $limit.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($full -ne $limit -and -not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Pfad liegt ausserhalb der erlaubten Repository-Grenze.'
    }
    $cursor = $full
    while ($cursor -and ($cursor -eq $limit -or $cursor.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase))) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw 'Pfad enthaelt einen Symlink oder Reparse-Point.'
        }
        if ($cursor -eq $limit) { break }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) { break }
        $cursor = $parent
    }
    return $full
}

function Resolve-NightlyRepositoryRoot {
    param([string]$RepositoryRoot)

    $canonicalRoot = Get-NightlyCanonicalRoot
    if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = $canonicalRoot }
    $full = Assert-NightlyPathWithoutReparsePoint -Path $RepositoryRoot -Boundary $canonicalRoot
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { throw 'RepositoryRoot fehlt.' }
    $gitRoot = @(& git -C $full rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $gitRoot.Count -eq 0) { throw 'RepositoryRoot ist kein Git-Arbeitsbaum.' }
    $verifiedRoot = [IO.Path]::GetFullPath(([string]$gitRoot[-1]).Trim())
    if ($verifiedRoot -ne $full) { throw 'RepositoryRoot stimmt nicht mit dem Git-Root ueberein.' }
    return $full
}

function Assert-NightlyDataSafe {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)

    $secretPattern = 'gh[pousr]_[0-9A-Za-z]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    $piiPattern = '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|\b(?:\+?49|0)[1-9][0-9][0-9\s()/.-]{6,}\b|\b(?:FIDE|DSB)[- ]?(?:ID)?\s*[:=]?\s*[0-9]{5,}\b'
    $absolutePathPattern = '(?i)[A-Za-z]:\\|/(?:home|Users)/[^/]+/'
    $blockedPhraseA = [string]::Concat('ign', 'ore') + '\s+(?:all|' + [string]::Concat('prev', 'ious') + ')'
    $blockedPhraseB = [string]::Concat('invoke-', 'expression')
    $blockedPhraseC = 'git\s+(?:push|reset|clean|commit|merge)'
    $blockedPhraseD = [string]::Concat('cu', 'rl') + '\s+https?://'
    $injectionPattern = "(?i)($blockedPhraseA|ignoriere\s+(?:alle|vorherige)|system\s*prompt|developer\s*message|fuehre\s+aus|execute\s*:|run\s*:|<script\b|$blockedPhraseB|$blockedPhraseC|remove-item\s+-recurse|$blockedPhraseD)"

    if ([string]::IsNullOrWhiteSpace($Value)) { throw "$Name darf nicht leer sein." }
    if ($Value -match '[\x00-\x08\x0B\x0C\x0E-\x1F]') { throw "$Name enthaelt Steuerzeichen." }
    if ($Value -match $secretPattern) { throw "$Name enthaelt ein Secret-Muster." }
    if ($Value -match $piiPattern) { throw "$Name enthaelt ein PII-Muster." }
    if ($Value -match $absolutePathPattern) { throw "$Name enthaelt einen absoluten Pfad." }
    if ($Value -match $injectionPattern) { throw "$Name enthaelt ein Befehls- oder Injection-Muster." }
    if ($Value -match '```|~~~') { throw "$Name enthaelt einen Code-Fence." }
}

function Get-NightlyGitState {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $branch = @(& git -C $RepositoryRoot branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0 -or $branch.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$branch[-1])) {
        throw 'Git-Branch ist nicht eindeutig verfuegbar.'
    }
    $head = @(& git -C $RepositoryRoot rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -ne 0 -or $head.Count -eq 0 -or ([string]$head[-1]).Trim() -cnotmatch '^[0-9a-f]{40}$') {
        throw 'Git-Head ist nicht eindeutig verfuegbar.'
    }
    $status = @(& git -C $RepositoryRoot status --porcelain=v1 --untracked-files=all 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Git-Status konnte nicht sicher gelesen werden.' }
    return [pscustomobject]@{
        Branch = ([string]$branch[-1]).Trim()
        HeadSha = ([string]$head[-1]).Trim()
        WorktreeClean = ($status.Count -eq 0)
    }
}

function Resolve-NightlyConfiguredRoot {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$RelativePath,
        [switch]$Create
    )

    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or $RelativePath -notmatch '^output/[a-z0-9-]+$') {
        throw 'Konfigurierter Nightly-Ausgabepfad ist unsicher.'
    }
    $full = Assert-NightlyPathWithoutReparsePoint -Path (Join-Path $RepositoryRoot $RelativePath) -Boundary (Get-NightlyCanonicalRoot)
    if ($Create) {
        [void](New-Item -ItemType Directory -Path $full -Force)
    }
    elseif (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw 'Konfigurierter Nightly-Ausgabepfad fehlt.'
    }
    [void](Assert-NightlyPathWithoutReparsePoint -Path $full -Boundary (Get-NightlyCanonicalRoot))
    return $full
}

function Get-NightlyCheckpointBinding {
    param([Parameter(Mandatory)]$Checkpoint)

    $canonicalCreatedAt = ([DateTimeOffset]$Checkpoint.createdAt).ToUniversalTime().ToString('o')
    $text = @(
        [string]$Checkpoint.schemaVersion,
        [string]$Checkpoint.checkpointId,
        [string]$Checkpoint.runId,
        [string]$Checkpoint.projectKey,
        [string]$Checkpoint.packageId,
        [string]$Checkpoint.phase,
        [string]$Checkpoint.status,
        $canonicalCreatedAt,
        [string]$Checkpoint.repository.branch,
        [string]$Checkpoint.repository.headSha,
        ([bool]$Checkpoint.repository.worktreeClean).ToString().ToLowerInvariant(),
        [string]$Checkpoint.progress.attempt,
        [string]$Checkpoint.progress.lastSuccessfulStep,
        [string]$Checkpoint.progress.nextAction,
        ([bool]$Checkpoint.controls.dataOnly).ToString().ToLowerInvariant(),
        ([bool]$Checkpoint.controls.networkUsed).ToString().ToLowerInvariant(),
        ([bool]$Checkpoint.controls.gitWritePerformed).ToString().ToLowerInvariant(),
        ([bool]$Checkpoint.controls.schedulerMutationPerformed).ToString().ToLowerInvariant(),
        ([bool]$Checkpoint.controls.externalWritePerformed).ToString().ToLowerInvariant()
    ) -join "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-NightlyRegistrationBinding {
    param([Parameter(Mandatory)]$Plan)

    $canonicalGeneratedAt = ([DateTimeOffset]$Plan.generatedAt).ToUniversalTime().ToString('o')
    $text = @(
        [string]$Plan.schemaVersion,
        [string]$Plan.registrationId,
        $canonicalGeneratedAt,
        [string]$Plan.status,
        [string]$Plan.projectKey,
        [string]$Plan.defaultBranch,
        [string]$Plan.checkpointRoot,
        [string]$Plan.consumerContract,
        [string]$Plan.source.branch,
        [string]$Plan.source.headSha,
        ([bool]$Plan.source.worktreeClean).ToString().ToLowerInvariant(),
        ([bool]$Plan.activationRequiresExplicitOwnerAction).ToString().ToLowerInvariant(),
        ([bool]$Plan.automaticExecutionEnabled).ToString().ToLowerInvariant(),
        ([bool]$Plan.controls.gitMutationAllowed).ToString().ToLowerInvariant(),
        ([bool]$Plan.controls.networkMutationAllowed).ToString().ToLowerInvariant(),
        ([bool]$Plan.controls.schedulerMutationAllowed).ToString().ToLowerInvariant(),
        ([bool]$Plan.controls.externalWriteAllowed).ToString().ToLowerInvariant(),
        ([bool]$Plan.controls.automaticInstructionActivationAllowed).ToString().ToLowerInvariant()
    ) -join "`n"
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}

function Write-NightlyAtomicJson {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Boundary
    )

    $safeDestination = Assert-NightlyPathWithoutReparsePoint -Path $Destination -Boundary $Boundary
    if (Test-Path -LiteralPath $safeDestination) { throw 'Nightly-Zieldatei existiert bereits.' }
    $temporary = "$safeDestination.tmp-$([Guid]::NewGuid().ToString('N'))"
    $moved = $false
    try {
        $utf8 = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 10) + "`n"), $utf8)
        Move-Item -LiteralPath $temporary -Destination $safeDestination
        $moved = $true
    }
    finally {
        if (-not $moved -and (Test-Path -LiteralPath $temporary -PathType Leaf)) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
    return $safeDestination
}

function Read-NightlyCheckpoint {
    param(
        [Parameter(Mandatory)][string]$CheckpointPath,
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)]$Policy
    )

    $checkpointRoot = Resolve-NightlyConfiguredRoot -RepositoryRoot $RepositoryRoot -RelativePath ([string]$Policy.checkpointRoot)
    $safePath = Assert-NightlyPathWithoutReparsePoint -Path $CheckpointPath -Boundary $checkpointRoot
    if (-not (Test-Path -LiteralPath $safePath -PathType Leaf)) { throw 'Checkpoint fehlt.' }
    $item = Get-Item -LiteralPath $safePath -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Checkpoint ist ein Symlink oder Reparse-Point.' }
    $checkpoint = Get-Content -LiteralPath $safePath -Raw | ConvertFrom-Json
    foreach ($property in 'schemaVersion', 'checkpointId', 'runId', 'projectKey', 'packageId', 'phase', 'status', 'createdAt', 'repository', 'progress', 'controls', 'bindingSha256') {
        if ($checkpoint.PSObject.Properties.Name -notcontains $property) { throw "Checkpoint-Feld $property fehlt." }
    }
    if ($checkpoint.schemaVersion -ne 1 -or $checkpoint.projectKey -ne $Policy.projectKey) { throw 'Checkpoint-Schema oder Projektbindung ist ungueltig.' }
    if ([string]$checkpoint.checkpointId -cnotmatch '^nightly-[0-9]{17}-[0-9a-f]{12}$' -or
        [string]$checkpoint.runId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$' -or
        [string]$checkpoint.packageId -cnotmatch '^STM-[A-Z]+-[0-9]{3}$' -or
        [string]$checkpoint.status -notin @('IN_PROGRESS', 'READY_TO_RESUME', 'COMPLETED', 'BLOCKED')) {
        throw 'Checkpoint-Identitaet oder Status ist ungueltig.'
    }
    $createdAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$checkpoint.createdAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$createdAt)) {
        throw 'Checkpoint-Zeitstempel ist ungueltig.'
    }
    if ([string]$checkpoint.repository.branch -cne [string]$Policy.defaultBranch -or
        [string]$checkpoint.repository.headSha -cnotmatch '^[0-9a-f]{40}$' -or
        -not [bool]$checkpoint.repository.worktreeClean -or
        [int]$checkpoint.progress.attempt -lt 0 -or [int]$checkpoint.progress.attempt -gt [int]$Policy.maxResumeAttempts) {
        throw 'Checkpoint-Git- oder Attempt-Bindung ist ungueltig.'
    }
    if ([string]$checkpoint.bindingSha256 -cne (Get-NightlyCheckpointBinding -Checkpoint $checkpoint)) { throw 'Checkpoint-Bindung ist ungueltig.' }
    if ($checkpoint.controls.PSObject.Properties.Name -notcontains 'command' -or $null -ne $checkpoint.controls.command -or
        -not [bool]$checkpoint.controls.dataOnly -or [bool]$checkpoint.controls.networkUsed -or [bool]$checkpoint.controls.gitWritePerformed -or [bool]$checkpoint.controls.schedulerMutationPerformed -or [bool]$checkpoint.controls.externalWritePerformed) {
        throw 'Checkpoint behauptet unzulaessige Seiteneffekte.'
    }
    foreach ($entry in @{ runId=$checkpoint.runId; packageId=$checkpoint.packageId; phase=$checkpoint.phase; lastSuccessfulStep=$checkpoint.progress.lastSuccessfulStep; nextAction=$checkpoint.progress.nextAction }.GetEnumerator()) {
        Assert-NightlyDataSafe -Name $entry.Key -Value ([string]$entry.Value)
    }
    return $checkpoint
}
