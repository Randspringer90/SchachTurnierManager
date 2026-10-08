#requires -Version 7.0
# Real editor ownership regressions, including cloned tournaments with shared IDs.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port = 5100,
    [int]$MarionettePort = 2840,
    [string]$FirefoxPath = 'C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed = 0
function Wait-Editor([string]$Script) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if (Invoke-MarionetteScript $Script) { return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'Editor smoke condition timed out.'
}
function Assert-Editor([string]$Name, [string]$Script) {
    if (-not (Invoke-MarionetteScript $Script)) { throw "Editor smoke failed: $Name" }
    $script:passed++; Write-Host "[PASS] $Name"
}
function Select-EditorTournament([string]$Name) {
    $null = Invoke-MarionetteScript -Arguments @($Name) -Script @'
const node = [...document.querySelectorAll('.list button')].find(n => n.textContent.startsWith(arguments[0]));
if (!node) throw new Error('Synthetic tournament missing'); node.click(); return true;
'@
    Wait-Editor ('return document.querySelector(".list button.selected").textContent.startsWith("' + $Name + '");')
}
function Set-EditorInput([string]$Selector, [string]$Value) {
    $selectorJson = $Selector | ConvertTo-Json -Compress
    $valueJson = $Value | ConvertTo-Json -Compress
    Invoke-MarionettePageScript @"
(function() { const node = document.querySelector($selectorJson);
Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(node, $valueJson);
node.dispatchEvent(new Event('input', { bubbles: true })); })();
"@
}
try {
    $profile = Join-Path $smoke.DataDirectory 'ff-profile'
    New-Item -ItemType Directory -Path $profile -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $profile 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
    Start-StmFirefoxBackend -Context $smoke | Out-Null
    $alpha = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments') -Method Post -ContentType 'application/json' -Body '{"name":"Editor Synthetic Alpha","settings":{"format":0,"plannedRounds":3}}' -NoProxy -MaximumRedirection 0
    foreach ($name in @('Synthetic One', 'Synthetic Two')) {
        $null = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $alpha.id + '/players') -Method Post -ContentType 'application/json' -Body (@{name=$name} | ConvertTo-Json) -NoProxy -MaximumRedirection 0
    }
    $null = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $alpha.id + '/pairings/next-round') -Method Post -ContentType 'application/json' -Body '{}' -NoProxy -MaximumRedirection 0
    $original = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $alpha.id) -NoProxy -MaximumRedirection 0
    $clone = $original | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $clone.id = [Guid]::NewGuid().ToString(); $clone.name = 'Editor Synthetic Beta'
    $null = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/import') -Method Post -ContentType 'application/json' -Body (@{tournament=$clone;overwriteExisting=$false} | ConvertTo-Json -Depth 100) -NoProxy -MaximumRedirection 0
    $betaBefore = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $clone.id) -NoProxy -MaximumRedirection 0 | ConvertTo-Json -Depth 100 -Compress
    Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile | Out-Null
    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    Start-MarionetteSession | Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Wait-Editor 'return document.querySelectorAll(".list button").length === 2;'
    Invoke-MarionettePageScript 'localStorage.setItem("stm.activeMainTab", "participants");'
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Wait-Editor 'return !!document.querySelector(".player-form");'
    Wait-Editor 'return [...document.querySelectorAll(".list button")].some(n => n.textContent.startsWith("Editor Synthetic Alpha")) && [...document.querySelectorAll(".list button")].some(n => n.textContent.startsWith("Editor Synthetic Beta"));'
    Select-EditorTournament 'Editor Synthetic Alpha'
    Wait-Editor 'return document.querySelectorAll(".participant-table tbody tr").length === 2;'
    $null = Invoke-MarionetteScript 'document.querySelector(".participant-table tbody button").click(); return true;'
    Wait-Editor 'return document.querySelector(".player-form button[type=submit]").textContent === "Aktualisieren";'
    Set-EditorInput '.player-form input[aria-label="Name, erforderlich"]' 'A unsaved edit'
    Select-EditorTournament 'Editor Synthetic Beta'
    Assert-Editor 'Selection resets the old player ID and form despite shared GUIDs' 'return document.querySelector(".player-form button[type=submit]").textContent === "Speichern" && document.querySelector(".player-form input[aria-label=\"Name, erforderlich\"]").value === "";'

    Select-EditorTournament 'Editor Synthetic Alpha'
    $null = Invoke-MarionetteScript 'document.querySelector(".participant-table tbody button").click(); return true;'
    Wait-Editor 'return document.querySelector(".player-form button[type=submit]").textContent === "Aktualisieren";'
    Set-EditorInput '.player-form input[aria-label="Name, erforderlich"]' 'A saving edit'
    Invoke-MarionettePageScript @'
window.__editorSmoke = {queue: [], writes: [], hold: true};
const state = window.__editorSmoke, originalFetch = window.fetch.bind(window);
window.fetch = function(input, options) {
  const url = typeof input === 'string' ? input : input.url;
  if (state.hold && options?.method === 'PUT' && (/\/players\//.test(url) || url.endsWith('/pairing'))) {
    state.writes.push({url, body: JSON.parse(options.body)});
    return new Promise(resolve => state.queue.push({resolve, settled:false}));
  }
  return originalFetch(input, options);
};
state.release = function(index) { state.queue[index].resolve(new Response('{}', {status:200, headers:{'Content-Type':'application/json'}}));
  setTimeout(() => {state.queue[index].settled=true;}, 100); };
'@
    $null = Invoke-MarionetteScript 'document.querySelector(".player-form").requestSubmit(); return true;'
    Wait-Editor 'return window.wrappedJSObject.__editorSmoke.queue.length === 1;'
    Select-EditorTournament 'Editor Synthetic Beta'
    Set-EditorInput '.player-form input[aria-label="Name, erforderlich"]' 'B current draft'
    Invoke-MarionettePageScript 'window.__editorSmoke.release(0);'
    Wait-Editor 'return window.wrappedJSObject.__editorSmoke.queue[0].settled;'
    Assert-Editor 'Late save from A leaves the new B draft intact' 'return document.querySelector(".player-form input[aria-label=\"Name, erforderlich\"]").value === "B current draft" && document.querySelector(".player-form button[type=submit]").textContent === "Speichern";'
    $bound = Invoke-MarionetteScript -Arguments @($alpha.id) -Script 'return window.wrappedJSObject.__editorSmoke.writes.length === 1 && window.wrappedJSObject.__editorSmoke.writes[0].url.startsWith("/api/tournaments/" + arguments[0] + "/players/");'
    if (-not $bound) { throw 'Save did not remain bound to Alpha.' }; $passed++

    $null = Invoke-MarionetteScript '[...document.querySelectorAll(".tab-bar button")].find(n => n.textContent.includes("Runde")).click(); return true;'
    Wait-Editor 'return !!document.querySelector("input[aria-label=\"Grund der manuellen Korrektur\"]");'
    Select-EditorTournament 'Editor Synthetic Alpha'
    Set-EditorInput 'input[aria-label="Grund der manuellen Korrektur"]' 'A pairing draft'
    Select-EditorTournament 'Editor Synthetic Beta'
    Assert-Editor 'Matching round and board keys in B do not retain A pairing draft' 'return document.querySelector("input[aria-label=\"Grund der manuellen Korrektur\"]").value !== "A pairing draft";'
    Select-EditorTournament 'Editor Synthetic Alpha'
    Set-EditorInput 'input[aria-label="Grund der manuellen Korrektur"]' 'A pairing save'
    $null = Invoke-MarionetteScript 'document.querySelector(".manual-pairing-disclosure").open = true; [...document.querySelectorAll("button")].find(n => n.textContent === "Paarung speichern").click(); return true;'
    Wait-Editor 'return window.wrappedJSObject.__editorSmoke.queue.length === 2;'
    Select-EditorTournament 'Editor Synthetic Beta'
    Set-EditorInput 'input[aria-label="Grund der manuellen Korrektur"]' 'B current pairing'
    Invoke-MarionettePageScript 'window.__editorSmoke.release(1);'
    Wait-Editor 'return window.wrappedJSObject.__editorSmoke.queue[1].settled;'
    Assert-Editor 'Late pairing save cannot clear a newer B draft' 'return document.querySelector("input[aria-label=\"Grund der manuellen Korrektur\"]").value === "B current pairing";'
    $betaAfter = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $clone.id) -NoProxy -MaximumRedirection 0 | ConvertTo-Json -Depth 100 -Compress
    if ($betaBefore -cne $betaAfter) { throw 'Editor switching changed persisted Beta data.' }; $passed++
    Invoke-MarionettePageScript 'window.__editorSmoke.hold = false;'
    $null = Invoke-MarionetteScript '[...document.querySelectorAll(".tab-bar button")].find(n => n.textContent.includes("Teilnehmer")).click(); return true;'
    Wait-Editor 'return !!document.querySelector(".player-form");'
    Set-EditorInput '.player-form input[aria-label="Name, erforderlich"]' 'Synthetic Normal Save'
    $null = Invoke-MarionetteScript 'document.querySelector(".player-form").requestSubmit(); return true;'
    Wait-Editor 'return document.querySelector(".status-line").textContent.includes("Teilnehmer gespeichert");'
    $normal = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $clone.id) -NoProxy -MaximumRedirection 0
    if (@($normal.players | Where-Object name -CEQ 'Synthetic Normal Save').Count -ne 1 -or @($normal.players).Count -ne 3) { throw 'Normal unchanged editor save failed.' }; $passed++
    Write-Host "TOURNAMENT_EDITOR_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}
catch { $smoke.Failed = $true; throw }
finally {
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke
}
