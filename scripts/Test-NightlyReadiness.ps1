#requires -Version 7.0
# SECURITY-PATTERN-FILE: Synthetische Negativ-Fixtures werden fragmentiert erzeugt und nie als Anweisung verwendet.
<#
.SYNOPSIS
Prueft Policy, Checkpoint-Bindung, Resume-Drift und nicht aktivierende Registrierung.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$policyPath = Join-Path $repo 'config/nightly-run.json'
$schemaPath = Join-Path $repo 'config/nightly-run.schema.json'
$checkpointScript = Join-Path $repo 'scripts/New-NightlyCheckpoint.ps1'
$resumeScript = Join-Path $repo 'scripts/Get-NightlyResumePlan.ps1'
$registrationScript = Join-Path $repo 'scripts/New-NightlyRegistrationPlan.ps1'
$commonScript = Join-Path $repo 'scripts/lib/NightlyResumeCommon.ps1'
$testRoot = Join-Path $repo ("output/nightly-readiness/{0}-{1}" -f $PID, [Guid]::NewGuid().ToString('N'))
$syntheticRepo = Join-Path $testRoot 'synthetic-repository'
$failures = [Collections.Generic.List[string]]::new()
$caseCount = 0

function Check {
    param([bool]$Condition, [string]$Message)
    $script:caseCount++
    if ($Condition) { Write-Host "OK  : $Message" }
    else { $script:failures.Add($Message); Write-Host "FAIL: $Message" }
}

function Invoke-Rejected {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Action)
    $rejected = $false
    try { [void](& $Action) } catch { $rejected = $true }
    Check $rejected "$Name wird fail-closed abgelehnt"
}

function Get-InstructionDigest {
    $files = @(
        Get-Item -LiteralPath (Join-Path $repo 'AGENTS.md')
        Get-Item -LiteralPath (Join-Path $repo 'config/trusted-instruction-paths.json')
        Get-Item -LiteralPath (Join-Path $repo 'config/nightly-run.json')
    ) | Sort-Object FullName -Unique
    return (($files | ForEach-Object { "$($_.Name)=$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" }) -join "`n")
}

foreach ($path in @($policyPath, $schemaPath, $checkpointScript, $resumeScript, $registrationScript, $commonScript)) {
    Check (Test-Path -LiteralPath $path -PathType Leaf) "$(Split-Path $path -Leaf) vorhanden"
}

$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
Check ($policy.schemaVersion -eq 1) 'Policy-SchemaVersion ist 1'
Check ($policy.'$schema' -eq './nightly-run.schema.json') 'Policy referenziert lokales Schema'
Check ($schema.'$schema' -eq 'https://json-schema.org/draft/2020-12/schema') 'Schema ist Draft 2020-12'
Check ($policy.registrationStatus -eq 'READY_FOR_ACTIVATION') 'Registrierung bleibt aktivierungsbereit'
Check (-not [bool]$policy.automaticExecutionEnabled) 'Automatische Ausfuehrung ist deaktiviert'
Check ($policy.defaultBranch -eq 'development') 'Development ist exakter Nightly-Branch'
Check ($policy.checkpointRoot -eq 'output/nightly-runs') 'Checkpoints bleiben im ignorierten Output'
Check ([int]$policy.maxResumeAttempts -ge 1 -and [int]$policy.maxResumeAttempts -le 5) 'Resume-Versuche sind begrenzt'
foreach ($control in 'gitMutationAllowed', 'networkMutationAllowed', 'schedulerMutationAllowed', 'externalWriteAllowed', 'automaticInstructionActivationAllowed') {
    Check (-not [bool]$policy.controls.$control) "Control $control ist false"
}

$productionSource = (Get-Content -Raw $checkpointScript), (Get-Content -Raw $resumeScript), (Get-Content -Raw $registrationScript), (Get-Content -Raw $commonScript) -join "`n"
$mutationNames = @(
    [string]::Concat('Register-', 'ScheduledTask'),
    [string]::Concat('New-', 'ScheduledTask'),
    [string]::Concat('Start-', 'Process'),
    [string]::Concat('Invoke-', 'WebRequest'),
    [string]::Concat('Invoke-', 'RestMethod')
)
foreach ($mutationName in $mutationNames) {
    Check ($productionSource -notmatch [regex]::Escape($mutationName)) "Produktivpfad enthaelt kein $mutationName"
}
Check ($productionSource -notmatch '(?i)&\s*git\s+[^\r\n]*(?:add|commit|push|merge|switch|checkout|tag|reset|clean)\b') 'Produktivpfad besitzt keine mutierende Git-Aktion'

$instructionBefore = Get-InstructionDigest
[void](New-Item -ItemType Directory -Path $syntheticRepo -Force)
try {
    & git init --initial-branch=development -- $syntheticRepo 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetisches Git-Repository konnte nicht initialisiert werden.' }
    [IO.File]::WriteAllText((Join-Path $syntheticRepo '.gitignore'), "output/`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $syntheticRepo 'README.md'), "synthetic nightly readiness`n", [Text.UTF8Encoding]::new($false))
    & git -C $syntheticRepo add -- .gitignore README.md
    if ($LASTEXITCODE -ne 0) { throw 'Synthetische Dateien konnten nicht gestaged werden.' }
    & git -C $syntheticRepo -c user.name=NightlyReadiness -c user.email=nightly-readiness@example.invalid -c commit.gpgsign=false commit -m 'synthetic baseline' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetischer Baseline-Commit fehlgeschlagen.' }

    $result = & $checkpointScript `
        -RunId 'nightly-readiness' `
        -PackageId 'STM-AI-004' `
        -Phase 'Readiness' `
        -Status READY_TO_RESUME `
        -LastSuccessfulStep 'Synthetic baseline committed' `
        -NextAction 'Validate the bounded resume plan' `
        -Attempt 1 `
        -RepositoryRoot $syntheticRepo

    Check ($result.Status -eq 'CHECKPOINT_CREATED') 'Sauberer synthetischer Lauf erzeugt Checkpoint'
    Check ($result.SideEffects -eq 'LOCAL_DATA_WRITE_ONLY') 'Checkpoint meldet nur lokale Datenschreibwirkung'
    Check (Test-Path -LiteralPath $result.CheckpointPath -PathType Leaf) 'Checkpoint-Datei ist vorhanden'
    $checkpointRoot = [IO.Path]::GetFullPath((Join-Path $syntheticRepo $policy.checkpointRoot))
    $checkpointFull = [IO.Path]::GetFullPath($result.CheckpointPath)
    Check ($checkpointFull.StartsWith(($checkpointRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)) 'Checkpoint liegt im konfigurierten Output'

    $checkpoint = Get-Content -LiteralPath $result.CheckpointPath -Raw | ConvertFrom-Json
    Check ($checkpoint.repository.branch -eq 'development') 'Checkpoint bindet development'
    Check ([string]$checkpoint.repository.headSha -cmatch '^[0-9a-f]{40}$') 'Checkpoint bindet exakten Head'
    Check ([bool]$checkpoint.repository.worktreeClean) 'Checkpoint bestaetigt sauberen Arbeitsbaum'
    Check ([bool]$checkpoint.controls.dataOnly) 'Checkpoint bleibt Daten'
    Check ($null -eq $checkpoint.controls.command) 'Checkpoint enthaelt kein Kommando'
    Check (-not [bool]$checkpoint.controls.networkUsed -and -not [bool]$checkpoint.controls.gitWritePerformed -and -not [bool]$checkpoint.controls.schedulerMutationPerformed -and -not [bool]$checkpoint.controls.externalWritePerformed) 'Checkpoint bestaetigt keine verbotenen Seiteneffekte'

    $plan = & $resumeScript -CheckpointPath $result.CheckpointPath -RepositoryRoot $syntheticRepo
    Check ($plan.Decision -eq 'READY_TO_RESUME') 'Unveraenderter Checkpoint ist resume-bereit'
    Check ($null -eq $plan.Command) 'Resume-Plan enthaelt kein Kommando'
    Check (-not [bool]$plan.InstructionActivated -and -not [bool]$plan.NetworkUsed -and -not [bool]$plan.GitWritePerformed -and -not [bool]$plan.SchedulerMutationPerformed -and -not [bool]$plan.ExternalWritePerformed) 'Resume-Plan bleibt seiteneffektfrei'

    $tamperedPath = Join-Path $checkpointRoot 'tampered.json'
    $tampered = Get-Content -LiteralPath $result.CheckpointPath -Raw | ConvertFrom-Json
    $tampered.progress.nextAction = 'Tampered next action'
    [IO.File]::WriteAllText($tamperedPath, (($tampered | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
    Invoke-Rejected -Name 'Manipulierte Checkpoint-Bindung' -Action { & $resumeScript -CheckpointPath $tamperedPath -RepositoryRoot $syntheticRepo }
    Remove-Item -LiteralPath $tamperedPath -Force

    [IO.File]::WriteAllText((Join-Path $syntheticRepo 'dirty.txt'), "dirty`n", [Text.UTF8Encoding]::new($false))
    $dirtyPlan = & $resumeScript -CheckpointPath $result.CheckpointPath -RepositoryRoot $syntheticRepo
    Check ($dirtyPlan.Decision -eq 'BLOCKED_DIRTY_WORKTREE') 'Dirty Worktree blockiert Resume'
    Remove-Item -LiteralPath (Join-Path $syntheticRepo 'dirty.txt') -Force

    & git -C $syntheticRepo switch -c synthetic-branch 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetischer Branchwechsel fehlgeschlagen.' }
    $branchPlan = & $resumeScript -CheckpointPath $result.CheckpointPath -RepositoryRoot $syntheticRepo
    Check ($branchPlan.Decision -eq 'BLOCKED_BRANCH_MISMATCH') 'Branch-Drift blockiert Resume'
    & git -C $syntheticRepo switch development 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Rueckkehr auf synthetisches development fehlgeschlagen.' }

    [IO.File]::AppendAllText((Join-Path $syntheticRepo 'README.md'), "head drift`n", [Text.UTF8Encoding]::new($false))
    & git -C $syntheticRepo add -- README.md
    & git -C $syntheticRepo -c user.name=NightlyReadiness -c user.email=nightly-readiness@example.invalid -c commit.gpgsign=false commit -m 'synthetic head drift' 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Synthetischer Drift-Commit fehlgeschlagen.' }
    $headPlan = & $resumeScript -CheckpointPath $result.CheckpointPath -RepositoryRoot $syntheticRepo
    Check ($headPlan.Decision -eq 'BLOCKED_HEAD_MISMATCH') 'Head-Drift blockiert Resume'

    Invoke-Rejected -Name 'Checkpoint ausserhalb des konfigurierten Roots' -Action { & $resumeScript -CheckpointPath (Join-Path $syntheticRepo 'README.md') -RepositoryRoot $syntheticRepo }
    $secretFixture = 'Token ' + 'ghp_' + ('A' * 24)
    Invoke-Rejected -Name 'Secret in Checkpoint-Daten' -Action {
        & $checkpointScript -RunId nightly-readiness -PackageId STM-AI-004 -Phase Readiness -Status READY_TO_RESUME -LastSuccessfulStep $secretFixture -NextAction 'Validate safe plan' -RepositoryRoot $syntheticRepo
    }
    $piiFixture = 'Contact ' + 'person' + '@example.invalid'
    Invoke-Rejected -Name 'PII in Checkpoint-Daten' -Action {
        & $checkpointScript -RunId nightly-readiness -PackageId STM-AI-004 -Phase Readiness -Status READY_TO_RESUME -LastSuccessfulStep 'Synthetic step done' -NextAction $piiFixture -RepositoryRoot $syntheticRepo
    }

    $attemptResult = & $checkpointScript `
        -RunId 'nightly-attempt-limit' `
        -PackageId 'STM-AI-004' `
        -Phase 'Attempt limit' `
        -Status READY_TO_RESUME `
        -LastSuccessfulStep 'Synthetic drift commit completed' `
        -NextAction 'Stop after bounded attempts' `
        -Attempt ([int]$policy.maxResumeAttempts) `
        -RepositoryRoot $syntheticRepo
    $attemptPlan = & $resumeScript -CheckpointPath $attemptResult.CheckpointPath -RepositoryRoot $syntheticRepo
    Check ($attemptPlan.Decision -eq 'BLOCKED_ATTEMPT_LIMIT') 'Attempt-Limit blockiert weitere Resume-Ausfuehrung'

    $registration = & $registrationScript -RepositoryRoot $syntheticRepo
    Check ($registration.Status -eq 'READY_FOR_ACTIVATION') 'Registrierungsplan ist bereit zur expliziten Aktivierung'
    Check (-not [bool]$registration.ActivationPerformed) 'Registrierungsplan aktiviert nichts'
    Check ($registration.SideEffects -eq 'LOCAL_DATA_WRITE_ONLY') 'Registrierungsplan schreibt nur lokale Daten'
    $registrationData = Get-Content -LiteralPath $registration.PlanPath -Raw | ConvertFrom-Json
    . $commonScript
    Check ([string]$registrationData.bindingSha256 -ceq (Get-NightlyRegistrationBinding -Plan $registrationData)) 'Registrierungsplan besitzt gueltige SHA-256-Bindung'
    Check ($registrationData.source.branch -eq 'development' -and [string]$registrationData.source.headSha -cmatch '^[0-9a-f]{40}$' -and [bool]$registrationData.source.worktreeClean) 'Registrierung ist an sauberes development und exakten Head gebunden'
    Check ([bool]$registrationData.activationRequiresExplicitOwnerAction) 'Registrierung verlangt explizite Owner-Aktion'
    Check (-not [bool]$registrationData.automaticExecutionEnabled -and $null -eq $registrationData.activationCommand) 'Registrierung besitzt weder Autoausfuehrung noch Aktivierungskommando'
    Check (-not [bool]$registrationData.controls.gitMutationAllowed -and -not [bool]$registrationData.controls.networkMutationAllowed -and -not [bool]$registrationData.controls.schedulerMutationAllowed -and -not [bool]$registrationData.controls.externalWriteAllowed) 'Registrierung verbietet externe Mutationen'
}
finally {
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $outputBoundary = [IO.Path]::GetFullPath((Join-Path $repo 'output/nightly-readiness'))
    $prefix = $outputBoundary.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($fullTestRoot.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $fullTestRoot -PathType Container)) {
        $item = Get-Item -LiteralPath $fullTestRoot -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
            Remove-Item -LiteralPath $fullTestRoot -Recurse -Force
        }
    }
}

$instructionAfter = Get-InstructionDigest
Check ($instructionBefore -ceq $instructionAfter) 'Nightly-Gate veraendert keine Instruktionsquelle'
Check (-not (Test-Path -LiteralPath $testRoot)) 'Synthetische Nightly-Artefakte wurden sicher bereinigt'

if ($failures.Count -gt 0) {
    Write-Error ("NIGHTLY_READINESS=FEHLER CASES={0} FAILURES={1}: {2}" -f $caseCount, $failures.Count, ($failures -join '; '))
    exit 1
}

Write-Host "NIGHTLY_READINESS=OK CASES=$caseCount REGISTRATION=READY_FOR_ACTIVATION"
exit 0
