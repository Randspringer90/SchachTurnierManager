<#
.SYNOPSIS
    Exportiert das forensische Audit-Bundle eines Turniers aus dem laufenden Backend
    und legt es als lokale Datei ab.

.DESCRIPTION
    Reines lokales Forensik-Werkzeug. Es nutzt ausschließlich den öffentlichen REST-Endpunkt
    GET /api/tournaments/{id}/audit-journal/export.jsonl (bzw. .json) des laufenden Backends
    (Standard: http://localhost:5088) und speichert das Ergebnis als UTF-8-Datei. Keine Cloud,
    kein Upload, kein externer Dienst.

    Das Bundle ist in sich geschlossen: Manifest, vollständiger Turnier-Snapshot,
    Pairing-Forensik je Runde und alle Audit-Journal-Ereignisse. Nach jeder Runde und nach
    Turnierende ausführen – damit bleibt der forensische Verlauf erhalten, selbst wenn die
    Turnierdatenbank verloren geht. Schließt die Forensik-Lücke aus dem Bergfest-Postmortem.

.PARAMETER TournamentId
    GUID des Turniers. Ohne Angabe werden die vorhandenen Turniere aufgelistet und
    interaktiv abgefragt.

.PARAMETER Format
    jsonl (Standard, append-only-freundlich) oder json (lesbares Dokument).

.PARAMETER OutputDir
    Zielordner. Standard: <Repo>\output\audit (ist .gitignore-geschützt, kein Commit).

.PARAMETER BaseUrl
    Basis-URL des laufenden Backends. Standard: http://localhost:5088

.EXAMPLE
    pwsh -File .\scripts\Export-TournamentAudit.ps1

.EXAMPLE
    pwsh -File .\scripts\Export-TournamentAudit.ps1 -TournamentId 00000000-0000-0000-0000-000000000000 -Format json
#>
[CmdletBinding()]
param(
    [string]$TournamentId,
    [ValidateSet('jsonl', 'json')]
    [string]$Format = 'jsonl',
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\output\audit'),
    [string]$BaseUrl = 'http://localhost:5088'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($TournamentId)) {
    $tournaments = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/tournaments"
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

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# Der Server liefert den Dateinamen (tournamentName_round_timestamp_audit.<ext>) im
# Content-Disposition-Header. Wir übernehmen ihn, fallen sonst auf einen Zeitstempel zurück.
$uri = "$BaseUrl/api/tournaments/$TournamentId/audit-journal/export.$Format"
Write-Host "Exportiere Audit-Bundle für $TournamentId ($Format) ..." -ForegroundColor Cyan
$response = Invoke-WebRequest -Method Get -Uri $uri

$fileName = $null
$disposition = $response.Headers['Content-Disposition']
if ($disposition) {
    $match = [regex]::Match([string]$disposition, 'filename\*?=(?:UTF-8'''')?"?([^";]+)"?')
    if ($match.Success) {
        $fileName = [System.Uri]::UnescapeDataString($match.Groups[1].Value)
    }
}
if ([string]::IsNullOrWhiteSpace($fileName)) {
    $fileName = ("turnier_round0_{0}_audit.{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Format)
}

$targetPath = Join-Path $OutputDir $fileName
[System.IO.File]::WriteAllText($targetPath, $response.Content, [System.Text.UTF8Encoding]::new($false))

Write-Host "Audit-Bundle gespeichert: $targetPath" -ForegroundColor Green
Write-Host 'Hinweis: Diese Datei enthält ggf. echte Teilnehmerdaten und gehört NICHT ins Repository.'
