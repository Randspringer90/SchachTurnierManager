#requires -Version 7.0
# Source-only headless entry/module smoke for the integrated local tools.
# Domain logic is covered by their contract tests; this checks real browser startup.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceAssemblyPath,
    [int]$Port = 5095,
    [int]$MarionettePort = 2831,
    [string]$FirefoxPath = 'C:\Program Files\Mozilla Firefox\firefox.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib/MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib/FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack
$passed = 0
$ownedAssets = [Collections.Generic.List[object]]::new()
$webRoot = Join-Path ([IO.Path]::GetDirectoryName($smoke.SourceAssemblyPath)) 'wwwroot'
$probeName = '__stm-module-probe-' + [Guid]::NewGuid().ToString('N') + '.mjs'
function Add-OwnedSmokeAsset([string]$Name, [string]$Content) {
    if ($Name -notmatch '^__stm-(module-probe|module-failure|module-fixture)-[a-f0-9]{32}\.(mjs|html)$') { throw 'Unsafe owned smoke asset name.' }
    $item = Get-Item -LiteralPath $webRoot -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Source wwwroot became a reparse point.' }
    $path = Join-Path $webRoot $Name
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
    $stream = [IO.FileStream]::new($path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes); $stream.Flush($true) } finally { $stream.Dispose() }
    $ownedAssets.Add([pscustomobject]@{Path=$path;Name=$Name;Hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash})
}
function Invoke-ModuleEvaluationProbe {
    $count = Invoke-MarionetteScript -Arguments @('/' + $probeName) -Script @'
const scripts = [...document.querySelectorAll('script[type="module"][src]')];
if (!scripts.length || scripts.length > 32 || scripts.some(s => new URL(s.src).origin !== location.origin)) return 0;
document.documentElement.dataset.stmSmokeModules = 'pending';
const probe = document.createElement('script');
probe.type = 'module'; probe.src = arguments[0]; probe.dataset.stmSmokeProbe = 'true';
probe.addEventListener('error', () => { document.documentElement.dataset.stmSmokeModules = 'error'; }, {once:true});
document.head.appendChild(probe);
return scripts.length;
'@
    if ([int]$count -le 0) { throw 'No allowed local modules for evaluation probe.' }
    if (-not (Wait-Smoke 'return ["loaded","error"].includes(document.documentElement.dataset.stmSmokeModules);')) { throw 'Module evaluation probe timed out.' }
    return [string](Invoke-MarionetteScript 'return document.documentElement.dataset.stmSmokeModules;')
}
function Assert-Smoke([string]$Name, [bool]$Condition) {
    if (-not $Condition) { throw "Integrated tool smoke failed: $Name" }
    $script:passed++
    Write-Host "[PASS] $Name"
}
function Wait-Smoke([string]$Script) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        if (Invoke-MarionetteScript $Script) { return $true }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    return $false
}
$toolNames = @('backup-check','backup-fingerprint','backup-compare','fide-search','support-summary','connection-check','browser-check','backup-duplicates','audit-reader','live-standings','backup-set','fide-workbench','backup-lock','backup-reader','rating-review')
try {
    if (-not [IO.File]::Exists($FirefoxPath)) { throw 'Installed Firefox executable is required.' }
    Add-OwnedSmokeAsset -Name $probeName -Content ([IO.File]::ReadAllText((Join-Path $root 'tests/browser/module-evaluation-probe.mjs')))
    $failureName = '__stm-module-failure-' + [Guid]::NewGuid().ToString('N') + '.mjs'
    $fixtureName = '__stm-module-fixture-' + [Guid]::NewGuid().ToString('N') + '.html'
    Add-OwnedSmokeAsset -Name $failureName -Content "throw new Error('synthetic top-level module failure');"
    Add-OwnedSmokeAsset -Name $fixtureName -Content @"
<!doctype html><html><head><meta charset="utf-8"><title>Synthetic module failure</title>
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; base-uri 'none'; object-src 'none'"></head>
<body><h1>Synthetic fixture</h1><input aria-label="Synthetic input"><script type="module" src="/$failureName"></script></body></html>
"@
    $profileDirectory = Join-Path $smoke.DataDirectory 'ff-profile'
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $profileDirectory 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@
    Start-StmFirefoxBackend -Context $smoke | Out-Null
    Start-StmFirefoxBrowser -Context $smoke -Firefox $FirefoxPath -ProfileDirectory $profileDirectory | Out-Null
    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    Start-MarionetteSession | Out-Null
    Open-MarionetteUrl ($smoke.BaseUrl + '/')
    Assert-Smoke 'React and privacy controls started' (Wait-Smoke 'return document.getElementById("root").children.length > 0 && !document.getElementById("stm-privacy-toggle").disabled;')
    $actualLinks = @(Invoke-MarionetteScript 'return Array.from(document.querySelectorAll("nav[aria-label=\"Weitere Werkzeuge\"] a")).map(a => new URL(a.href).pathname);')
    $expectedLinks = @($toolNames | ForEach-Object { "/$_/index.html" })
    Assert-Smoke 'Exactly the fifteen consolidated tool entries are reachable' ($actualLinks.Count -eq 15 -and @(Compare-Object $actualLinks $expectedLinks).Count -eq 0)
    Invoke-MarionetteClick (Find-MarionetteElement '#stm-privacy-toggle')
    Assert-Smoke 'Privacy curtain conceals the tournament view' ([bool](Invoke-MarionetteScript 'return document.getElementById("root").hidden && document.getElementById("stm-privacy-toggle").getAttribute("aria-expanded") === "false";'))
    Assert-Smoke 'Tool navigation remains visible with privacy curtain' ([bool](Invoke-MarionetteScript 'return document.querySelector("nav[aria-label=\"Weitere Werkzeuge\"]").getBoundingClientRect().height > 0;'))
    Invoke-MarionetteClick (Find-MarionetteElement '#stm-privacy-toggle')
    Assert-Smoke 'Privacy curtain restores the tournament view' ([bool](Invoke-MarionetteScript 'return !document.getElementById("root").hidden && document.getElementById("stm-privacy-toggle").getAttribute("aria-expanded") === "true";'))
    foreach ($path in $expectedLinks) {
        Open-MarionetteUrl ($smoke.BaseUrl + $path)
        Assert-Smoke "$path has real controls and a heading" ([bool](Invoke-MarionetteScript 'return !!document.querySelector("h1") && document.title.length > 0 && document.querySelectorAll("input,select,button").length > 0;'))
        # First verify local module entries, then prove their successful evaluation.
        $moduleCount = Invoke-MarionetteScript @'
const original = Array.from(document.querySelectorAll('script[type="module"][src]'));
if (original.length === 0 || original.some(s => new URL(s.src).origin !== location.origin)) return 0;
return original.length;
'@
        Assert-Smoke "$path declares local ES modules" ([int]$moduleCount -gt 0)
        Assert-Smoke "$path evaluates its modules successfully in Firefox" ((Invoke-ModuleEvaluationProbe) -ceq 'loaded')
    }
    Open-MarionetteUrl ($smoke.BaseUrl + '/' + $fixtureName)
    Assert-Smoke 'Negative fixture has a valid heading and controls' ([bool](Invoke-MarionetteScript 'return !!document.querySelector("h1") && !!document.querySelector("input");'))
    $null = Invoke-MarionetteScript @'
const original = document.querySelector('script[type="module"][src]');
document.documentElement.dataset.stmSmokeElementLoad = 'pending';
const repeat = document.createElement('script'); repeat.type = 'module'; repeat.src = original.src;
repeat.addEventListener('load', () => { document.documentElement.dataset.stmSmokeElementLoad = 'loaded'; }, {once:true});
repeat.addEventListener('error', () => { document.documentElement.dataset.stmSmokeElementLoad = 'error'; }, {once:true});
document.head.appendChild(repeat);
'@
    Assert-Smoke 'Real throwing ESM reproduces the insufficient element-load signal' (Wait-Smoke 'return document.documentElement.dataset.stmSmokeElementLoad === "loaded";')
    Assert-Smoke 'A real top-level module throw is rejected despite a valid module URL' ((Invoke-ModuleEvaluationProbe) -ceq 'error')
    Write-Host "Integrated tools: $passed PASS; 0 FAIL; 15 real tool entries; headless source-only; no package."
}
catch { $smoke.Failed = $true; throw }
finally {
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke
    # Only after owned browser/backend shutdown; exact GUID files, no traversal.
    foreach ($asset in $ownedAssets) {
        $null = Resolve-StmFirefoxSourceAssembly -Root $root -Path $smoke.SourceAssemblyPath
        $expected = [IO.Path]::GetFullPath((Join-Path $webRoot $asset.Name))
        if ([IO.Path]::GetFullPath($asset.Path) -cne $expected) { throw 'Owned smoke asset path drift.' }
        $item = Get-Item -LiteralPath $expected -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $item.PSIsContainer -or
            (Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash -cne $asset.Hash) { throw 'Owned smoke asset changed; preserve it for review.' }
        Remove-Item -LiteralPath $expected -ErrorAction Stop
    }
}
