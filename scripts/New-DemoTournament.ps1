<#
.SYNOPSIS
    Legt ein Demo-/Dry-run-Turnier mit synthetischen Spielern gegen das laufende Backend an
    und kann optional alle 5 Runden automatisch durchspielen.

.DESCRIPTION
    Dieses Skript ist die praktische Generalprobe für den Bergfest-/Freestyle-Würfelschach-Einsatz.
    Es benötigt nur das laufende WebApi-Backend (Standard: http://localhost:5088) und nutzt
    ausschließlich die öffentlichen REST-Endpunkte. Es committet nichts und schreibt keine Dateien;
    die Turnierdaten landen in der lokalen SQLite-Datenbank des Backends (Autosave nach jeder Aktion).

    Alle Spielernamen sind rein synthetisch ("Demo Spieler NN"), es werden keine echten
    Teilnehmerdaten verarbeitet.

.PARAMETER BaseUrl
    Basis-URL des laufenden Backends. Standard: http://localhost:5088

.PARAMETER PlayerCount
    Anzahl synthetischer Spieler (8-12 empfohlen). Standard: 10

.PARAMETER Rounds
    Anzahl auszuspielender Runden. Standard: 5

.PARAMETER Name
    Turniername. Standard: "Bergfest Freestyle-Würfelschach (Demo)"

.PARAMETER PlayOut
    Wenn gesetzt, werden alle Runden ausgelost und mit Zufallsergebnissen befüllt.
    Ohne diesen Schalter wird nur das Turnier mit Spielern angelegt (manueller Dry-run).

.EXAMPLE
    pwsh -File .\scripts\New-DemoTournament.ps1 -PlayerCount 10 -PlayOut

.EXAMPLE
    pwsh -File .\scripts\New-DemoTournament.ps1 -PlayerCount 11 -Rounds 5 -PlayOut
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:5088",
    [ValidateRange(2, 200)][int]$PlayerCount = 10,
    [ValidateRange(1, 15)][int]$Rounds = 5,
    [string]$Name = "Bergfest Freestyle-Würfelschach (Demo)",
    [switch]$PlayOut
)

$ErrorActionPreference = "Stop"
$BaseUrl = $BaseUrl.TrimEnd("/")

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Path,
        $Body
    )
    $uri = "$BaseUrl$Path"
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 12
        return Invoke-RestMethod -Method $Method -Uri $uri -Body $json -ContentType "application/json"
    }
    return Invoke-RestMethod -Method $Method -Uri $uri
}

Write-Host "== Bergfest Demo-Turnier ==" -ForegroundColor Cyan
Write-Host "Backend: $BaseUrl"

# 1. Healthcheck
try {
    $health = Invoke-Api -Method Get -Path "/api/health"
    Write-Host "Healthcheck OK (Status: $($health.status))" -ForegroundColor Green
}
catch {
    Write-Error "Backend nicht erreichbar unter $BaseUrl. Bitte zuerst das WebApi starten (siehe Runbook)."
    throw
}

# 2. Turnier anlegen (Swiss, geplante Runden = $Rounds)
# Hinweis: Die WebApi bindet Enums im Request-Body numerisch. TournamentFormat.Swiss = 1.
$tournament = Invoke-Api -Method Post -Path "/api/tournaments" -Body @{
    name     = $Name
    settings = @{
        format        = 1   # 1 = Swiss
        plannedRounds = $Rounds
    }
}
$tid = $tournament.id
Write-Host "Turnier angelegt: '$Name' (Id $tid)" -ForegroundColor Green

# 3. Synthetische Spieler anlegen
for ($i = 1; $i -le $PlayerCount; $i++) {
    # PlayerRequest ist flach: manualTwz ist ein Top-Level-Feld (kein verschachteltes rating-Objekt).
    $body = @{
        name         = ("Demo Spieler {0:D2}" -f $i)
        startingRank = $i
        manualTwz    = (2000 - $i * 25)
    }
    [void](Invoke-Api -Method Post -Path "/api/tournaments/$tid/players" -Body $body)
}
Write-Host "$PlayerCount synthetische Spieler angelegt." -ForegroundColor Green

if (-not $PlayOut) {
    Write-Host ""
    Write-Host "Turnier ist bereit. Auslosung/Ergebnisse manuell im Dashboard durchführen." -ForegroundColor Yellow
    Write-Host "Turnier-Id: $tid"
    return
}

# 4. Runden auslosen und mit Zufallsergebnissen befüllen
# GameResultKind numerisch: 1 = WhiteWin, 2 = Draw, 3 = BlackWin. Feldname im DTO: result.
$results = @(1, 2, 3)
for ($r = 1; $r -le $Rounds; $r++) {
    $round = Invoke-Api -Method Post -Path "/api/tournaments/$tid/pairings/next-round"
    $boards = @($round.pairings | Where-Object { -not $_.isBye })
    foreach ($p in $boards) {
        $kind = $results | Get-Random
        [void](Invoke-Api -Method Post -Path "/api/tournaments/$tid/rounds/$($round.roundNumber)/boards/$($p.boardNumber)/result" -Body @{ result = $kind })
    }
    $byeCount = @($round.pairings | Where-Object { $_.isBye }).Count
    Write-Host ("Runde {0}: {1} Bretter gespielt, {2} Bye." -f $round.roundNumber, $boards.Count, $byeCount) -ForegroundColor Green
}

# 5. Tabelle ausgeben
$standings = Invoke-Api -Method Get -Path "/api/tournaments/$tid/standings"
Write-Host ""
Write-Host "== Endtabelle ==" -ForegroundColor Cyan
$standings | Select-Object rank, name, points, buchholz, buchholzCutOne |
    Format-Table -AutoSize | Out-Host

Write-Host ""
Write-Host "Dry-run abgeschlossen. Turnier-Id: $tid" -ForegroundColor Green
Write-Host "Export/Print-Endpunkte siehe docs/BERGFEST_MVP_RUNBOOK.md."
