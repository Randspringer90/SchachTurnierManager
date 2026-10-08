#requires -Version 7.0
# Real React event/request regressions. Synthetic tournaments; source-only, headless.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port = 5099,
    [int]$MarionettePort = 2839,
    [string]$FirefoxPath = 'C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed = 0
function Wait-Csv([string]$Script) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if (Invoke-MarionetteScript $Script) { return $true }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw 'CSV smoke condition timed out.'
}
function Assert-Csv([string]$Name, [string]$Script) {
    if (-not (Invoke-MarionetteScript $Script)) { throw "CSV smoke failed: $Name" }
    $script:passed++
    Write-Host "[PASS] $Name"
}
function Click-Csv([string]$Text) {
    $found = Invoke-MarionetteScript -Arguments @($Text) -Script @'
const target = [...document.querySelectorAll('button')].find(n => n.textContent.trim() === arguments[0] && !n.disabled);
if (!target) return false;
document.querySelectorAll('[data-csv-smoke]').forEach(n => n.removeAttribute('data-csv-smoke'));
target.setAttribute('data-csv-smoke', 'click'); return true;
'@
    if (-not $found) { throw "CSV smoke control unavailable: $Text" }
    Invoke-MarionetteClick (Find-MarionetteElement '[data-csv-smoke="click"]')
}
function Set-Csv([string]$Content) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Content))
    Invoke-MarionettePageScript @"
(function() {
const node = document.querySelector('textarea[rows="7"]');
Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(node, atob('$encoded'));
node.dispatchEvent(new Event('input', { bubbles: true }));
})();
"@
}
function Select-CsvTournament([string]$Name) {
    $null = Invoke-MarionetteScript -Arguments @($Name) -Script @'
const target = [...document.querySelectorAll('.list button')].find(n => n.textContent.startsWith(arguments[0]));
if (!target) throw new Error('Synthetic tournament absent'); target.click(); return true;
'@
    $null = Wait-Csv ('return document.querySelector(".list button.selected").textContent.startsWith("' + $Name + '");')
}
function Release-Csv([int]$Index, [int]$Rows) {
    Invoke-MarionettePageScript "window.__csvSmoke.release($Index, $Rows);"
    $null = Wait-Csv "return window.wrappedJSObject.__csvSmoke.queue[$Index].settled;"
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
    foreach ($name in @('CSV Synthetic Alpha', 'CSV Synthetic Beta')) {
        $created = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments') -Method Post -ContentType 'application/json' -Body (@{name=$name;settings=$null} | ConvertTo-Json) -NoProxy -MaximumRedirection 0
        if ($name -ceq 'CSV Synthetic Beta') { $betaId = [string]$created.id }
    }
    Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profile | Out-Null
    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    Start-MarionetteSession | Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    $null = Wait-Csv 'return !!document.querySelector(".list button");'
    Invoke-MarionettePageScript 'localStorage.setItem("stm.activeMainTab", "print");'
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    $null = Wait-Csv 'return !!document.querySelector("textarea[rows=\"7\"]");'
    $null = Wait-Csv 'return [...document.querySelectorAll(".list button")].some(n => n.textContent.startsWith("CSV Synthetic Alpha")) && [...document.querySelectorAll(".list button")].some(n => n.textContent.startsWith("CSV Synthetic Beta"));'
    Select-CsvTournament 'CSV Synthetic Alpha'
    Invoke-MarionettePageScript @'
window.__csvSmoke = { queue: [], imports: [], mock: true };
const original = window.fetch.bind(window), state = window.__csvSmoke;
window.fetch = function(input, options) {
  const url = typeof input === 'string' ? input : input.url;
  if (url.endsWith('/players/import.csv')) state.imports.push({url, body: JSON.parse(options.body)});
  if (!state.mock || !url.endsWith('/players/preview-import.csv')) return original(input, options);
  // Ignore AbortSignal deliberately: prove generation guards, not producer cooperation.
  return new Promise(resolve => state.queue.push({url, body: JSON.parse(options.body), resolve, settled: false}));
};
state.release = function(index, rows) {
  const item = state.queue[index];
  item.resolve(new Response(JSON.stringify({ totalRows: rows, importableRows: rows, warningRows: 0,
    blockingRows: 0, likelyDuplicateRows: 0, hasBlockingIssues: false,
    replaceExisting: item.body.replaceExisting, globalWarnings: [], rows: [] }),
    {status: 200, headers: {'Content-Type': 'application/json'}}));
  // A following task runs after fetch/json continuations and React updates.
  setTimeout(() => { item.settled = true; }, 100);
};
'@
    Set-Csv "Name`nSynthetic CSV A"
    Click-Csv 'Import prüfen'
    $null = Wait-Csv 'return window.wrappedJSObject.__csvSmoke.queue.length === 1;'
    Set-Csv "Name`nSynthetic CSV B"
    Release-Csv 0 11
    Assert-Csv 'CSV B rejects late CSV A preview in the real App' 'return !document.querySelector(".preview-summary") && [...document.querySelectorAll("button")].find(n => n.textContent === "CSV importieren").disabled;'

    Click-Csv 'Import prüfen'
    $null = Wait-Csv 'return window.wrappedJSObject.__csvSmoke.queue.length === 2;'
    Select-CsvTournament 'CSV Synthetic Beta'
    Release-Csv 1 12
    Assert-Csv 'Tournament Beta rejects late Alpha preview' 'return !document.querySelector(".preview-summary") && [...document.querySelectorAll("button")].find(n => n.textContent === "CSV importieren").disabled;'

    Click-Csv 'Import prüfen'
    $null = Wait-Csv 'return window.wrappedJSObject.__csvSmoke.queue.length === 3;'
    Release-Csv 2 13
    $null = Wait-Csv 'return !!document.querySelector(".preview-summary");'
    $null = Invoke-MarionetteScript 'const box = document.querySelector("textarea[rows=\"7\"]").parentElement.querySelector("input[type=checkbox]"); box.click(); return true;'
    Assert-Csv 'Replace change revokes an accepted preview' 'return !document.querySelector(".preview-summary") && [...document.querySelectorAll("button")].find(n => n.textContent === "CSV importieren").disabled;'
    $null = Invoke-MarionetteScript 'document.querySelector("textarea[rows=\"7\"]").parentElement.querySelector("input[type=checkbox]").click(); return true;'

    Click-Csv 'Import prüfen'; Click-Csv 'Import prüfen'
    $null = Wait-Csv 'return window.wrappedJSObject.__csvSmoke.queue.length === 5;'
    Release-Csv 4 15
    $null = Wait-Csv 'return document.querySelector(".preview-summary")?.textContent.includes("15 Zeilen");'
    Release-Csv 3 14
    Assert-Csv 'Reverse responses preserve only the latest generation' 'return document.querySelector(".preview-summary").textContent.includes("15 Zeilen") && !document.querySelector(".preview-summary").textContent.includes("14 Zeilen");'
    Assert-Csv 'All invalid scenarios sent no import request' 'return window.wrappedJSObject.__csvSmoke.imports.length === 0;'

    Invoke-MarionettePageScript 'window.__csvSmoke.mock = false;'
    Set-Csv "Name`nSynthetic Normal Import"
    Click-Csv 'Import prüfen'
    $null = Wait-Csv 'return !!document.querySelector(".preview-summary") && ![...document.querySelectorAll("button")].find(n => n.textContent === "CSV importieren").disabled;'
    Click-Csv 'CSV importieren'
    $null = Wait-Csv 'return document.querySelector(".status-line").textContent.includes("1 Teilnehmer importiert");'
    $beta = Invoke-RestMethod ($smoke.BaseUrl + '/api/tournaments/' + $betaId) -NoProxy -MaximumRedirection 0
    if (@($beta.players).Count -ne 1 -or $beta.players[0].name -cne 'Synthetic Normal Import') { throw 'Normal import did not persist the intended player in Beta.' }
    $bound = Invoke-MarionetteScript -Arguments @($betaId) -Script 'const state = window.wrappedJSObject.__csvSmoke; return state.imports.length === 1 && state.imports[0].body.content === "Name\nSynthetic Normal Import" && state.imports[0].body.replaceExisting === false && state.imports[0].url === "/api/tournaments/" + arguments[0] + "/players/import.csv";'
    if (-not $bound) { throw 'Normal import request identity mismatch.' }
    $passed++
    Write-Host '[PASS] Unchanged preview imports once with the exact payload and tournament'
    Write-Host "CSV_PREVIEW_BROWSER=$passed PASS; 0 FAIL; 0 SKIP"
}
catch { $smoke.Failed = $true; throw }
finally {
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke
}
