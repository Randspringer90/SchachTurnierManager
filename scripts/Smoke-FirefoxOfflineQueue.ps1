#requires -Version 7.0
# Native browser acceptance on an owned loopback server and synthetic SQLite DB.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port = 5093,
    [int]$MarionettePort = 2843,
    [string]$FirefoxPath = 'C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed = 0
function Assert-Smoke([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAIL: $Name" }
    $script:passed++; Write-Host "PASS $Name"
}
function Wait-Js([string]$Script, [int]$Seconds = 35) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        if (Invoke-MarionetteScript $Script) { return $true }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}
function Click-Text([string]$Text, [string]$Scope = 'document') {
    $encoded = $Text | ConvertTo-Json -Compress
    $script = "const root = $Scope; const node = [...root.querySelectorAll('button')].find(n => n.textContent.trim() === $encoded && !n.disabled); if(!node) return false; node.click(); return true;"
    if (-not (Invoke-MarionetteScript $script)) { throw 'Expected enabled native browser button was not found.' }
}
function Open-Rounds {
    Click-Text 'Runde'
    Assert-Smoke (Wait-Js "return !!document.querySelector('select[aria-label*=`"Brett 1`"]');") 'round result controls are available'
}
function Choose-Result([int]$Board, [int]$Result) {
    Invoke-MarionettePageScript @"
(() => {
 const select = document.querySelector('select[aria-label="Ergebnis: Runde 1, Brett $Board"]');
 if (!select || select.disabled) throw new Error('Synthetic board control missing');
 Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value').set.call(select, '$Result');
 select.dispatchEvent(new Event('change', {bubbles:true}));
})();
"@
    Assert-Smoke (Wait-Js "return !!document.querySelector('.result-confirm');") 'result confirmation opens in the application'
}
function Enable-LocalQueue {
    Invoke-MarionetteScript "const box=document.querySelector('.result-confirm input[type=checkbox]'); if(!box) return false; if(!box.checked) box.click(); return box.checked;" | Out-Null
}
function Confirm-Result {
    $saved = Invoke-MarionetteScript "const buttons=[...document.querySelectorAll('.result-confirm button')]; const button=buttons.at(-1); if(!button || button.disabled) return false; button.click(); return true;"
    Assert-Smoke ([bool]$saved) 'result confirmation is submitted'
}
function Read-Tournament {
    return Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments/$($script:tournamentId)" -NoProxy -MaximumRedirection 0
}
function Post-Result([int]$Board, [int]$Result) {
    $body = @{roundNumber=1;boardNumber=$Board;result=$Result} | ConvertTo-Json
    Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments/$($script:tournamentId)/results" -NoProxy -MaximumRedirection 0 -Method Post -ContentType 'application/json' -Body $body | Out-Null
}
function Window-Value($Result) {
    if ($Result -is [string]) { return $Result }
    if ($Result.PSObject.Properties.Name -contains 'value') { return $Result.value }
    return $Result.handle
}
try {
    New-Item -ItemType Directory -Path $smoke.DataDirectory | Out-Null
    $backend = Start-StmFirefoxBackend $smoke
    $body = @{ name='Synthetic queue browser'; settings=@{format=0;plannedRounds=3;allowManualPairingOverrides=$true} } | ConvertTo-Json
    $tournament = Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments" -NoProxy -MaximumRedirection 0 -Method Post -ContentType 'application/json' -Body $body
    $script:tournamentId = $tournament.id
    foreach ($number in 1..4) {
        $player = @{name="Synthetic queue $number";status=0;elo=(2000-$number)} | ConvertTo-Json
        Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments/$tournamentId/players" -NoProxy -MaximumRedirection 0 -Method Post -ContentType 'application/json' -Body $player | Out-Null
    }
    Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments/$tournamentId/pairings/next-round" -NoProxy -MaximumRedirection 0 -Method Post | Out-Null
    $profile = Join-Path $smoke.DataDirectory 'profile'
    New-Item -ItemType Directory -Path $profile | Out-Null
    @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@ | Set-Content -LiteralPath (Join-Path $profile 'user.js')
    $browser = Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile
    Connect-Marionette -Port $MarionettePort | Out-Null
    $session = Start-MarionetteSession
    Write-Host "NATIVE_BROWSER=$($session.capabilities.browserName)/$($session.capabilities.browserVersion)"
    Write-Host "OWNED_BACKEND_PID=$($backend.Process.Id) PORT=$Port DATABASE=$(Join-Path $smoke.DataDirectory 'smoke.sqlite')"
    Write-Host "SOURCE_ASSEMBLY_SHA256=$((Get-FileHash -LiteralPath $smoke.SourceAssemblyPath -Algorithm SHA256).Hash)"
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Assert-Smoke (Wait-Js "return !!document.querySelector('.status-card .ok') && [...document.querySelectorAll('.list button')].some(n=>n.textContent.includes('Synthetic queue browser'));") 'native browser connects to the owned synthetic tournament'
    Open-Rounds
    Choose-Result 1 1
    Confirm-Result
    Assert-Smoke (Wait-Js "return !document.querySelector('.result-confirm') && document.querySelector('select[aria-label*=`"Brett 1`"]')?.value === '1';") 'ordinary UI result receives a server acknowledgement'

    # Observe the actual six projection reads in window A while editing settings.
    Invoke-MarionettePageScript @'
window.__queueProjectionReads=[];
const previousFetch=window.fetch;
window.fetch=function(input, init) {
 const url=String(input);
 if(!init?.method && /\/(standings|categories|cross-table|hero-cup|round-diagnostics|audit-journal)$/.test(url)) window.__queueProjectionReads.push(url);
 return previousFetch.apply(this,arguments);
};
'@
    $windowA = Window-Value (Invoke-MarionetteCommand 'WebDriver:GetWindowHandle')
    $windowB = Window-Value (Invoke-MarionetteCommand 'WebDriver:NewWindow' @{type='tab'})
    Invoke-MarionetteCommand 'WebDriver:SwitchToWindow' @{handle=$windowB} | Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Assert-Smoke (Wait-Js "return !!document.querySelector('.status-card .ok');") 'second real browser window connects'
    Open-Rounds
    Choose-Result 2 3
    Enable-LocalQueue
    Confirm-Result
    Assert-Smoke (Wait-Js "return !document.querySelector('.result-confirm') && document.querySelector('select[aria-label*=`"Brett 2`"]')?.value === '3';") 'second window commits a different board'
    Invoke-MarionetteCommand 'WebDriver:SwitchToWindow' @{handle=$windowA} | Out-Null
    Assert-Smoke (Wait-Js "return document.querySelector('select[aria-label*=`"Brett 2`"]')?.value === '3';") 'first window sees same-tournament changes without reload'
    Assert-Smoke (Wait-Js "const reads=window.wrappedJSObject.__queueProjectionReads; return ['standings','categories','cross-table','hero-cup','round-diagnostics','audit-journal'].every(name=>reads.some(url=>url.endsWith('/'+name)));") 'all six projections refresh after the other window changes the tournament'
    Click-Text 'Mehr'
    Assert-Smoke (Wait-Js "const node=[...document.querySelectorAll('.more-grid button')].find(n=>n.textContent.trim().startsWith('Verwaltung & Audit')); if(!node) return false; node.click(); return true;") 'administration is reached through the real More navigation'
    Assert-Smoke (Wait-Js "return !!document.querySelector('input[type=number][max=`"99`"]');") 'settings editor is available'
    Invoke-MarionettePageScript @'
const input=document.querySelector('input[type=number][max="99"]');
Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set.call(input,'11');
input.dispatchEvent(new Event('input',{bubbles:true}));
'@
    $current = Read-Tournament
    $current.settings.plannedRounds = 9
    $settingsBody = @{settings=$current.settings} | ConvertTo-Json -Depth 8
    Invoke-RestMethod "$($smoke.BaseUrl)/api/tournaments/$tournamentId/settings" -NoProxy -MaximumRedirection 0 -Method Put -ContentType 'application/json' -Body $settingsBody | Out-Null
    Assert-Smoke (Wait-Js "return document.querySelector('input[type=number][max=`"99`"]')?.value === '11';") 'unsaved settings input remains intact'
    # Wait across an actual periodic probe, then verify the same input again.
    $deadline = [DateTime]::UtcNow.AddSeconds(12)
    while ([DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 250 }
    Assert-Smoke ([bool](Invoke-MarionetteScript "return document.querySelector('input[type=number][max=`"99`"]')?.value === '11';")) 'polling and an external settings change preserve unsaved input'
    Invoke-MarionetteCommand 'WebDriver:SwitchToWindow' @{handle=$windowB} | Out-Null
    Invoke-MarionetteCommand 'WebDriver:CloseWindow' | Out-Null
    Invoke-MarionetteCommand 'WebDriver:SwitchToWindow' @{handle=$windowA} | Out-Null
    Open-Rounds
    Assert-Smoke (Wait-Js 'return !!navigator.serviceWorker.controller;' 30) 'offline application shell is controlled by its real service worker'

    Choose-Result 1 2
    Enable-LocalQueue
    Stop-StmFirefoxBackend -Context $smoke -Handle $backend
    Confirm-Result
    Assert-Smoke (Wait-Js "return document.querySelector('.status-line')?.textContent.includes('in diesem Browser vorgemerkt');" 40) 'transport failure retains a durable unacknowledged result'
    Assert-Smoke ([bool](Invoke-MarionetteScript "return document.querySelectorAll('.offline-result-queue li').length === 1;")) 'pending result is visible as pending'
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Assert-Smoke (Wait-Js "return document.querySelectorAll('.offline-result-queue li').length === 1;" 35) 'queue survives a real offline browser reload'
    $backend = Start-StmFirefoxBackend $smoke
    Click-Text 'Ergebnisse synchronisieren' 'document.querySelector(".offline-result-queue")'
    Assert-Smoke (Wait-Js "return !document.querySelector('.offline-result-queue');") 'replay acknowledges and removes the durable entry'
    $current = Read-Tournament
    Assert-Smoke ($current.rounds[0].pairings[0].result.kind -eq 2) 'restarted SQLite backend holds the replayed result'

    # The server really commits, then a controlled client transport fault loses
    # the response. Retrying must use the same receipt, without a second audit.
    Open-Rounds
    Invoke-MarionettePageScript @'
window.__queueFaultIds=[];
const transport=window.fetch;
window.__queueLoseReply=true;
window.fetch=async function(input,init) {
 const response=await transport.apply(this,arguments);
 if(String(input).endsWith('/queued-results')) {
   window.__queueFaultIds.push(JSON.parse(init.body).mutationId);
   if(window.__queueLoseReply) { window.__queueLoseReply=false; throw new TypeError('Synthetic lost reply'); }
 }
 return response;
};
'@
    Choose-Result 1 3
    Enable-LocalQueue
    Confirm-Result
    Assert-Smoke (Wait-Js "return document.querySelector('.status-line')?.textContent.includes('in diesem Browser vorgemerkt');") 'lost successful response keeps the queue entry'
    $beforeReplay = @((Read-Tournament).auditJournal | Where-Object { $_.action -eq 21 }).Count
    Assert-Smoke ($beforeReplay -ge 4) 'the real result audit entries exist before retry'
    Click-Text 'Ergebnisse synchronisieren' 'document.querySelector(".offline-result-queue")'
    Assert-Smoke (Wait-Js "return !document.querySelector('.offline-result-queue');") 'lost-response replay completes'
    Assert-Smoke ([bool](Invoke-MarionetteScript 'const ids=window.wrappedJSObject.__queueFaultIds; return ids.length===2 && ids[0]===ids[1];')) 'real repeated requests carry the identical mutation ID'
    Assert-Smoke (@((Read-Tournament).auditJournal | Where-Object { $_.action -eq 21 }).Count -eq $beforeReplay) 'idempotent retry creates no additional result audit'

    Choose-Result 1 1
    Enable-LocalQueue
    Stop-StmFirefoxBackend -Context $smoke -Handle $backend
    Confirm-Result
    Assert-Smoke (Wait-Js "return document.querySelector('.status-line')?.textContent.includes('in diesem Browser vorgemerkt');" 40) 'second offline change is durably queued'
    $backend = Start-StmFirefoxBackend $smoke
    Post-Result 1 2
    Click-Text 'Ergebnisse synchronisieren' 'document.querySelector(".offline-result-queue")'
    Assert-Smoke (Wait-Js "return document.querySelector('.offline-result-queue')?.textContent.includes('Konflikt:');") 'stale replay becomes a visible conflict'
    Assert-Smoke ((Read-Tournament).rounds[0].pairings[0].result.kind -eq 2) 'conflict never overwrites the newer server result'
    Click-Text 'Lokalen Eintrag verwerfen' 'document.querySelector(".offline-result-queue")'
    Assert-Smoke (Wait-Js "return !!document.querySelector('[role=alertdialog]');") 'discard requires an application confirmation'
    Click-Text 'Eintrag verwerfen' 'document.querySelector("[role=alertdialog]")'
    Assert-Smoke (Wait-Js "return !document.querySelector('.offline-result-queue');") 'confirmed discard removes only the local queue entry'
    Assert-Smoke ((Read-Tournament).rounds[0].pairings[0].result.kind -eq 2) 'discard does not mutate the server result'
    Write-Host "FIREFOX_OFFLINE_QUEUE=PASS ASSERTIONS=$passed"
}
catch { $smoke.Failed = $true; throw }
finally {
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke
}
