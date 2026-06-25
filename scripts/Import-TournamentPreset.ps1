<#
.SYNOPSIS
Importiert eine lokale Bergfest-/Turnier-Preset-JSON-Datei in die laufende SchachTurnierManager-WebApi.

.DESCRIPTION
Robuste v3: Erstellt ein Turnier ueber POST /api/tournaments und importiert die Teilnehmer anschliessend
ueber den vorhandenen CSV-Import-Endpunkt POST /api/tournaments/{id}/players/import.csv.
Damit wird die gleiche Importlogik genutzt, die auch das Dashboard verwendet.

Beispiele:
  .\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -DryRun
  .\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -CreateTournament
#>
[CmdletBinding()]
param(
    [string]$PresetPath,
    [string]$PresetId,
    [switch]$AutoSelectSinglePreset,
    [string]$ApiBaseUrl = 'http://localhost:5088',
    [switch]$DryRun,
    [switch]$CreateTournament,
    [switch]$OverwriteExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    try {
        $root = (& git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) {
            return (Resolve-Path -LiteralPath $root).Path
        }
    } catch { }
    return (Get-Location).Path
}

function Resolve-Preset {
    param([string]$PathValue, [string]$IdValue, [string]$Root)

    if (-not [string]::IsNullOrWhiteSpace($PathValue)) {
        $candidate = $PathValue
        if (-not [System.IO.Path]::IsPathRooted($candidate)) {
            $candidate = Join-Path $Root $candidate
        }
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "PresetPath wurde nicht gefunden: $candidate"
        }
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    if ([string]::IsNullOrWhiteSpace($IdValue)) {
        throw 'Bitte -PresetPath oder -PresetId angeben.'
    }

    $folder = Join-Path $Root (Join-Path 'local-input' $IdValue)
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        throw "PresetId '$IdValue' wurde nicht gefunden. Erwarteter Ordner: $folder"
    }

    $matches = @(Get-ChildItem -LiteralPath $folder -Filter '*.local.json' -File | Sort-Object Name)
    if ($matches.Count -eq 0) {
        throw "Keine *.local.json-Datei fuer PresetId '$IdValue' gefunden."
    }
    if ($matches.Count -eq 1) {
        return $matches[0].FullName
    }

    $list = ($matches | ForEach-Object { " - $($_.FullName)" }) -join [Environment]::NewLine
    throw "Mehrere Preset-Dateien gefunden. Bitte -PresetPath verwenden:$([Environment]::NewLine)$list"
}

function Get-Value {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-Text {
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    return $text
}

function Get-FirstText {
    param([object]$First, [object]$Second)
    $a = Get-Text $First
    if ($a.Length -gt 0) { return $a }
    return (Get-Text $Second)
}

function Get-IntOrEmpty {
    param([object]$Value)
    $text = Get-Text $Value
    if ($text.Length -eq 0) { return '' }
    try {
        return ([int]$text).ToString([Globalization.CultureInfo]::InvariantCulture)
    } catch {
        return ''
    }
}

function Get-TwzNumber {
    param([object]$Participant)
    foreach ($field in @('twzManual', 'dwz', 'eloStandard')) {
        $text = Get-IntOrEmpty (Get-Value $Participant $field)
        if ($text.Length -gt 0) {
            $value = [int]$text
            if ($value -gt 0) { return $value }
        }
    }
    return 0
}

function Escape-CsvField {
    param([object]$Value)
    $text = Get-Text $Value
    $text = $text -replace '"', '""'
    if ($text.Contains(';') -or $text.Contains('"') -or $text.Contains("`n") -or $text.Contains("`r")) {
        return '"' + $text + '"'
    }
    return $text
}

function Get-Notes {
    param([object]$Participant)
    $items = @()
    $lookup = Get-Text (Get-Value $Participant 'lookupConfidence')
    $rating = Get-Text (Get-Value $Participant 'ratingStatus')
    if ($lookup.Length -gt 0) { $items += "Lookup: $lookup" }
    if ($rating.Length -gt 0) { $items += "Rating: $rating" }
    $review = Get-Value $Participant 'manualReviewRequired'
    if ($review -eq $true) { $items += 'Manuelle Pruefung empfohlen' }
    $notes = Get-Value $Participant 'ratingNotes'
    foreach ($note in @($notes)) {
        $noteText = Get-Text $note
        if ($noteText.Length -gt 0) { $items += $noteText }
    }
    return ($items -join '; ')
}

function Convert-ToCsvContent {
    param([object[]]$Participants)

    $seen = @{}
    $rows = @()
    $index = 0
    foreach ($participant in $Participants) {
        $name = Get-FirstText (Get-Value $participant 'name') (Get-Value $participant 'fullName')
        if ($name.Length -eq 0) { throw 'Teilnehmer ohne name/fullName gefunden.' }
        $key = $name.Trim().ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            Write-Warning "Doppelten Teilnehmer uebersprungen: $name"
            continue
        }
        $seen[$key] = $true
        $twz = Get-TwzNumber $participant
        $rows += [pscustomobject]@{
            Sort = ('{0:D6}-{1:D6}' -f (999999 - $twz), $index)
            Participant = $participant
        }
        $index++
    }

    $lines = @('Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen')
    foreach ($row in ($rows | Sort-Object Sort)) {
        $p = $row.Participant
        $name = Get-FirstText (Get-Value $p 'name') (Get-Value $p 'fullName')
        $club = Get-FirstText (Get-Value $p 'club') (Get-Value $p 'verein')
        $fields = @(
            $name,
            $club,
            (Get-IntOrEmpty (Get-Value $p 'birthYear')),
            'Unknown',
            (Get-IntOrEmpty (Get-Value $p 'dwz')),
            (Get-IntOrEmpty (Get-Value $p 'dwzIndex')),
            (Get-IntOrEmpty (Get-Value $p 'eloStandard')),
            (Get-IntOrEmpty (Get-Value $p 'twzManual')),
            (Get-Text (Get-Value $p 'fideId')),
            (Get-Text (Get-Value $p 'dsbId')),
            (Get-Text (Get-Value $p 'title')),
            'Active',
            (Get-Notes $p)
        )
        $lines += (($fields | ForEach-Object { Escape-CsvField $_ }) -join ';')
    }

    return ($lines -join [Environment]::NewLine)
}

function Invoke-Json {
    param([string]$Method, [string]$Uri, [object]$Body)
    $args = @{
        Method = $Method
        Uri = $Uri
        Headers = @{ Accept = 'application/json' }
    }
    if ($null -ne $Body) {
        $args['ContentType'] = 'application/json; charset=utf-8'
        $args['Body'] = ($Body | ConvertTo-Json -Depth 40)
    }
    try {
        return Invoke-RestMethod @args
    } catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message)) {
            $message += "`n$($_.ErrorDetails.Message)"
        }
        throw $message
    }
}

$repoRoot = Get-RepoRoot
$presetFile = Resolve-Preset -PathValue $PresetPath -IdValue $PresetId -Root $repoRoot
$preset = Get-Content -LiteralPath $presetFile -Raw -Encoding UTF8 | ConvertFrom-Json
$participants = @(Get-Value $preset 'participants')
if ($participants.Count -eq 0) { throw "Preset enthaelt keine participants: $presetFile" }

$tournament = Get-Value $preset 'tournament'
$tournamentName = Get-FirstText (Get-Value $tournament 'name') 'Importiertes Turnier'
$roundText = Get-IntOrEmpty (Get-Value $tournament 'rounds')
$rounds = 5
if ($roundText.Length -gt 0) { $rounds = [int]$roundText }

$csvContent = Convert-ToCsvContent -Participants $participants
$lineCount = ($csvContent -split "`r?`n").Count - 1

$reportDir = Join-Path $repoRoot 'output\reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path $reportDir "preset-import-$stamp.csv"
Set-Content -LiteralPath $csvPath -Value $csvContent -Encoding UTF8

Write-Host "Preset: $presetFile"
Write-Host "Turnier: $tournamentName"
Write-Host "Teilnehmer: $lineCount"
Write-Host "CSV: $csvPath"

if ($DryRun) {
    Write-Host 'DryRun: Keine API-Aenderung ausgefuehrt.'
    Get-Content -LiteralPath $csvPath -Encoding UTF8 | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
    exit 0
}

if (-not $CreateTournament) {
    throw 'Keine Aenderung ausgefuehrt. Fuer Import bitte -CreateTournament angeben oder zuerst -DryRun verwenden.'
}

$base = $ApiBaseUrl.TrimEnd('/')
$health = Invoke-Json -Method 'GET' -Uri ($base + '/api/health') -Body $null
Write-Host "Health: $($health.status)"

$settings = @{
    format = 1
    scoringSystem = 0
    twzSource = 0
    plannedRounds = $rounds
    tiebreaks = @(0, 1, 2, 4, 6, 99)
    allowManualPairingOverrides = $true
    forfeitTiebreakPolicy = 0
    countByeAsWin = $false
    seniorBirthYearOrEarlier = $null
    heroCupMinimumRatedGames = 1
}
$createBody = @{ name = $tournamentName; settings = $settings }
$created = Invoke-Json -Method 'POST' -Uri ($base + '/api/tournaments') -Body $createBody
$tournamentId = [string]$created.id
if ([string]::IsNullOrWhiteSpace($tournamentId)) {
    throw "Turnier wurde erstellt, aber Antwort enthaelt keine id: $($created | ConvertTo-Json -Depth 20)"
}
Write-Host "Turnier erstellt: $tournamentId"

$importBody = @{ content = $csvContent; replaceExisting = [bool]$OverwriteExisting }
$imported = Invoke-Json -Method 'POST' -Uri ($base + "/api/tournaments/$tournamentId/players/import.csv") -Body $importBody

$resultPath = Join-Path $reportDir "preset-import-result-$stamp.json"
$result = @{
    tournamentId = $tournamentId
    tournamentName = $tournamentName
    csvPath = $csvPath
    importedCount = @($imported).Count
    apiBaseUrl = $ApiBaseUrl
    dashboard = 'http://localhost:5173'
}
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host "Import erfolgreich. Teilnehmer importiert: $(@($imported).Count)"
Write-Host "Report: $resultPath"
Write-Host 'Dashboard: http://localhost:5173'
