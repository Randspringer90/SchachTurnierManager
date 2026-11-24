#requires -Version 7.0
# Bounded native API workload, synthetic participants and an owned SQLite DB.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [Parameter(Mandatory)][string]$ReportPath,
    [int]$Port = 5094,
    [int]$ReservedControlPort = 2844
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$context = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $ReservedControlPort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$measurements = [Collections.Generic.List[object]]::new()
$ids = [Collections.Generic.List[string]]::new()
$backend = $null
function Request-Load([string]$Path, [string]$Method = 'GET', $Body = $null, [int]$Seconds = 20) {
    $arguments = @{ Uri=($context.BaseUrl+$Path); Method=$Method; NoProxy=$true; MaximumRedirection=0; TimeoutSec=$Seconds }
    if ($null -ne $Body) { $arguments.ContentType='application/json'; $arguments.Body=($Body | ConvertTo-Json -Depth 10 -Compress) }
    $response = Invoke-RestMethod @arguments
    return $response
}
try {
    if (Test-Path -LiteralPath $ReportPath) { throw 'Load report already exists; use a new evidence path.' }
    New-Item -ItemType Directory -Path $context.DataDirectory | Out-Null
    $backend = Start-StmFirefoxBackend $context
    foreach ($count in @(20,100,200)) {
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $tournament = Request-Load '/api/tournaments' 'POST' @{
            name="Synthetic native load $count"; settings=@{format=1;pairingStrategy=1;swissInitialColour=1;plannedRounds=3}
        }
        $ids.Add($tournament.id)
        foreach ($number in 1..$count) {
            $null = Request-Load "/api/tournaments/$($tournament.id)/players" 'POST' @{
                name=('Synthetic load {0:D3}' -f $number); status=0; elo=(2400-$number); startingRank=$number
            }
        }
        $seedMs = $clock.ElapsedMilliseconds
        $clock.Restart()
        $round = Request-Load "/api/tournaments/$($tournament.id)/pairings/next-round" 'POST' $null 130
        $pairing1Ms = $clock.ElapsedMilliseconds
        if (@($round.pairings).Count -ne $count/2) { throw 'Native load produced an incomplete first round.' }
        $clock.Restart()
        foreach ($pair in $round.pairings) {
            $null = Request-Load "/api/tournaments/$($tournament.id)/results" 'POST' @{
                roundNumber=1;boardNumber=$pair.boardNumber;result=2;expectedPreviousResult=0
            }
        }
        $resultsMs = $clock.ElapsedMilliseconds
        $clock.Restart()
        $second = Request-Load "/api/tournaments/$($tournament.id)/pairings/next-round" 'POST' $null 130
        $pairing2Ms = $clock.ElapsedMilliseconds
        if ($second.roundNumber -ne 2 -or @($second.pairings).Count -ne $count/2) { throw 'Native load produced an incomplete second round.' }
        $clock.Restart()
        $standings = @(Request-Load "/api/tournaments/$($tournament.id)/standings")
        $standingMs = $clock.ElapsedMilliseconds
        if ($standings.Count -ne $count -or ($standings | Measure-Object points -Sum).Sum -ne $count/2) {
            throw "Synthetic standings mismatch: rows=$($standings.Count), points=$(($standings | Measure-Object points -Sum).Sum), expectedRows=$count."
        }
        $clock.Restart()
        $backup = Request-Load "/api/tournaments/$($tournament.id)/export/json"
        $exportMs = $clock.ElapsedMilliseconds
        if (@($backup.players).Count -ne $count -or @($backup.rounds).Count -ne 2) { throw 'Native backup lost participants or rounds.' }
        $backend.Process.Refresh()
        $measurements.Add([pscustomobject]@{players=$count;seedMs=$seedMs;pairingRound1Ms=$pairing1Ms;recordResultsMs=$resultsMs;
            pairingRound2Ms=$pairing2Ms;standingsMs=$standingMs;exportMs=$exportMs;
            workingSetBytes=$backend.Process.WorkingSet64;peakWorkingSetBytes=$backend.Process.PeakWorkingSet64;boards=$second.pairings.Count})
        Write-Host "NATIVE_LOAD_PLAYERS=$count ROUND1_MS=$pairing1Ms ROUND2_MS=$pairing2Ms STANDINGS_MS=$standingMs"
    }
    $firstPid = $backend.Process.Id
    Stop-StmFirefoxBackend -Context $context -Handle $backend
    $backend = Start-StmFirefoxBackend $context
    foreach ($id in $ids) {
        $saved = Request-Load "/api/tournaments/$id"
        if (@($saved.rounds).Count -ne 2) { throw 'Native restart lost a persisted round.' }
    }
    $report = [ordered]@{schemaVersion=1;timeUtc=[DateTime]::UtcNow.ToString('o');status='WORKLOAD_COMPLETED';
        interpretation='Measured API workload only; no invented performance SLA and no colleague-PC acceptance.';
        sourceAssemblySha256=(Get-FileHash -LiteralPath $context.SourceAssemblyPath -Algorithm SHA256).Hash;
        port=$Port;firstProcessId=$firstPid;restartProcessId=$backend.Process.Id;synthetic=$true;
        measurements=$measurements;restartPreservedAllRounds=$true}
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($report | ConvertTo-Json -Depth 6))
    $stream = [IO.FileStream]::new([IO.Path]::GetFullPath($ReportPath),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes) } finally { $stream.Dispose() }
    Write-Host 'NATIVE_LOAD=COMPLETED SYNTHETIC_SQLITE_RESTART=PASS'
}
catch { $context.Failed=$true; throw }
finally { Stop-StmFirefoxSmoke -Context $context }
