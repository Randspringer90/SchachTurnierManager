# Firefox-Regressionstest fuer die zerstoerenden Turnieraktionen (STM-UX-013).
#
# Hintergrund: Zuruecksetzen nutzte window.confirm, Loeschen window.confirm gefolgt
# von window.prompt. Firefox unterdrueckt wiederholte modale Dialoge aus demselben
# Skriptdurchlauf ("Verhindern, dass diese Seite weitere Dialoge erzeugt"), der
# zweite Dialog erschien also nie. Der Namensvergleich lief dann gegen null, das
# Loeschen brach still ab und die Auswahl blieb veraltet.
#
# Unit- und Guard-Tests decken die Entscheidungslogik ab, konnten den Defekt aber
# per Konstruktion nicht reproduzieren: er war browserspezifisch. Dieser Test
# faehrt darum einen echten headless Firefox ueber das Marionette-Protokoll.
#
# Bewusst nicht Teil von Invoke-ReleaseGate.ps1: benoetigt eine lokale
# Firefox-Installation. Vor einem Release-Candidate manuell ausfuehren.
#
# Vorbedingung: Firefox installiert. Kein Netzwerkzugriff noetig.

[CmdletBinding()]
param(
    [int]$Port = 5093,
    [int]$MarionettePort = 2829,
    [string]$FirefoxPath,
    [switch]$KeepBrowserOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib\MarionetteClient.psm1') -Force -DisableNameChecking

$script:Ok = 0
$script:Failed = 0
$script:BaseUrl = "http://127.0.0.1:$Port"

function Write-Result {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "  [ OK ] $Name"
        $script:Ok++
    } else {
        Write-Host "  [FEHLER] $Name" -ForegroundColor Red
        $script:Failed++
    }
    if ($Detail) { Write-Host "         $Detail" }
}

function Resolve-FirefoxPath {
    if ($FirefoxPath) {
        if (-not (Test-Path $FirefoxPath)) { throw "Firefox nicht gefunden: $FirefoxPath" }
        return $FirefoxPath
    }
    $candidates = @(
        'C:\Program Files\Mozilla Firefox\firefox.exe',
        'C:\Program Files (x86)\Mozilla Firefox\firefox.exe'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    throw 'Firefox wurde nicht gefunden. Pfad ueber -FirefoxPath angeben.'
}

# Hinweis: @(Invoke-RestMethod ...) liefert bei einem leeren JSON-Array Count 1.
# Die Namen werden darum ueber die Pipeline gesammelt, die korrekt aufzaehlt.
function Get-TournamentName {
    $names = @()
    $response = Invoke-RestMethod "$script:BaseUrl/api/tournaments"
    $response | ForEach-Object { $names += $_.name }
    return ,([string[]]$names)
}

function Wait-ForCondition {
    param([string]$Script, [int]$TimeoutSeconds = 15)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Invoke-MarionetteScript $Script) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

# Markiert ein per Text gefundenes Element, damit ein echter Marionette-Klick
# (inklusive Hit-Testing) es adressieren kann.
function Set-ElementMarker {
    param([string]$Selector, [string]$ContainsText, [string]$Marker)
    $js = @"
const nodes = Array.from(document.querySelectorAll('$Selector'));
const target = nodes.find(n => (n.textContent || '').includes('$ContainsText'));
document.querySelectorAll('[data-smoke="$Marker"]').forEach(n => n.removeAttribute('data-smoke'));
if (!target) { return false; }
target.setAttribute('data-smoke', '$Marker');
return true;
"@
    if (-not (Invoke-MarionetteScript $js)) {
        throw "Element mit Text '$ContainsText' nicht gefunden (Selektor '$Selector')."
    }
}

function Invoke-MarkedClick {
    param([string]$Selector, [string]$ContainsText, [string]$Marker)
    Set-ElementMarker -Selector $Selector -ContainsText $ContainsText -Marker $Marker
    Invoke-MarionetteClick (Find-MarionetteElement "[data-smoke=`"$Marker`"]")
}

function Get-NativeDialogCall {
    $value = Invoke-MarionetteScript 'return (window.__nativeDialogCalls || []).join(",");'
    if ($null -eq $value) { return '' }
    return [string]$value
}

function Get-ConsoleError {
    $value = Invoke-MarionetteScript 'return (window.__consoleErrors || []).join(" | ");'
    if ($null -eq $value) { return '' }
    return [string]$value
}

function Open-AdminArea {
    Invoke-MarkedClick -Selector 'button' -ContainsText 'Mehr' -Marker 'tab-more'
    Start-Sleep -Milliseconds 400
    Invoke-MarkedClick -Selector 'button' -ContainsText 'Verwaltung' -Marker 'tab-admin'
    Start-Sleep -Milliseconds 500
}

function Select-Tournament {
    param([string]$Name)
    Invoke-MarkedClick -Selector 'button' -ContainsText $Name -Marker 'pick'
    Start-Sleep -Milliseconds 600
}

function Get-ConfirmButtonDisabled {
    return Invoke-MarionetteScript @'
const dialog = document.querySelector('[role="alertdialog"]');
if (!dialog) { return null; }
const button = Array.from(dialog.querySelectorAll("button")).find(b => b.textContent.includes("Turnier löschen"));
return button ? button.disabled : null;
'@
}

$backend = $null
$browser = $null
$dataDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("stm-ff-smoke-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$profileDirectory = Join-Path $dataDirectory 'ff-profile'

try {
    Write-Host '=== Firefox-Smoke: Zuruecksetzen/Loeschen (echter Browser) ==='

    $firefox = Resolve-FirefoxPath
    Write-Host "[Smoke] Firefox: $firefox"

    Write-Host '[Smoke] Baue portables Paket, damit kein veraltetes Binary getestet wird ...'
    & (Join-Path $PSScriptRoot 'Pack-Portable.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Pack-Portable ist fehlgeschlagen.' }

    $exe = Join-Path $root 'output\portable\app\SchachTurnierManager.WebApi.exe'
    if (-not (Test-Path $exe)) { throw "Backend-Binary nicht gefunden: $exe" }

    New-Item -ItemType Directory -Force -Path $dataDirectory, $profileDirectory | Out-Null
    Write-Host "[Smoke] Isoliertes Datenverzeichnis: $dataDirectory"

    $env:ASPNETCORE_URLS = $script:BaseUrl
    $env:SchachTurnierManager__DataDirectory = $dataDirectory
    $env:SchachTurnierManager__LogDirectory = (Join-Path $dataDirectory 'logs')
    $backend = Start-Process -FilePath $exe -PassThru -WindowStyle Hidden

    $healthy = $false
    for ($i = 0; $i -lt 45; $i++) {
        try {
            $health = Invoke-WebRequest "$script:BaseUrl/api/health" -UseBasicParsing -TimeoutSec 2
            if ($health.StatusCode -eq 200) { $healthy = $true; break }
        } catch {
            Start-Sleep -Milliseconds 800
        }
    }
    if (-not $healthy) { throw "Backend auf $script:BaseUrl war nicht erreichbar." }

    foreach ($name in @('Firefox Smoke Alpha', 'Firefox Smoke Beta')) {
        $body = @{ name = $name; system = 0; totalRounds = 3; location = 'Testraum'; startDate = '2026-01-01' } | ConvertTo-Json
        Invoke-RestMethod "$script:BaseUrl/api/tournaments" -Method Post -ContentType 'application/json' -Body $body | Out-Null
    }

    Set-Content -Path (Join-Path $profileDirectory 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@

    $arguments = @('-marionette', '-no-remote', '-profile', $profileDirectory, 'about:blank')
    if (-not $KeepBrowserOpen) { $arguments = @('-headless') + $arguments }
    $browser = Start-Process -FilePath $firefox -ArgumentList $arguments -PassThru

    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    $session = Start-MarionetteSession
    Write-Host ("[Smoke] Browser: {0} {1}" -f $session.capabilities.browserName, $session.capabilities.browserVersion)

    Open-MarionetteUrl "$script:BaseUrl/"
    [void](Wait-ForCondition 'return document.body.innerText.includes("Firefox Smoke");' 20)

    # Faellt der Test auf einen nativen Dialog zurueck, wird das protokolliert statt zu blockieren.
    Invoke-MarionetteScript @'
window.__nativeDialogCalls = [];
window.confirm = function () { window.__nativeDialogCalls.push("confirm"); return false; };
window.prompt  = function () { window.__nativeDialogCalls.push("prompt");  return null; };
window.alert   = function () { window.__nativeDialogCalls.push("alert"); };
window.__consoleErrors = [];
const originalError = console.error.bind(console);
console.error = function (...args) { window.__consoleErrors.push(args.map(String).join(" ")); originalError(...args); };
return true;
'@ | Out-Null

    Write-Host ''
    Write-Host '=== 1. Loeschen oeffnet einen In-App-Dialog, keine native Dialogkette ==='

    Select-Tournament 'Firefox Smoke Alpha'
    Open-AdminArea
    Write-Result 'Verwaltungsbereich mit den gefaehrlichen Aktionen erreichbar' `
        ([bool](Invoke-MarionetteScript 'return document.body.innerText.includes("Gefährliche Aktionen");'))

    Invoke-MarkedClick -Selector 'button' -ContainsText 'Turnier löschen' -Marker 'open-delete'
    Start-Sleep -Milliseconds 500

    Write-Result 'Loeschen oeffnet einen In-App-alertdialog' (Test-MarionetteElement '[role="alertdialog"]')
    Write-Result 'Kein natives window.confirm/prompt verwendet' ((Get-NativeDialogCall) -eq '')
    Write-Result 'Dialog ist beschriftet und beschrieben (a11y)' ([bool](Invoke-MarionetteScript @'
const d = document.querySelector('[role="alertdialog"]');
return !!(d && d.getAttribute("aria-labelledby") && d.getAttribute("aria-describedby") && d.getAttribute("aria-modal") === "true");
'@))

    Write-Host ''
    Write-Host '=== 2. Tippbestaetigung - der Schritt, den Firefox verschluckt hat ==='

    Write-Result 'Bestaetigen ist zunaechst deaktiviert' ((Get-ConfirmButtonDisabled) -eq $true)

    $nameField = Find-MarionetteElement '[role="alertdialog"] input[type="text"]'
    Send-MarionetteKeys -ElementId $nameField -Text 'Firefox Smoke Falsch'
    Start-Sleep -Milliseconds 300
    Write-Result 'Ein falscher Name haelt Bestaetigen deaktiviert' ((Get-ConfirmButtonDisabled) -eq $true)

    Invoke-MarionetteScript @'
const dialog = document.querySelector('[role="alertdialog"]');
const field = dialog.querySelector('input[type="text"]');
const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
setter.call(field, "");
field.dispatchEvent(new Event("input", { bubbles: true }));
return true;
'@ | Out-Null
    Start-Sleep -Milliseconds 200
    Send-MarionetteKeys -ElementId $nameField -Text 'Firefox Smoke Alpha'
    Start-Sleep -Milliseconds 300
    Write-Result 'Der exakte Name aktiviert Bestaetigen in Firefox' ((Get-ConfirmButtonDisabled) -eq $false)

    Write-Host ''
    Write-Host '=== 3. Loeschen laeuft durch und waehlt das naechste Turnier ==='

    Invoke-MarkedClick -Selector '[role="alertdialog"] button' -ContainsText 'Turnier löschen' -Marker 'confirm-delete'
    [void](Wait-ForCondition 'return !document.querySelector(''[role="alertdialog"]'');' 20)

    Write-Result 'Dialog nach erfolgreichem Loeschen geschlossen' (-not (Test-MarionetteElement '[role="alertdialog"]'))
    Write-Result 'Im gesamten Loeschablauf kein nativer Dialog' ((Get-NativeDialogCall) -eq '')

    $names = Get-TournamentName
    Write-Result 'Alpha ist im Backend geloescht' (-not ($names -contains 'Firefox Smoke Alpha')) `
        ('verbleibend: ' + ($names -join ', '))

    [void](Wait-ForCondition 'return document.body.innerText.includes("Firefox Smoke Beta");' 15)
    Write-Result 'Das verbleibende Turnier ist ausgewaehlt, keine tote Id' `
        ([bool](Invoke-MarionetteScript 'return document.body.innerText.includes("Firefox Smoke Beta");'))
    Write-Result 'Keine Konsolenfehler nach dem Loeschen' ([string]::IsNullOrWhiteSpace((Get-ConsoleError)))

    Write-Host ''
    Write-Host '=== 4. Zuruecksetzen: Escape bricht ab, nichts wird zurueckgesetzt ==='

    Select-Tournament 'Firefox Smoke Beta'
    Open-AdminArea
    Invoke-MarkedClick -Selector 'button' -ContainsText 'Turnier zurücksetzen' -Marker 'open-reset'
    Start-Sleep -Milliseconds 500
    Write-Result 'Zuruecksetzen oeffnet ebenfalls einen In-App-alertdialog' (Test-MarionetteElement '[role="alertdialog"]')
    Write-Result 'Zuruecksetzen nutzt keinen nativen Dialog' ((Get-NativeDialogCall) -eq '')

    Send-MarionetteEscape
    Start-Sleep -Milliseconds 500
    Write-Result 'Escape schliesst den Dialog ohne zu bestaetigen' (-not (Test-MarionetteElement '[role="alertdialog"]'))

    Write-Host ''
    Write-Host '=== 5. Loeschen des letzten Turniers ergibt einen sauberen Leerzustand ==='

    Invoke-MarkedClick -Selector 'button' -ContainsText 'Turnier löschen' -Marker 'open-delete-last'
    Start-Sleep -Milliseconds 500
    $lastInput = Find-MarionetteElement '[role="alertdialog"] input[type="text"]'
    Send-MarionetteKeys -ElementId $lastInput -Text 'Firefox Smoke Beta'
    Start-Sleep -Milliseconds 300
    Invoke-MarkedClick -Selector '[role="alertdialog"] button' -ContainsText 'Turnier löschen' -Marker 'confirm-delete-last'
    [void](Wait-ForCondition 'return !document.querySelector(''[role="alertdialog"]'');' 20)

    $remaining = Get-TournamentName
    $deadline = (Get-Date).AddSeconds(15)
    while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $remaining = Get-TournamentName
    }
    Write-Result 'Im Backend ist kein Turnier mehr vorhanden' ($remaining.Count -eq 0) ("Anzahl: " + $remaining.Count)

    Start-Sleep -Seconds 1
    Write-Result 'Leerzustand erzeugt keine Konsolenfehler (keine Requests gegen eine tote Id)' `
        ([string]::IsNullOrWhiteSpace((Get-ConsoleError)))
    Write-Result 'Im gesamten Lauf kein nativer Dialog' ((Get-NativeDialogCall) -eq '')
    Write-Result 'App ist weiterhin gerendert (kein Error-Boundary-Absturz)' `
        ([bool](Invoke-MarionetteScript 'return !!document.querySelector("#root");'))

    Write-Host ''
    Write-Host '=========================================='
    Write-Host ("Firefox-Smoke: {0} OK, {1} FEHLER" -f $script:Ok, $script:Failed)
    if ($script:Failed -gt 0) {
        Write-Host 'Firefox-Regression NICHT bestanden.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Alle Firefox-Dialogablaeufe gruen.'
    exit 0
} finally {
    try { Disconnect-Marionette } catch { }
    if ($browser -and -not $KeepBrowserOpen) {
        Stop-Process -Id $browser.Id -Force -ErrorAction SilentlyContinue
    }
    if ($backend) {
        Write-Host "[Smoke] Stoppe Backend (PID $($backend.Id)) ..."
        Stop-Process -Id $backend.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 500
    if (Test-Path $dataDirectory) {
        Remove-Item -Recurse -Force -LiteralPath $dataDirectory -ErrorAction SilentlyContinue
        Write-Host '[Smoke] Temp-Datenverzeichnis entfernt.'
    }
}
