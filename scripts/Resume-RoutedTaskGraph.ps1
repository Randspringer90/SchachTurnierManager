#requires -Version 7.0
<#
.SYNOPSIS
Setzt einen unterbrochenen Routed-Execution-Lauf sicher am Checkpoint fort.

.DESCRIPTION
Validiert die Checkpoint-Bindung fail-closed (Typ, Graph-Hash, Repository, Branch,
Resume-Limit). ESCALATED- und RATE_LIMITED-Tasks werden wieder auf READY gesetzt;
COMPLETED/INTEGRATED/QUARANTINED/REJECTED bleiben unveraendert erhalten. Danach wird
Invoke-RoutedTaskGraph auf dem rekonstruierten Graphen fortgesetzt.
Exitcodes wie Invoke-RoutedTaskGraph; 3=Bindung verletzt/Limit erreicht.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CheckpointPath,

    [string]$PolicyPath,

    [string]$RuntimePolicyPath,

    [string]$SimulateResultsPath,

    [int]$MaxResumeAttempts = 3,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

try {
    $checkpoint = Read-RoutedCheckpoint -CheckpointPath $CheckpointPath -MaxResumeAttempts $MaxResumeAttempts
}
catch {
    [pscustomobject]@{ status = 'RESUME_BLOCKED'; reason = $_.Exception.Message } | ConvertTo-Json
    exit 3
}

$graph = $checkpoint.graph
$resumable = 0
foreach ($task in @($graph.tasks)) {
    if ([string]$task.status -in @('RATE_LIMITED', 'ESCALATED', 'RUNNING', 'BUDGET_EXCEEDED')) {
        $task.status = 'READY'
        $resumable++
    }
}
if ($resumable -eq 0 -and @(@($graph.tasks) | Where-Object { [string]$_.status -in @('PENDING', 'READY') }).Count -eq 0) {
    [pscustomobject]@{ status = 'NO_RESUME_REQUIRED'; reason = 'Keine fortsetzbaren Tasks im Checkpoint.' } | ConvertTo-Json
    exit 0
}

# Resume-Zaehler erhoehen und Graph mit neuem Hash als Fortsetzungsgraph schreiben.
$runRoot = Split-Path -Parent ([IO.Path]::GetFullPath($CheckpointPath))
$resumeGraphPath = Join-Path $runRoot ("resume-graph-" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss') + '.json')
$graphHash = Get-TaskGraphHash -Graph $graph
$envelope = [ordered]@{
    schemaVersion = 1
    kind          = 'routed-task-graph'
    graphHash     = $graphHash
    resumedFrom   = [string]$checkpoint.graphHash
    graph         = $graph
}
($envelope | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $resumeGraphPath -Encoding utf8NoBOM

# Attempt-Zaehler im bestehenden Checkpoint persistieren.
$raw = Get-Content -LiteralPath $CheckpointPath -Raw | ConvertFrom-Json
$raw.resumeAttempts = [int]$raw.resumeAttempts + 1
($raw | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $CheckpointPath -Encoding utf8NoBOM

$invokeArgs = @(
    '-TaskGraphPath', $resumeGraphPath,
    '-RunRoot', $runRoot,
    '-CheckpointPath', $CheckpointPath
)
if ($PolicyPath) { $invokeArgs += @('-PolicyPath', $PolicyPath) }
if ($RuntimePolicyPath) { $invokeArgs += @('-RuntimePolicyPath', $RuntimePolicyPath) }
if ($SimulateResultsPath) { $invokeArgs += @('-SimulateResultsPath', $SimulateResultsPath) }
if ($DryRun) { $invokeArgs += '-DryRun' }

& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-RoutedTaskGraph.ps1') @invokeArgs
exit $LASTEXITCODE
