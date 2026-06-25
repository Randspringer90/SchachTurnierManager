<#
.SYNOPSIS
    Schreibgeschützter Turniertag-Bereitschaftscheck. Ändert nichts am System.

.DESCRIPTION
    Prüft nur lesend, ob die wichtigsten Voraussetzungen für den Turniertag stimmen:
      - Backend erreichbar (GET /api/health)
      - Frontend-Port (5173) belegt / erreichbar
      - SQLite-Datenbankpfad existiert (aus dem Health-Endpunkt gelesen)
      - Backup-Ordner existiert
      - Git-Arbeitsverzeichnis sauber und mit origin synchron

    Es werden KEINE Windows-Energieoptionen, Dienste oder Dateien verändert.
    Keine Cloud, kein Upload, kein externer Dienst.

.PARAMETER BaseUrl
    Basis-URL des laufenden Backends. Standard: http://localhost:5088

.PARAMETER FrontendUrl
    URL des Vite-Frontends. Standard: http://127.0.0.1:5173

.PARAMETER BackupDir
    Erwarteter lokaler Backup-Ordner. Standard: D:\Schach\Backups

.EXAMPLE
    pwsh -File .\scripts\Show-EventReadiness.ps1
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://localhost:5088',
    [string]$FrontendUrl = 'http://127.0.0.1:5173',
    [string]$BackupDir = 'D:\Schach\Backups'
)

$ErrorActionPreference = 'Continue'
$root = Resolve-Path "$PSScriptRoot\.."
$allOk = $true

function Write-Check {
    param([bool]$Ok, [string]$Label, [string]$Detail = '')
    $symbol = if ($Ok) { '[ OK ]' } else { '[FAIL]' }
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ("{0} {1}" -f $symbol, $Label) -ForegroundColor $color
    if ($Detail) { Write-Host ("        {0}" -f $Detail) -ForegroundColor DarkGray }
}

Write-Host 'Turniertag-Bereitschaftscheck (nur lesend)' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan

# 1) Backend erreichbar
$health = $null
try {
    $health = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/health" -TimeoutSec 4
    Write-Check $true 'Backend erreichbar' ("{0} {1}: {2}" -f $health.app, $health.version, $health.status)
}
catch {
    $allOk = $false
    Write-Check $false 'Backend erreichbar' ("Keine Antwort von $BaseUrl/api/health. Backend-Fenster prüfen.")
}

# 2) Frontend-Port
$frontendOk = $false
try {
    $response = Invoke-WebRequest -Uri $FrontendUrl -UseBasicParsing -TimeoutSec 4
    $frontendOk = $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
}
catch {
    $frontendOk = $false
}
if (-not $frontendOk) { $allOk = $false }
Write-Check $frontendOk 'Frontend erreichbar' $FrontendUrl

# 3) Datenbankpfad existiert
if ($health -and $health.databasePath) {
    $dbExists = Test-Path -LiteralPath $health.databasePath
    if (-not $dbExists) { $allOk = $false }
    Write-Check $dbExists 'Datenbankpfad existiert' $health.databasePath
}
else {
    Write-Check $false 'Datenbankpfad existiert' 'Konnte databasePath nicht aus dem Health-Endpunkt lesen.'
}

# 4) Backup-Ordner existiert
$backupExists = Test-Path -LiteralPath $BackupDir
if (-not $backupExists) { $allOk = $false }
Write-Check $backupExists 'Backup-Ordner existiert' $BackupDir

# 5) Git sauber und synchron
Push-Location $root
try {
    $statusLines = git status --porcelain 2>$null
    $gitClean = [string]::IsNullOrWhiteSpace(($statusLines -join ''))
    Write-Check $gitClean 'Git-Arbeitsverzeichnis sauber' $(if ($gitClean) { 'keine offenen Änderungen' } else { 'Es gibt nicht committete Änderungen.' })

    $localHead = (git rev-parse HEAD 2>$null)
    $remoteHead = (git rev-parse '@{u}' 2>$null)
    if ($localHead -and $remoteHead) {
        $synced = $localHead -eq $remoteHead
        Write-Check $synced 'Git synchron mit origin' $(if ($synced) { 'HEAD == origin' } else { 'Lokaler Stand weicht von origin ab.' })
    }
    else {
        Write-Check $true 'Git synchron mit origin' 'Kein Upstream gesetzt – Hinweis, kein harter Fehler.'
    }
}
finally {
    Pop-Location
}

Write-Host '==========================================' -ForegroundColor Cyan
if ($allOk) {
    Write-Host 'Bereit für den Turniertag.' -ForegroundColor Green
}
else {
    Write-Host 'Mindestens ein Punkt ist NICHT bereit. Bitte oben prüfen.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Erinnerung (keine automatische Systemänderung):' -ForegroundColor Cyan
Write-Host '  - Laptop am Netzteil betreiben.'
Write-Host '  - Energiesparen / Bildschirmsperre vermeiden.'
Write-Host '  - Browser-Tab offen lassen, Backend-Fenster nicht schließen.'
Write-Host '  - Nach jeder Runde ein Backup ziehen (scripts\Backup-BergfestTournament.ps1).'
