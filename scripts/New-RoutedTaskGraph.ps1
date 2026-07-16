#requires -Version 7.0
<#
.SYNOPSIS
Erzeugt aus einer Masterprompt-Zerlegung einen validierten, gerouteten Taskgraph.

.DESCRIPTION
Die semantische Zerlegung erstellt der Orchestrator (Fabel oder Sol). Dieses Skript
behandelt die Zerlegungsdatei als T3-Daten: es validiert sie fail-closed gegen die
Task-Decomposition-Policy, ermittelt pro Teilaufgabe das logische Profil ueber
scripts/Resolve-ModelRoute.ps1 (kein stiller Wechsel, kein Downgrade kritischer
Arbeit) und schreibt den gerouteten Graphen inklusive Hash. Exitcodes:
0=ok, 3=fail-closed blockiert.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DecompositionFile,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string[]]$AvailableProfiles,

    [string]$PolicyPath,

    [string]$ModelRoutingPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'lib/RoutedExecutionCommon.ps1')

$AvailableProfiles = @(
    $AvailableProfiles |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim().ToLowerInvariant() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique
)

$policy = Get-RoutedPolicy -PolicyPath $PolicyPath
if (-not (Test-Path -LiteralPath $DecompositionFile -PathType Leaf)) {
    throw "Zerlegungsdatei fehlt: $DecompositionFile"
}
$graph = Get-Content -LiteralPath $DecompositionFile -Raw | ConvertFrom-Json

$violations = @(Test-RoutedTaskGraph -Graph $graph -Policy $policy)
if ($violations.Count -gt 0) {
    [pscustomobject]@{
        status     = 'BLOCKED_INVALID_GRAPH'
        violations = @($violations)
    } | ConvertTo-Json -Depth 8
    exit 3
}

$resolver = Join-Path $PSScriptRoot 'Resolve-ModelRoute.ps1'
$routedTasks = [System.Collections.Generic.List[object]]::new()
$blocked = [System.Collections.Generic.List[object]]::new()

foreach ($task in @($graph.tasks)) {
    $resolveArgs = @(
        '-TaskCategory', [string]$task.category,
        '-WorkMode', [string]$task.workMode,
        '-Size', [string]$task.size,
        '-Risk', [string]$task.risk,
        '-AvailableProfiles', ($AvailableProfiles -join ',')
    )
    if ($ModelRoutingPath) { $resolveArgs += @('-ConfigPath', $ModelRoutingPath) }
    if ([bool]$task.deterministic) { $resolveArgs += '-Deterministic' }

    $decisionJson = & pwsh -NoProfile -File $resolver @resolveArgs
    $resolverExit = $LASTEXITCODE
    $decision = $decisionJson | ConvertFrom-Json

    $routing = [ordered]@{
        matchedRule        = $decision.matchedRule
        recommendedProfile = $decision.recommendedProfile
        resolverStatus     = $decision.status
        resolverReason     = $decision.reason
    }

    if ($resolverExit -ne 0) {
        $blocked.Add([pscustomobject]@{ taskId = $task.taskId; status = $decision.status; reason = $decision.reason })
        $task | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$routing) -Force
        $task.status = 'BLOCKED'
        $routedTasks.Add($task)
        continue
    }

    $assigned = [string]$decision.recommendedProfile
    $preferred = [string]$task.preferredProfile
    if ($preferred -and $preferred -ne $assigned) {
        # Praeferenz wird nur akzeptiert, wenn sie den Resolver-Vorschlag nicht unterschreitet.
        $routing.preferredProfileIgnored = $preferred
        $routing.preferredProfileNote = 'Owner-Praeferenz ersetzt nie die Capability-/Qualitaetsentscheidung des Resolvers.'
    }
    $task | Add-Member -NotePropertyName assignedProfile -NotePropertyValue $assigned -Force
    $task | Add-Member -NotePropertyName routing -NotePropertyValue ([pscustomobject]$routing) -Force
    $task.status = 'READY'
    $routedTasks.Add($task)
}

$graph.tasks = @($routedTasks)
$graph | Add-Member -NotePropertyName routedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
$graph | Add-Member -NotePropertyName availableProfiles -NotePropertyValue @($AvailableProfiles) -Force

$graphHash = Get-TaskGraphHash -Graph $graph
$envelope = [ordered]@{
    schemaVersion = 1
    kind          = 'routed-task-graph'
    graphHash     = $graphHash
    graph         = $graph
}

$outputDir = Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath))
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}
($envelope | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM

$summary = [pscustomobject]@{
    status       = if ($blocked.Count -gt 0) { 'ROUTED_WITH_BLOCKS' } else { 'ROUTED' }
    graphHash    = $graphHash
    taskCount    = @($graph.tasks).Count
    blockedCount = $blocked.Count
    blocked      = @($blocked)
    outputPath   = [IO.Path]::GetFullPath($OutputPath)
}
$summary | ConvertTo-Json -Depth 8

if ($blocked.Count -gt 0) { exit 3 }
exit 0
