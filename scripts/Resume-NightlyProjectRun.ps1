#requires -Version 7.0
<#
.SYNOPSIS
Setzt unterbrochene Nightly-Arbeit dieses Projekts sicher fort.

.DESCRIPTION
Zwei Ebenen, beide fail-closed:
1. Nightly-Checkpoints (STM-AI-004): validiert ueber das bestehende
   scripts/Get-NightlyResumePlan.ps1 (SHA-/Branch-/Worktree-Bindung, plan-only).
2. Routed-Execution-Checkpoints (STM-AI-005): setzt ueber
   scripts/Resume-RoutedTaskGraph.ps1 fort.
Ohne gueltigen Checkpoint endet das Skript mit NO_RESUME_REQUIRED (Exit 0).
Dieses Skript fuehrt keine Git-, Netzwerk- oder Scheduler-Mutation aus.
#>
[CmdletBinding()]
param(
    [string]$NightlyCheckpointPath,

    [string]$RoutedCheckpointPath,

    [string]$SimulateResultsPath,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
$results = [ordered]@{ kind = 'nightly-resume'; timestampUtc = [DateTime]::UtcNow.ToString('o') }

if ($RoutedCheckpointPath) {
    $resumeArgs = @('-CheckpointPath', $RoutedCheckpointPath)
    if ($SimulateResultsPath) { $resumeArgs += @('-SimulateResultsPath', $SimulateResultsPath) }
    if ($DryRun) { $resumeArgs += '-DryRun' }
    & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Resume-RoutedTaskGraph.ps1') @resumeArgs
    $results.routedExit = $LASTEXITCODE
    $results.status = switch ($results.routedExit) {
        0 { 'ROUTED_RESUMED' }
        2 { 'ROUTED_INTERRUPTED_AGAIN' }
        default { 'ROUTED_RESUME_BLOCKED' }
    }
    [pscustomobject]$results | ConvertTo-Json
    exit $results.routedExit
}

if ($NightlyCheckpointPath) {
    & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/Get-NightlyResumePlan.ps1') -CheckpointPath $NightlyCheckpointPath
    $results.nightlyExit = $LASTEXITCODE
    $results.status = if ($results.nightlyExit -eq 0) { 'NIGHTLY_PLAN_READY' } else { 'NIGHTLY_RESUME_BLOCKED' }
    [pscustomobject]$results | ConvertTo-Json
    exit $results.nightlyExit
}

# Ohne expliziten Checkpoint: neueste Kandidaten unter output/ suchen (read-only).
$candidates = @(Get-ChildItem -Path (Join-Path $repoRoot 'output') -Recurse -Filter 'checkpoint.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
if ($candidates.Count -eq 0) {
    $results.status = 'NO_RESUME_REQUIRED'
    [pscustomobject]$results | ConvertTo-Json
    exit 0
}
$results.status = 'CANDIDATES_FOUND'
$results.candidates = @($candidates | Select-Object -First 5 | ForEach-Object { $_.FullName })
[pscustomobject]$results | ConvertTo-Json
exit 0
