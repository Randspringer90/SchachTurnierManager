[CmdletBinding()]
param(
    [string] $BaseUrl = "http://localhost:5088",
    [string] $FideId = "4610563",
    [switch] $RunLiveTests
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string] $Name,
        [scriptblock] $Action
    )

    Write-Host "[ExternalLookupSmoke] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

$base = $BaseUrl.TrimEnd('/')

Write-Host "[ExternalLookupSmoke] Backend: $base"
Write-Host "[ExternalLookupSmoke] FIDE-ID: $FideId"

$health = Invoke-RestMethod -Uri "$base/api/health" -Method Get
Write-Host "[ExternalLookupSmoke] Health: $($health.app) $($health.version) $($health.status)"

$providers = Invoke-RestMethod -Uri "$base/api/external-players/providers" -Method Get
Write-Host "[ExternalLookupSmoke] Provider:"
$providers | ForEach-Object {
    Write-Host ("  - {0}: Id={1}, Name={2}" -f $_.name, $_.supportsIdLookup, $_.supportsNameSearch)
}

$fide = Invoke-RestMethod -Uri "$base/api/external-players/fide/$FideId" -Method Get
Write-Host "[ExternalLookupSmoke] FIDE-Status: $($fide.status) · $($fide.message)"
if (-not $fide.players -or $fide.players.Count -lt 1) {
    throw "FIDE-Smoke-Test lieferte keinen Treffer."
}

$player = $fide.players[0]
Write-Host ("[ExternalLookupSmoke] Treffer: {0} · FIDE {1} · Elo {2} · Geburtsjahr {3} · Federation {4}" -f $player.name, $player.fideId, $player.elo, $player.birthYear, $player.federation)

if ($player.fideId -ne $FideId) {
    throw "Unerwartete FIDE-ID im Ergebnis: $($player.fideId)"
}

if ($RunLiveTests) {
    $env:STM_RUN_LIVE_LOOKUP_TESTS = "1"
    Invoke-Step "dotnet test LiveExternalPlayerLookupTests" {
        dotnet test --filter "FullyQualifiedName~LiveExternalPlayerLookupTests"
    }
}
