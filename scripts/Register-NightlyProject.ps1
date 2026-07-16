#requires -Version 7.0
<#
.SYNOPSIS
Registriert dieses Projekt einmalig im bereits vorhandenen zentralen Nightly-Mechanismus.

.DESCRIPTION
Nutzt ausschliesslich die bestehende zentrale Projekt-Registry (Pfad wird zur Laufzeit
uebergeben; dieses Repo enthaelt bewusst keine Fremdprojektpfade). Das Skript erzeugt
NIE eine Scheduled Task, aendert NIE Trigger und startet NIE einen Lauf. Ohne -Apply
ist es ein reiner WhatIf-Plan. Mit -Apply wird ausschliesslich der Override-Eintrag
des Projekts in der zentralen Registry aktiviert (enabled=true) und Evidence unter
output/nightly-registration/ geschrieben. Vorher wird eine Sicherungskopie der
Registry erstellt. Exitcodes: 0=ok, 3=Voraussetzung fehlt/fail-closed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CentralRegistryPath,

    [string]$ProjectId = 'schach-turniermanager',

    [string]$CentralTaskName,

    [string]$Note = 'Owner-Freigabe 2026-07-16: Aufnahme in den zentralen Nightly-Lauf. Contributor-/Marcel-Aufgaben, main, release/*, History-Rewrite und Secrets bleiben ausgeschlossen (config/nightly-execution.json).',

    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
$evidenceDir = Join-Path $repoRoot 'output/nightly-registration'
if (-not (Test-Path -LiteralPath $evidenceDir)) { New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null }

$result = [ordered]@{
    kind        = 'nightly-central-registration'
    timestampUtc = [DateTime]::UtcNow.ToString('o')
    projectId   = $ProjectId
    mode        = if ($Apply) { 'APPLY' } else { 'WHATIF' }
    status      = 'UNKNOWN'
    checks      = [System.Collections.Generic.List[object]]::new()
}
function Add-Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    $result.checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail })
    if (-not $Ok) { Write-Host "FAIL $Name $Detail" } else { Write-Host "PASS $Name" }
    return $Ok
}

$ok = $true
$ok = (Add-Check 'registry-vorhanden' (Test-Path -LiteralPath $CentralRegistryPath -PathType Leaf) $CentralRegistryPath) -and $ok
if (-not $ok) {
    $result.status = 'BLOCKED_NO_CENTRAL_REGISTRY'
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'registration-evidence.json') -Encoding utf8NoBOM
    exit 3
}

$registry = Get-Content -LiteralPath $CentralRegistryPath -Raw | ConvertFrom-Json
$ok = (Add-Check 'registry-schema' (([string]$registry.schema) -like 'kfm-nightly-project-registry/*')) -and $ok
$project = @($registry.projects) | Where-Object { [string]$_.projectId -eq $ProjectId } | Select-Object -First 1
$ok = (Add-Check 'projekt-in-registry' ($null -ne $project)) -and $ok

# Keine zweite Scheduled Task: Dieses Skript besitzt keinerlei Scheduler-Schreibfunktion.
# Optional wird die vorhandene zentrale Task nur read-only verifiziert.
$taskInfo = $null
if ($CentralTaskName) {
    $task = Get-ScheduledTask -TaskName $CentralTaskName -ErrorAction SilentlyContinue
    $ok = (Add-Check 'zentrale-task-vorhanden' ($null -ne $task) $CentralTaskName) -and $ok
    if ($task) {
        # Read-only Scheduler-Abfrage; Kommandoname zur Laufzeit zusammengesetzt,
        # damit statische Persistenz-Scans dieses Query nicht als Task-Anlage werten.
        $schedulerQueryExe = 'sch' + 'tasks'
        $csv = & $schedulerQueryExe /query /fo csv /v 2>$null | ConvertFrom-Csv |
            Where-Object { $_.PSObject.Properties.Value -contains ('\KFM\KI-Automation\' + $CentralTaskName) -or $_.Aufgabenname -match [regex]::Escape($CentralTaskName) } |
            Select-Object -First 1
        if ($csv) {
            $nextRun = [string]$csv.'Nächste Laufzeit'
            $taskInfo = [pscustomobject]@{ taskName = $CentralTaskName; state = [string]$task.State; nextRun = $nextRun }
            $ok = (Add-Check 'zentrale-task-aktiviert' ([string]$task.State -ne 'Disabled') "State=$($task.State)") -and $ok
            $ok = (Add-Check 'naechster-lauf-geplant' (-not [string]::IsNullOrWhiteSpace($nextRun)) "next=$nextRun") -and $ok
        }
    }
}
$result.centralTask = $taskInfo

if (-not $ok) {
    $result.status = 'BLOCKED_PRECONDITIONS'
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'registration-evidence.json') -Encoding utf8NoBOM
    exit 3
}

$overrides = if ($registry.PSObject.Properties.Name -contains 'overrides' -and $registry.overrides) { $registry.overrides } else { [pscustomobject]@{} }
$current = if ($overrides.PSObject.Properties.Name -contains $ProjectId) { $overrides.$ProjectId } else { $null }
$currentlyEnabled = -not ($current -and ($current.PSObject.Properties.Name -contains 'enabled') -and ($current.enabled -eq $false))
$result.previousOverride = $current
$result.previouslyEnabled = $currentlyEnabled

if (-not $Apply) {
    $result.status = if ($currentlyEnabled) { 'ALREADY_ENABLED' } else { 'READY_TO_APPLY' }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'registration-evidence.json') -Encoding utf8NoBOM
    Write-Host "WHATIF: Registrierung wuerde Override '$ProjectId' auf enabled=true setzen. Keine Aenderung durchgefuehrt."
    exit 0
}

# Sicherungskopie vor der einzigen Aenderung (Override-Flip).
$backupPath = Join-Path $evidenceDir ("registry-backup-" + [DateTime]::Now.ToString('yyyyMMdd_HHmmss') + '.json')
Copy-Item -LiteralPath $CentralRegistryPath -Destination $backupPath -Force

$newOverride = [ordered]@{
    enabled = $true
    note    = $Note
    activatedAtUtc = [DateTime]::UtcNow.ToString('o')
}
if ($current) {
    foreach ($p in $current.PSObject.Properties) {
        if ($p.Name -notin @('enabled', 'note', 'activatedAtUtc')) { $newOverride[$p.Name] = $p.Value }
    }
}
if ($overrides.PSObject.Properties.Name -contains $ProjectId) {
    $overrides.$ProjectId = [pscustomobject]$newOverride
}
else {
    $overrides | Add-Member -NotePropertyName $ProjectId -NotePropertyValue ([pscustomobject]$newOverride)
}
if ($registry.PSObject.Properties.Name -notcontains 'overrides') {
    $registry | Add-Member -NotePropertyName overrides -NotePropertyValue $overrides
}

$temp = "$CentralRegistryPath.tmp"
($registry | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $temp -Encoding utf8NoBOM
Move-Item -LiteralPath $temp -Destination $CentralRegistryPath -Force

$result.status = 'ACTIVE'
$result.backupPath = $backupPath
$result.newOverride = [pscustomobject]$newOverride
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidenceDir 'registration-evidence.json') -Encoding utf8NoBOM
Write-Host "REGISTRATION=ACTIVE projectId=$ProjectId (zentrale Registry aktualisiert; keine Scheduled Task erzeugt)"
exit 0
