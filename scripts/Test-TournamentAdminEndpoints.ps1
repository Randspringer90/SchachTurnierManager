[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'http://localhost:5088',
    [Guid]$TournamentId = [Guid]::Empty,
    [switch]$AllowDestructive
)

$ErrorActionPreference = 'Stop'
$base = $ApiBaseUrl.TrimEnd('/')

function Invoke-JsonStatus {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null
    )

    $payload = $null
    if ($null -ne $Body) {
        $payload = $Body | ConvertTo-Json -Depth 20
    }

    try {
        $response = Invoke-WebRequest -Method $Method -Uri $Url -ContentType 'application/json' -Body $payload -ErrorAction Stop
        return [pscustomobject]@{ Method = $Method; Url = $Url; StatusCode = [int]$response.StatusCode; Note = 'OK'; Content = $response.Content }
    }
    catch {
        $status = $null
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null }
        }
        return [pscustomobject]@{ Method = $Method; Url = $Url; StatusCode = $status; Note = $_.Exception.Message; Content = $null }
    }
}

Write-Host "Health pruefen: $base/api/health"
$health = Invoke-RestMethod -Uri "$base/api/health" -Method GET
$health | ConvertTo-Json -Depth 5

$random = [Guid]::NewGuid()
Write-Host "Pruefe DELETE-Route mit nicht existierendem Turnier. Erwartet: 404, nicht 405."
$deleteProbe = Invoke-JsonStatus -Method DELETE -Url "$base/api/tournaments/$random"
$deleteProbe | Format-List Method,StatusCode,Note
if ($deleteProbe.StatusCode -eq 405) {
    throw "DELETE-Route ist nicht aktiv: API liefert 405 Method Not Supported. Backend-Patch ist nicht geladen."
}

Write-Host "Pruefe RESET-Route mit nicht existierendem Turnier. Erwartet: 404, nicht 405/Route-Miss."
$resetProbe = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$random/reset"
$resetProbe | Format-List Method,StatusCode,Note
if ($resetProbe.StatusCode -eq 405 -or $resetProbe.StatusCode -eq $null) {
    throw "RESET-Route ist nicht aktiv oder nicht erreichbar. Backend-Patch ist nicht geladen."
}

Write-Host "Pruefe Spielersuche (search-all) mit Namensquery. Erwartet: 200 und Quellenstatus je Quelle."
$searchAll = Invoke-JsonStatus -Method GET -Url "$base/api/external-players/search-all?query=Mustermann"
$searchAll | Format-List Method,StatusCode,Note
if ($searchAll.StatusCode -ne 200) {
    throw "search-all-Route funktioniert nicht: HTTP $($searchAll.StatusCode)."
}
$searchResult = $searchAll.Content | ConvertFrom-Json
if (@($searchResult.sources).Count -lt 1) {
    throw "search-all liefert keinen Quellenstatus. Erwartet: mindestens 1 Quelle."
}
Write-Host "search-all OK: $($searchResult.message)"

if ($TournamentId -ne [Guid]::Empty) {
    if (-not $AllowDestructive) {
        Write-Host "TournamentId angegeben, aber ohne -AllowDestructive wird Reset/Delete nicht ausgefuehrt."
        Write-Host "Zum echten Testen: -TournamentId $TournamentId -AllowDestructive"
        return
    }

    Write-Warning "Destruktiver Test: Reset loescht Runden/Ergebnisse; Delete loescht danach das Turnier."
    $resetResult = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$TournamentId/reset"
    $resetResult | Format-List Method,StatusCode,Note
    if ($resetResult.StatusCode -notin 200,404) {
        throw "Reset-Test unerwartet: HTTP $($resetResult.StatusCode)."
    }

    $deleteResult = Invoke-JsonStatus -Method DELETE -Url "$base/api/tournaments/$TournamentId"
    $deleteResult | Format-List Method,StatusCode,Note
    if ($deleteResult.StatusCode -notin 200,404) {
        throw "Delete-Test unerwartet: HTTP $($deleteResult.StatusCode)."
    }
}
else {
    Write-Host "Erzeuge und loesche ein Scratch-Turnier, um Reset/Delete ohne echtes Turnier zu verifizieren."
    $scratchName = "AdminEndpointProbe-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
    $create = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments" -Body @{ name = $scratchName; settings = @{ format = 1; plannedRounds = 3 } }
    $create | Format-List Method,StatusCode,Note
    if ($create.StatusCode -ne 201 -and $create.StatusCode -ne 200) {
        throw "Scratch-Turnier konnte nicht angelegt werden: HTTP $($create.StatusCode)."
    }
    $created = $create.Content | ConvertFrom-Json
    $scratchId = [string]$created.id
    Write-Host "Scratch-Turnier: $scratchName / $scratchId"

    foreach ($player in @(
        @{ name = 'Scratch Spieler 1'; gender = 0; status = 0; manualTwz = 1800 },
        @{ name = 'Scratch Spieler 2'; gender = 0; status = 0; manualTwz = 1700 }
    )) {
        $addPlayer = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$scratchId/players" -Body $player
        $addPlayer | Format-List Method,StatusCode,Note
        if ($addPlayer.StatusCode -ne 200) {
            throw "Scratch-Spieler konnte nicht angelegt werden: HTTP $($addPlayer.StatusCode)."
        }
    }

    $previewRound = Invoke-JsonStatus -Method GET -Url "$base/api/tournaments/$scratchId/pairings/preview-next-round"
    $previewRound | Format-List Method,StatusCode,Note
    if ($previewRound.StatusCode -ne 200) {
        throw "Scratch-Auslosungsvorschau konnte nicht erzeugt werden: HTTP $($previewRound.StatusCode)."
    }

    $generateRound = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$scratchId/pairings/next-round"
    $generateRound | Format-List Method,StatusCode,Note
    if ($generateRound.StatusCode -ne 200) {
        throw "Scratch-Runde konnte nicht erzeugt werden: HTTP $($generateRound.StatusCode)."
    }
    $generatedRound = $generateRound.Content | ConvertFrom-Json

    $rollChess960 = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$scratchId/rounds/$($generatedRound.roundNumber)/chess960/start-positions" -Body @{ overwriteExisting = $false; seed = 960 }
    $rollChess960 | Format-List Method,StatusCode,Note
    if ($rollChess960.StatusCode -ne 200) {
        throw "Chess960-Startstellungen konnten nicht gewuerfelt werden: HTTP $($rollChess960.StatusCode)."
    }
    $rolledRound = $rollChess960.Content | ConvertFrom-Json
    $regularBoards = @($rolledRound.pairings | Where-Object { -not $_.isBye })
    $assignedPositions = @($regularBoards | Where-Object { $null -ne $_.chess960StartPosition })
    if ($assignedPositions.Count -ne $regularBoards.Count) {
        throw "Chess960-Startstellungen fehlen. Erwartet: $($regularBoards.Count), Ist: $($assignedPositions.Count)."
    }

    $resetScratch = Invoke-JsonStatus -Method POST -Url "$base/api/tournaments/$scratchId/reset"
    $resetScratch | Format-List Method,StatusCode,Note
    if ($resetScratch.StatusCode -ne 200) {
        throw "Reset-Route funktioniert nicht: HTTP $($resetScratch.StatusCode)."
    }
    $resetTournament = $resetScratch.Content | ConvertFrom-Json
    if ($resetTournament.players.Count -ne 2) {
        throw "Reset hat Teilnehmer nicht erhalten. Erwartet: 2, Ist: $($resetTournament.players.Count)."
    }
    if ($resetTournament.rounds.Count -ne 0) {
        throw "Reset hat Runden nicht entfernt. Erwartet: 0, Ist: $($resetTournament.rounds.Count)."
    }

    $deleteScratch = Invoke-JsonStatus -Method DELETE -Url "$base/api/tournaments/$scratchId"
    $deleteScratch | Format-List Method,StatusCode,Note
    if ($deleteScratch.StatusCode -ne 200) {
        throw "Delete-Route funktioniert nicht: HTTP $($deleteScratch.StatusCode)."
    }

    $listAfterDelete = Invoke-RestMethod -Uri "$base/api/tournaments" -Method GET
    if ($listAfterDelete | Where-Object { $_.id -eq $scratchId }) {
        throw "Delete hat Scratch-Turnier nicht aus /api/tournaments entfernt."
    }

    Write-Host "Admin-Endpunkte OK: Reset und Delete funktionieren am Scratch-Turnier."
}
