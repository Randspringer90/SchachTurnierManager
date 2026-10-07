# Firefox-End-to-End fuer den kompletten Turnierablauf (STM-STAB-001).
#
# Hintergrund: 523 .NET- und 24 Frontendtests waren gruen, waehrend im echten
# Browser "Turnier anlegen" nicht zuverlaessig funktionierte und mehrere
# Schaltflaechen wirkungslos wirkten. Keiner der vorhandenen Tests konnte das
# sehen: sie pruefen Logik, nicht Bedienung.
#
# Dieser Test faehrt darum einen echten headless Firefox ueber Marionette gegen
# das portable Paket - also gegen genau das Binary, das ein Anwender startet.
# Bewusst ohne Playwright/Selenium: laeuft offline und ohne Registry-Zugriff.
#
# Abgedeckt:
#   1. Start, Healthcheck, Leerzustand
#   2. Turnier anlegen (erster Klick, sichtbares Ergebnis, Persistenz)
#   3. Doppelklickschutz: zwei Submits erzeugen genau ein Turnier
#   4. Backend nicht erreichbar: verstaendliche Meldung statt totem Knopf
#   5. Erholung nach Backendstart ohne Browserneustart
#   6. Demo-Turnier, Auslosung, Ergebnisse, Rundenschluss, Tabelle
#   7. Backup-Export
#   8. Neustart der Anwendung, Turnier weiterhin vorhanden
#   9. Button-Crawl ueber alle sichtbaren Bedienelemente
#
# Vorbedingung: Firefox installiert, portables Paket baubar. Kein Netzwerk noetig.
# Bewusst nicht Teil von Invoke-ReleaseGate.ps1 (braucht eine Firefox-Installation).

[CmdletBinding()]
param(
    [int]$Port = 5097,
    [int]$MarionettePort = 2837,
    [string]$FirefoxPath,
    [string]$EvidenceDirectory,
    [switch]$SkipPack,
    [string]$SourceAssemblyPath,
    [switch]$KeepBrowserOpen
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module (Join-Path $PSScriptRoot 'lib\MarionetteClient.psm1') -Force -DisableNameChecking
. (Join-Path $PSScriptRoot 'lib\FirefoxSmokeCommon.ps1')
$smoke = New-StmFirefoxSmokeContext -Root $root -Port $Port -MarionettePort $MarionettePort -SourceAssemblyPath $SourceAssemblyPath -SkipPack:$SkipPack -KeepBrowserOpen:$KeepBrowserOpen

$script:Ok = 0
$script:Failed = 0
$script:BaseUrl = "http://127.0.0.1:$Port"
$script:Evidence = $EvidenceDirectory

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
    foreach ($candidate in @('C:\Program Files\Mozilla Firefox\firefox.exe', 'C:\Program Files (x86)\Mozilla Firefox\firefox.exe')) {
        if (Test-Path $candidate) { return $candidate }
    }
    throw 'Firefox wurde nicht gefunden. Pfad ueber -FirefoxPath angeben.'
}

function Save-Evidence {
    param([string]$Name)
    if (-not $script:Evidence) { return }
    try { Save-MarionetteScreenshot -Path (Join-Path $script:Evidence "$Name.png") | Out-Null } catch { }
}

# --- Seiteninstrumentierung -------------------------------------------------
# Muss im Seitenkontext laufen: eine Zuweisung an window.fetch in der
# Marionette-Sandbox erreicht das fetch der Seite nicht.
$instrumentation = @'
window.__stm = { console: [], page: [], rejections: [], failedRequests: [], nativeDialogs: [] };
const originalConsoleError = console.error.bind(console);
console.error = function () {
  window.__stm.console.push(Array.from(arguments).map(String).join(' '));
  originalConsoleError.apply(null, arguments);
};
window.addEventListener('error', function (event) { window.__stm.page.push(String(event.message)); });
window.addEventListener('unhandledrejection', function (event) {
  window.__stm.rejections.push(String((event.reason && (event.reason.message || event.reason)) || event.reason));
});
const originalFetch = window.fetch;
window.fetch = function (input, init) {
  const url = String(input);
  const method = (init && init.method) || 'GET';
  return originalFetch.apply(this, arguments).then(
    function (response) {
      if (!response.ok) { window.__stm.failedRequests.push(method + ' ' + url + ' -> ' + response.status); }
      return response;
    },
    function (error) {
      window.__stm.failedRequests.push(method + ' ' + url + ' -> ' + String(error));
      throw error;
    });
};
window.confirm = function () { window.__stm.nativeDialogs.push('confirm'); return false; };
window.prompt = function () { window.__stm.nativeDialogs.push('prompt'); return null; };
window.alert = function () { window.__stm.nativeDialogs.push('alert'); };
'@

function Reset-Instrumentation {
    Invoke-MarionetteScript @'
const log = window.wrappedJSObject.__stm;
log.console.length = 0; log.page.length = 0; log.rejections.length = 0;
log.failedRequests.length = 0; log.nativeDialogs.length = 0;
return true;
'@ | Out-Null
}

function Get-Instrumented {
    param([string]$Key)
    $value = Invoke-MarionetteScript "return (window.wrappedJSObject.__stm.$Key || []).join(' | ');"
    if ($null -eq $value) { return '' }
    return [string]$value
}

# --- DOM-Helfer -------------------------------------------------------------

function Get-BodyText {
    return [string](Invoke-MarionetteScript 'return document.body ? document.body.innerText : "";')
}

function Get-StatusLineText {
    return [string](Invoke-MarionetteScript 'const e = document.querySelector(".status-line"); return e ? e.innerText.replace(/\s+/g, " ").trim() : "";')
}

function Wait-ForCondition {
    param([string]$Script, [int]$TimeoutSeconds = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Invoke-MarionetteScript $Script) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

function Set-ElementMarker {
    param([string]$Selector, [string]$ContainsText, [string]$Marker)
    $js = @"
const nodes = Array.from(document.querySelectorAll('$Selector'));
const target = nodes.find(n => (n.textContent || '').includes('$ContainsText') && !n.disabled);
document.querySelectorAll('[data-smoke="$Marker"]').forEach(n => n.removeAttribute('data-smoke'));
if (!target) { return false; }
target.setAttribute('data-smoke', '$Marker');
return true;
"@
    if (-not (Invoke-MarionetteScript $js)) {
        throw "Bedienelement mit Text '$ContainsText' nicht gefunden oder deaktiviert (Selektor '$Selector')."
    }
}

function Invoke-MarkedClick {
    param([string]$Selector, [string]$ContainsText, [string]$Marker)
    Set-ElementMarker -Selector $Selector -ContainsText $ContainsText -Marker $Marker
    Invoke-MarionetteClick (Find-MarionetteElement "[data-smoke=`"$Marker`"]")
}

function Set-InputValue {
    param([string]$Selector, [string]$Value)
    $escaped = $Value.Replace("'", "\'")
    Invoke-MarionetteScript @"
const field = document.querySelector('$Selector');
if (!field) { return false; }
const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
setter.call(field, '$escaped');
field.dispatchEvent(new Event('input', { bubbles: true }));
return true;
"@ | Out-Null
}

function Get-TournamentName {
    $names = @()
    (Invoke-RestMethod "$script:BaseUrl/api/tournaments" -NoProxy -MaximumRedirection 0) | ForEach-Object { $names += $_.name }
    return , ([string[]]$names)
}

function Open-CreateTournamentForm {
    if (-not (Invoke-MarionetteScript 'return !!document.querySelector("form.create-tournament-form");')) {
        Invoke-MarkedClick -Selector '.tournament-start-actions button' -ContainsText 'Turnier anlegen' -Marker 'open-create'
        Start-Sleep -Milliseconds 500
    }
}

function Start-Backend {
    param([string]$DataDirectory)
    if ($DataDirectory -cne $smoke.DataDirectory) { throw 'Backend data directory must belong to this smoke run.' }
    return Start-StmFirefoxBackend -Context $smoke
}

function Stop-Backend {
    param($Process)
    if ($null -ne $Process) { Stop-StmFirefoxBackend -Context $smoke -Handle $Process }
}

$backend = $null
$browser = $null
$dataDirectory = $smoke.DataDirectory
$profileDirectory = Join-Path $dataDirectory 'ff-profile'

try {
    Write-Host '=== Firefox-End-to-End: Turnierablauf (echter Browser) ==='

    $firefox = Resolve-FirefoxPath
    Write-Host "[Flow] Firefox: $firefox"

    if (-not $SkipPack) {
        Write-Host '[Flow] Baue portables Paket, damit kein veraltetes Binary getestet wird ...'
        & (Join-Path $PSScriptRoot 'Pack-Portable.ps1') -NoZip | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Pack-Portable ist fehlgeschlagen.' }
    }

    New-Item -ItemType Directory -Force -Path $dataDirectory, $profileDirectory | Out-Null
    if ($script:Evidence) { New-Item -ItemType Directory -Force -Path $script:Evidence | Out-Null }
    Write-Host "[Flow] Isoliertes Datenverzeichnis: $dataDirectory"

    $backend = Start-Backend -DataDirectory $dataDirectory

    Set-Content -Path (Join-Path $profileDirectory 'user.js') -Encoding utf8 -Value @"
user_pref("marionette.port", $MarionettePort);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.update.enabled", false);
"@

    $browser = Start-StmFirefoxBrowser -Context $smoke -Firefox $firefox -ProfileDirectory $profileDirectory -KeepBrowserOpen:$KeepBrowserOpen

    Connect-Marionette -Port $MarionettePort -TimeoutSeconds 60 | Out-Null
    $session = Start-MarionetteSession
    Write-Host ("[Flow] Browser: {0} {1}" -f $session.capabilities.browserName, $session.capabilities.browserVersion)

    Open-MarionetteUrl "$script:BaseUrl/"
    [void](Wait-ForCondition 'return !!document.querySelector(".status-line");' 30)
    Invoke-MarionettePageScript $instrumentation
    Write-Result 'Instrumentierung im Seitenkontext aktiv' ([bool](Invoke-MarionetteScript 'return !!window.wrappedJSObject.__stm;'))

    Write-Host ''
    Write-Host '=== 1. Start, Healthcheck und Leerzustand ==='

    Write-Result 'Anwendung ist gerendert (kein weisser Bildschirm)' ([bool](Invoke-MarionetteScript 'return !!document.querySelector("#root") && document.body.innerText.length > 200;'))
    [void](Wait-ForCondition 'return !!document.querySelector(".status-card .ok");' 20)
    Write-Result 'Backend-Chip wird gruen' ([bool](Invoke-MarionetteScript 'return !!document.querySelector(".status-card .ok");'))
    Write-Result 'Kein Bereitschaftsbanner mehr sichtbar' (-not (Test-MarionetteElement '.readiness-banner'))
    Write-Result 'Leerzustand wird angezeigt' ((Get-BodyText) -match 'Noch keine Turniere')
    Write-Result 'Keine Konsolenfehler beim Start' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'console'))) (Get-Instrumented 'console')
    Write-Result 'Keine unbehandelte Promise-Ablehnung beim Start' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'rejections'))) (Get-Instrumented 'rejections')
    Save-Evidence '01-leerzustand'

    Write-Host ''
    Write-Host '=== 2. Turnier anlegen reagiert beim ersten Klick ==='

    Reset-Instrumentation
    Invoke-MarkedClick -Selector '.tournament-start-actions button' -ContainsText 'Turnier anlegen' -Marker 'open-create'
    Start-Sleep -Milliseconds 500
    Write-Result 'Der erste Klick oeffnet das Formular' (Test-MarionetteElement 'form.create-tournament-form')

    Set-InputValue -Selector 'form.create-tournament-form input' -Value ''
    Start-Sleep -Milliseconds 200
    Write-Result 'Ohne Namen bleibt "Jetzt anlegen" deaktiviert (nachvollziehbares Pflichtfeld)' `
        ([bool](Invoke-MarionetteScript 'const b = document.querySelector("form.create-tournament-form button[type=submit]"); return !!b && b.disabled;'))

    Set-InputValue -Selector 'form.create-tournament-form input' -Value 'Flow Turnier Alpha'
    Start-Sleep -Milliseconds 300
    Write-Result 'Mit Namen ist "Jetzt anlegen" bedienbar' `
        ([bool](Invoke-MarionetteScript 'const b = document.querySelector("form.create-tournament-form button[type=submit]"); return !!b && !b.disabled;'))
    Save-Evidence '02-formular'

    Invoke-MarkedClick -Selector 'form.create-tournament-form button[type="submit"]' -ContainsText '' -Marker 'submit-create'
    # Auf das Schliessen des Formulars warten, nicht auf den Namen: die
    # Live-Zusammenfassung im offenen Formular enthaelt den Namen bereits und
    # wuerde die Pruefung sofort erfuellen, bevor der POST ueberhaupt lief.
    [void](Wait-ForCondition 'return !document.querySelector("form.create-tournament-form");' 25)
    # Die Liste wird erst nach dem Schliessen des Formulars nachgeladen.
    $listed = Wait-ForCondition 'return Array.from(document.querySelectorAll(".list button")).some(n => (n.textContent||"").includes("Flow Turnier Alpha"));' 20

    Write-Result 'Turnier erscheint in der Turnierliste' $listed
    Write-Result 'Statuszeile bestaetigt die Anlage' ((Get-StatusLineText) -match 'Turnier angelegt')
    Write-Result 'Das Formular schliesst sich nach dem Erfolg' (-not (Test-MarionetteElement 'form.create-tournament-form'))
    Write-Result 'Kein nativer Dialog im Anlageablauf' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'nativeDialogs')))
    Write-Result 'Keine unbehandelte Promise-Ablehnung' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'rejections'))) (Get-Instrumented 'rejections')
    Write-Result 'Keine fehlgeschlagenen Requests' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'failedRequests'))) (Get-Instrumented 'failedRequests')

    $names = Get-TournamentName
    Write-Result 'Turnier ist im Backend gespeichert' ($names -contains 'Flow Turnier Alpha') ('vorhanden: ' + ($names -join ', '))
    Save-Evidence '03-angelegt'

    Write-Host ''
    Write-Host '=== 3. Reload erhaelt das Turnier ==='

    Open-MarionetteUrl "$script:BaseUrl/"
    [void](Wait-ForCondition 'return Array.from(document.querySelectorAll(".list button")).some(n => (n.textContent||"").includes("Flow Turnier Alpha"));' 25)
    Invoke-MarionettePageScript $instrumentation
    Write-Result 'Nach dem Reload ist das Turnier weiterhin in der Liste' `
        ([bool](Invoke-MarionetteScript 'return Array.from(document.querySelectorAll(".list button")).some(n => (n.textContent||"").includes("Flow Turnier Alpha"));'))

    Write-Host ''
    Write-Host '=== 4. Doppelklickschutz: zwei Submits ergeben ein Turnier ==='

    Reset-Instrumentation
    $before = (Get-TournamentName).Count
    Open-CreateTournamentForm
    Set-InputValue -Selector 'form.create-tournament-form input' -Value 'Flow Doppelklick'
    Start-Sleep -Milliseconds 300
    # Zwei Submits aus demselben Ereigniszyklus - genau das, was ein hektischer
    # Doppelklick am Turniertag ausloest.
    Invoke-MarionetteScript @'
const form = document.querySelector('form.create-tournament-form');
form.requestSubmit();
form.requestSubmit();
return true;
'@ | Out-Null
    [void](Wait-ForCondition 'return !document.querySelector("form.create-tournament-form");' 25)
    Start-Sleep -Seconds 2

    $after = Get-TournamentName
    $duplicates = @($after | Where-Object { $_ -eq 'Flow Doppelklick' }).Count
    Write-Result 'Ein Doppelklick erzeugt genau ein Turnier' ($duplicates -eq 1) ("Anzahl 'Flow Doppelklick': $duplicates, gesamt: " + $after.Count + " (vorher $before)")

    Write-Host ''
    Write-Host '=== 5. Backend nicht erreichbar: verstaendliche Meldung statt totem Knopf ==='

    Stop-Backend -Process $backend
    $backend = $null
    Reset-Instrumentation

    Open-CreateTournamentForm
    Set-InputValue -Selector 'form.create-tournament-form input' -Value 'Flow Offline'
    Start-Sleep -Milliseconds 300
    Invoke-MarionetteScript 'document.querySelector("form.create-tournament-form").requestSubmit(); return true;' | Out-Null

    # Der Zeitausfall des API-Clients muss zuschlagen. Bewusst grosszuegig warten:
    # ohne ihn wuerde hier nie etwas passieren - genau der reproduzierte Defekt.
    $offlineHandled = Wait-ForCondition 'return !!document.querySelector(".status-line .error") || !!document.querySelector(".readiness-banner.tone-error");' 40
    Write-Result 'Der fehlgeschlagene Klick endet in einer sichtbaren Meldung' $offlineHandled (Get-StatusLineText)

    $offlineText = (Get-BodyText)
    Write-Result 'Keine rohe NetworkError-/TypeError-Ausgabe' (-not ($offlineText -match 'NetworkError|TypeError|Failed to fetch'))
    Write-Result 'Kein Host, Port oder Proxy in der Meldung' (-not ((Get-StatusLineText) -match '127\.0\.0\.1|localhost|:\d{4}|proxy'))
    Write-Result 'Der Backend-Chip behauptet nicht weiter "online"' (-not (Test-MarionetteElement '.status-card .ok'))
    Write-Result 'Bereitschaftsbanner mit erneutem Versuch erscheint' (Test-MarionetteElement '.readiness-banner.tone-error button')
    Write-Result 'App ist weiterhin gerendert (kein weisser Bildschirm)' ([bool](Invoke-MarionetteScript 'return !!document.querySelector("#root");'))
    Write-Result 'Kein haengender Dialog' (-not (Test-MarionetteElement '[role="alertdialog"]'))
    $offlineNames = @()
    Save-Evidence '04-backend-offline'

    Write-Host ''
    Write-Host '=== 6. Erholung: nach Backendstart ohne Browserneustart weiterarbeiten ==='

    # Zuerst mit weiterhin totem Backend: der Knopf muss klickbar sein, darf die
    # Anwendung nicht zerstoeren und darf nicht faelschlich gruen melden.
    Invoke-MarkedClick -Selector '.readiness-banner button' -ContainsText 'Erneut versuchen' -Marker 'retry-offline'
    Start-Sleep -Seconds 2
    Write-Result 'Erneuter Versuch bei totem Backend zerstoert die Anwendung nicht' ([bool](Invoke-MarionetteScript 'return !!document.querySelector("#root");'))
    Write-Result 'Erneuter Versuch meldet nicht faelschlich Erfolg' (-not (Test-MarionetteElement '.status-card .ok'))

    $backend = Start-Backend -DataDirectory $dataDirectory
    # Der Bereitschaftstakt kann das Backend selbst wiederfinden; ist das Banner
    # noch da, wird der Knopf benutzt. Beide Wege muessen zum gleichen Ziel fuehren.
    if (Test-MarionetteElement '.readiness-banner button') {
        Invoke-MarkedClick -Selector '.readiness-banner button' -ContainsText 'Erneut versuchen' -Marker 'retry-backend'
    }
    $recovered = Wait-ForCondition 'return !!document.querySelector(".status-card .ok") && !document.querySelector(".readiness-banner");' 40
    Write-Result 'Nach dem Backendstart wird die Anwendung ohne Browserneustart wieder gruen' $recovered

    Reset-Instrumentation
    Open-CreateTournamentForm
    Set-InputValue -Selector 'form.create-tournament-form input' -Value 'Flow Nach Neustart'
    Start-Sleep -Milliseconds 300
    Invoke-MarkedClick -Selector 'form.create-tournament-form button[type="submit"]' -ContainsText '' -Marker 'submit-after-restart'
    [void](Wait-ForCondition 'return !document.querySelector("form.create-tournament-form");' 25)
    Start-Sleep -Seconds 1
    $offlineNames = Get-TournamentName
    Write-Result 'Nach der Erholung laesst sich wieder ein Turnier anlegen' ($offlineNames -contains 'Flow Nach Neustart')
    Write-Result 'Der abgebrochene Offline-Versuch hat nichts halb angelegt' (-not ($offlineNames -contains 'Flow Offline')) ('vorhanden: ' + ($offlineNames -join ', '))

    Write-Host ''
    Write-Host '=== 7. Vollstaendiger Turnierablauf ueber das Demo-Turnier ==='

    Reset-Instrumentation
    Invoke-MarkedClick -Selector 'button' -ContainsText 'Demo-Turnier öffnen' -Marker 'open-demo'
    $demoReady = Wait-ForCondition 'return document.body.innerText.includes("Build-Week") || document.body.innerText.includes("Demo");' 60
    Start-Sleep -Seconds 3
    Write-Result 'Demo-Turnier mit acht synthetischen Teilnehmern wird angelegt' $demoReady

    $demo = (Invoke-RestMethod "$script:BaseUrl/api/tournaments" -NoProxy -MaximumRedirection 0) | Where-Object { $_.players.Count -ge 8 } | Select-Object -First 1
    Write-Result 'Acht Teilnehmer sind persistiert' ($null -ne $demo -and $demo.players.Count -ge 8) ("Teilnehmer: " + $(if ($demo) { $demo.players.Count } else { 0 }))
    Write-Result 'Mindestens eine Runde ist ausgelost' ($null -ne $demo -and $demo.rounds.Count -ge 1) ("Runden: " + $(if ($demo) { $demo.rounds.Count } else { 0 }))

    if ($demo) {
        $standings = Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)/standings" -NoProxy -MaximumRedirection 0
        Write-Result 'Tabelle liefert eine Zeile je Teilnehmer' (@($standings).Count -eq $demo.players.Count) ("Zeilen: " + @($standings).Count)

        # Ergebnisse und Rundenfortschritt ueber die API pruefen: die Auslosung der
        # naechsten Runde ist der Schritt, der bei unvollstaendigen Ergebnissen
        # blockieren muss.
        # The demo already completes round 1, so pair a new round to get open boards.
        # Pairing.result is an object { kind }; GameResultKind 0 means "not played yet".
        $round = Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)/pairings/next-round" -NoProxy -MaximumRedirection 0 -Method Post
        $openBoards = @($round.pairings | Where-Object { -not $_.isBye -and $_.result.kind -eq 0 })
        Write-Result 'Eine neue Runde mit offenen Brettern ist ausgelost' ($openBoards.Count -gt 0) ("Runde $($round.roundNumber), offene Bretter: " + $openBoards.Count)

        $posted = 0
        foreach ($pairing in $openBoards) {
            $body = @{ roundNumber = $round.roundNumber; boardNumber = $pairing.boardNumber; result = 1; expectedPreviousResult = $pairing.result.kind } | ConvertTo-Json
            Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)/results" -NoProxy -MaximumRedirection 0 -Method Post -ContentType 'application/json' -Body $body | Out-Null
            $posted++
        }
        Write-Result 'Mindestens ein Ergebnis wurde per POST eingetragen' ($posted -gt 0) ("POSTs: $posted")

        $afterResults = Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)" -NoProxy -MaximumRedirection 0
        $storedRound = @($afterResults.rounds | Where-Object { $_.roundNumber -eq $round.roundNumber })[0]
        $stillOpen = @($storedRound.pairings | Where-Object { -not $_.isBye -and $_.result.kind -eq 0 })
        $storedAsSent = @($storedRound.pairings | Where-Object { -not $_.isBye -and $_.result.kind -eq 1 })
        Write-Result 'Alle Ergebnisse der Runde sind eingetragen' ($stillOpen.Count -eq 0) ("offen: " + $stillOpen.Count)
        Write-Result 'Gespeicherte Ergebnisse entsprechen den gesendeten' ($storedAsSent.Count -eq $posted) ("gespeichert mit kind=1: $($storedAsSent.Count) von $posted")

        $nextRound = Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)/pairings/next-round" -NoProxy -MaximumRedirection 0 -Method Post
        Write-Result 'Naechste Runde laesst sich nach vollstaendigen Ergebnissen auslosen' ($nextRound.roundNumber -gt $round.roundNumber) ("neue Runde: " + $nextRound.roundNumber)

        $standingsAfter = Invoke-RestMethod "$script:BaseUrl/api/tournaments/$($demo.id)/standings" -NoProxy -MaximumRedirection 0
        $totalPoints = ($standingsAfter | Measure-Object -Property points -Sum).Sum
        Write-Result 'Tabelle verteilt Punkte nach der gespielten Runde' ($totalPoints -gt 0) ("Punktsumme: $totalPoints")

        $export = Invoke-WebRequest "$script:BaseUrl/api/tournaments/$($demo.id)/export/json" -NoProxy -MaximumRedirection 0 -UseBasicParsing
        Write-Result 'Backup-Export liefert ein vollstaendiges JSON' ($export.StatusCode -eq 200 -and $export.Content.Length -gt 200) ("Bytes: " + $export.Content.Length)
    }

    Open-MarionetteUrl "$script:BaseUrl/"
    [void](Wait-ForCondition 'return !!document.querySelector(".status-card .ok");' 30)
    Invoke-MarionettePageScript $instrumentation
    Write-Result 'Oberflaeche zeigt die Tabelle nach dem Rundenfortschritt' `
        ([bool](Invoke-MarionetteScript 'const t = Array.from(document.querySelectorAll("button")).find(n => (n.textContent||"").trim() === "Tabelle"); if (!t) { return false; } t.click(); return true;'))
    Start-Sleep -Seconds 2
    Write-Result 'Keine Konsolenfehler im Turnierablauf' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'console'))) (Get-Instrumented 'console')
    Save-Evidence '05-tabelle'

    Write-Host ''
    Write-Host '=== 8. Anwendungsneustart: Daten bleiben erhalten ==='

    $expected = Get-TournamentName
    Stop-Backend -Process $backend
    $backend = Start-Backend -DataDirectory $dataDirectory
    Open-MarionetteUrl "$script:BaseUrl/"
    [void](Wait-ForCondition 'return !!document.querySelector(".status-card .ok");' 40)
    Invoke-MarionettePageScript $instrumentation

    $afterRestart = Get-TournamentName
    $missing = @($expected | Where-Object { $afterRestart -notcontains $_ })
    Write-Result 'Nach dem Neustart sind alle Turniere weiterhin vorhanden' ($missing.Count -eq 0) ("fehlend: " + ($missing -join ', '))
    Write-Result 'Turnier laesst sich nach dem Neustart erneut oeffnen' `
        ([bool](Invoke-MarionetteScript 'const b = Array.from(document.querySelectorAll(".list button")).find(n => (n.textContent||"").includes("Flow Turnier Alpha")); if (!b) { return false; } b.click(); return true;'))
    Start-Sleep -Seconds 2
    Write-Result 'Das geoeffnete Turnier wird angezeigt' ((Get-BodyText) -match 'Flow Turnier Alpha')
    Save-Evidence '06-nach-neustart'

    Write-Host ''
    Write-Host '=== 9. Button-Crawl: jedes sichtbare Bedienelement hat einen klaren Zustand ==='

    Reset-Instrumentation

    # Nur lesende bzw. navigierende Aktionen werden geklickt. Zerstoerende und
    # schreibende Aktionen bleiben ausgeschlossen - der Crawl darf keine
    # Testdaten vernichten, auch nicht in einem isolierten Datenverzeichnis.
    $enumerateScript = @'
const destructive = /löschen|zurücksetzen|entfernen|import|überschreiben|auslosen|abschließen|speichern|würfeln|backup|installieren|anlegen|übernehmen|ändern|senden|drucken|export/i;
const buttons = Array.from(document.querySelectorAll('button'));
const rows = buttons.map((button, index) => ({
  index: index,
  label: (button.textContent || '').replace(/\s+/g, ' ').trim().slice(0, 60),
  disabled: !!button.disabled,
  type: button.getAttribute('type') || 'submit',
  hasTitle: !!button.getAttribute('title'),
  hasAriaLabel: !!button.getAttribute('aria-label'),
  visible: !!(button.offsetWidth || button.offsetHeight || button.getClientRects().length),
  safe: !destructive.test(button.textContent || '')
}));
return JSON.stringify(rows);
'@

    function Switch-MainTab {
        param([string]$Label)
        return [bool](Invoke-MarionetteScript @"
const tab = Array.from(document.querySelectorAll('.tab-bar button, .more-grid button'))
  .find(n => (n.textContent || '').trim().startsWith('$Label'));
if (!tab) { return false; }
tab.click();
return true;
"@)
    }

    # Die drei letzten Bereiche liegen hinter "Mehr" und muessen darueber
    # angesteuert werden - auch beim Zurueckschalten nach jedem Klick.
    $subAreas = @('Turnierassistent', 'Druck, Export & Backup', 'Verwaltung & Audit')
    $areas = @('Übersicht', 'Teilnehmer', 'Runde', 'Tabelle', 'Mehr') + $subAreas

    function Enter-Area {
        param([string]$Label)
        if ($subAreas -contains $Label) {
            if (-not (Switch-MainTab -Label 'Mehr')) { return $false }
            Start-Sleep -Milliseconds 350
        }
        return (Switch-MainTab -Label $Label)
    }
    $matrix = @()
    $clicked = 0
    $areasReached = 0

    foreach ($area in $areas) {
        if (-not (Enter-Area -Label $area)) {
            Write-Host ("  [info] Bereich '{0}' ist in diesem Zustand nicht erreichbar." -f $area)
            continue
        }
        $areasReached++
        Start-Sleep -Milliseconds 600

        $rows = (Invoke-MarionetteScript $enumerateScript) | ConvertFrom-Json
        foreach ($row in $rows) {
            if (-not $row.visible) { continue }
            $matrix += [pscustomobject]@{
                Bereich      = $area
                Beschriftung = $row.label
                Deaktiviert  = $row.disabled
                Typ          = $row.type
                Beschriftet  = ($row.label -or $row.hasTitle -or $row.hasAriaLabel)
                Sicher       = $row.safe
                Geklickt     = $false
            }
        }

        # Sichere Elemente dieses Bereichs anklicken und pruefen, dass die
        # Anwendung stehen bleibt.
        $safeRows = @($rows | Where-Object { $_.visible -and $_.safe -and -not $_.disabled })
        foreach ($row in $safeRows) {
            $index = $row.index
            $label = $row.label
            Invoke-MarionetteScript "const b = document.querySelectorAll('button')[$index]; if (b && !b.disabled) { b.click(); } return true;" | Out-Null
            Start-Sleep -Milliseconds 200
            $clicked++
            $entry = $matrix | Where-Object { $_.Bereich -eq $area -and $_.Beschriftung -eq $label } | Select-Object -First 1
            if ($entry) { $entry.Geklickt = $true }

            if (-not (Invoke-MarionetteScript 'return !!document.querySelector("#root");')) {
                Write-Result "Klick auf '$label' im Bereich '$area' zerstoert die Anwendung" $false
                break
            }
            if (Test-MarionetteElement '[role="alertdialog"]') { Send-MarionetteEscape; Start-Sleep -Milliseconds 200 }
            # Der Klick kann den Bereich gewechselt haben - zurueckschalten.
            [void](Enter-Area -Label $area)
            Start-Sleep -Milliseconds 200
        }
    }

    $unlabelled = @($matrix | Where-Object { -not $_.Beschriftet })
    $disabledCount = @($matrix | Where-Object { $_.Deaktiviert }).Count

    Write-Host ("  Bereiche erreicht: {0}/{1}" -f $areasReached, $areas.Count)
    Write-Host ("  Bedienelemente erfasst: {0} (deaktiviert {1})" -f $matrix.Count, $disabledCount)
    Write-Result 'Der Crawl erreicht die Hauptbereiche der Anwendung' ($areasReached -ge 5) ("erreicht: $areasReached von " + $areas.Count)
    Write-Result 'Der Crawl erfasst eine belastbare Zahl an Bedienelementen' ($matrix.Count -ge 40) ("erfasst: " + $matrix.Count)
    Write-Result 'Kein sichtbares Bedienelement ohne Beschriftung, Titel oder aria-label' ($unlabelled.Count -eq 0) `
        (($unlabelled | ForEach-Object { "$($_.Bereich)/#" }) -join ', ')

    if ($script:Evidence) {
        $matrix | Export-Csv -Path (Join-Path $script:Evidence 'button-matrix.csv') -NoTypeInformation -Encoding utf8
    }

    Write-Host ("  Sichere Bedienelemente geklickt: {0}" -f $clicked)
    Write-Result 'Die Anwendung ueberlebt den Klickdurchlauf' ([bool](Invoke-MarionetteScript 'return !!document.querySelector("#root");'))
    Write-Result 'Kein Klick loest einen nativen Browserdialog aus' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'nativeDialogs'))) (Get-Instrumented 'nativeDialogs')
    Write-Result 'Kein Klick erzeugt eine unbehandelte Promise-Ablehnung' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'rejections'))) (Get-Instrumented 'rejections')
    Write-Result 'Kein Klick erzeugt einen Seitenfehler' ([string]::IsNullOrWhiteSpace((Get-Instrumented 'page'))) (Get-Instrumented 'page')
    Save-Evidence '07-button-crawl'

    if ($script:Evidence) {
        @(
            "Firefox-Flow-Smoke"
            "Zeitpunkt : $(Get-Date -Format 'o')"
            "Browser   : $($session.capabilities.browserName) $($session.capabilities.browserVersion)"
            "BaseUrl   : $script:BaseUrl"
            "Buttons   : erfasst $($matrix.Count) in $areasReached Bereichen, geklickt $clicked"
            "Ergebnis  : $script:Ok OK, $script:Failed FEHLER"
        ) | Set-Content -Encoding utf8 -Path (Join-Path $script:Evidence 'firefox-flow-summary.txt')
    }

    Write-Host ''
    Write-Host '=========================================='
    Write-Host ("Firefox-Flow: {0} OK, {1} FEHLER" -f $script:Ok, $script:Failed)
    if ($script:Failed -gt 0) {
        Write-Host 'Turnierablauf NICHT bestanden.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Alle geprueften Bedienablaeufe gruen.'
    exit 0
} catch {
    $smoke.Failed = $true
    throw
} finally {
    if ($script:Failed -gt 0) { $smoke.Failed = $true }
    try { Disconnect-Marionette } catch { }
    Stop-StmFirefoxSmoke -Context $smoke -KeepBrowserOpen:$KeepBrowserOpen
}
