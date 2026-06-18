<#
.SYNOPSIS
    Zieht einen lokalen JSON-Snapshot eines Turniers aus dem laufenden Backend
    und legt ihn im Backup-Ordner ab.

.DESCRIPTION
    Reines lokales Backup-Werkzeug für den Turniertag. Es nutzt ausschließlich den
    öffentlichen REST-Endpunkt GET /api/tournaments/{id}/export/json des laufenden
    Backends (Standard: http://localhost:5088) und speichert das Ergebnis als
    UTF-8-JSON-Datei. Keine Cloud, kein Upload, kein externer Dienst.

    Die Datenbank speichert ohnehin nach jeder Aktion automatisch (Autosave in SQLite).
    Dieser externe Snapshot ist der zusätzliche Sicherheitsnetz-Export pro Runde und
    am Turnierende. Wiederherstellen über POST /api/tournaments/import.

.PARAMETER TournamentId
    GUID des Turniers. Ohne Angabe werden die vorhandenen Turniere aufgelistet
    und interaktiv abgefragt.

.PARAMETER Label
    Kurzer Bezeichner für den Dateinamen, z. B. "r3" oder "final". Ohne Angabe
    wird ein Zeitstempel verwendet.

.PARAMETER BackupDir
    Zielordner. Standard: D:\Schach\Backups (wird bei Bedarf angelegt).

.PARAMETER BaseUrl
    Basis-URL des laufenden Backends. Standard: http://localhost:5088

.EXAMPLE
    pwsh -File .\scripts\Backup-BergfestTournament.ps1 -Label r1

.EXAMPLE
    pwsh -File .\scripts\Backup-BergfestTournament.ps1 -TournamentId 00000000-0000-0000-0000-000000000000 -Label final
#>
[CmdletBinding()]
param(
    [string]$TournamentId,
    [string]$Label,
    [string]$BackupDir = 'D:\Schach\Backups',
    [string]$BaseUrl = 'http://localhost:5088'
)

$ErrorActionPreference = 'Stop'

function Get-Tournaments {
    return Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/tournaments"
}

if ([string]::IsNullOrWhiteSpace($TournamentId)) {
    $tournaments = Get-Tournaments
    if (-not $tournaments -or $tournaments.Count -eq 0) {
        throw "Keine Turniere gefunden. Läuft das Backend unter $BaseUrl?"
    }

    Write-Host 'Vorhandene Turniere:' -ForegroundColor Cyan
    $index = 0
    foreach ($t in $tournaments) {
        Write-Host ("  [{0}] {1}  ({2}, Runden: {3})  {4}" -f $index, $t.name, $t.settings.format, $t.rounds.Count, $t.id)
        $index++
    }

    $choice = Read-Host 'Nummer des Turniers auswählen'
    $selected = $tournaments[[int]$choice]
    if (-not $selected) {
        throw "Ungültige Auswahl: $choice"
    }
    $TournamentId = $selected.id
}

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

if ([string]::IsNullOrWhiteSpace($Label)) {
    $Label = (Get-Date -Format 'yyyyMMdd_HHmmss')
}

$safeLabel = ($Label -replace '[^A-Za-z0-9_\-]', '_')
$targetPath = Join-Path $BackupDir ("bergfest_{0}.json" -f $safeLabel)

Write-Host "Sichere Turnier $TournamentId ..." -ForegroundColor Cyan
$json = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/tournaments/$TournamentId/export/json"
$json | ConvertTo-Json -Depth 16 | Set-Content -Encoding utf8 -Path $targetPath

Write-Host "Backup gespeichert: $targetPath" -ForegroundColor Green
Write-Host 'Wiederherstellen: JSON-Inhalt an POST /api/tournaments/import mit { "tournament": <json>, "overwriteExisting": true } senden.'
