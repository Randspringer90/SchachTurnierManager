# SchachTurnierManager

Lokaler Turniermanager für Schweizer-System-Turniere im Vereins- und Open-Kontext.

## Aktueller Stand bis 0.51.x

- Turniere lokal anlegen, speichern und als portable Version starten.
- Teilnehmer erfassen, importieren, bearbeiten, zurückziehen und löschen.
- Externe Spielerdaten per FIDE-ID suchen und übernehmen.
- Schweizer-System-Paarungen mit global optimaler Rematch-Vermeidung bis 20 Spieler,
  Audit, Bye-/kampflos-Prüfungen und Regressionstests.
- Ergebnisse, Tabellen, Kategorien, Kreuztabelle, Rundenblätter und Exporte.
- Persistentes Audit-Journal mit Dashboard, Exporten und Query-API.
- Operator-Readiness-Smoke für lokale synthetische Turniertagsprüfung.
- Lokaler Turnierassistent für Format-, Runden-, Zeit-, Brett- und Turniertagsempfehlungen ohne externe KI-API.
- Release-Gate für Restore, Build, Tests, Frontend-Build und Portable-Paket.
- Commit-Guard mit Open-Source-Sicherheitsprüfungen gegen Artefakte, lokale Audits, Backups, interne Registry-URLs und typische Secret-Muster.

## Projektstruktur

- `src/`, `tests/`: .NET-Solution (Domain, Application, Infrastructure, WebApi) und React/TypeScript-WebApp; Architektur in `docs/architecture/ARCHITECTURE.md`.
- `docs/architecture/`: dauerhafte Architektur- und Fachkonzepte, inkl. `AI_AGENT_ARCHITECTURE.md`.
- `docs/planning/`: Roadmaps, Tickets und Abläufe, inkl. `PROJECT_ORCHESTRATION.md` (welche Aufgabe über welches Skript läuft).
- `docs/handoffs/`: historisches Handoff-Archiv (nicht mehr gepflegt, nicht im Public Snapshot).
- `scripts/`: aktive Skripte mit Übersicht in `scripts/README.md`; historische After-Apply-Skripte unter `scripts/archive/after-apply/`.
- `AGENTS.md`: verbindliche, providerneutrale Regeln für KI-Agenten; `.agents/skills/` enthält wiederverwendbare Skills, `.claude/` nur einen Adapter.


### Release/Ops, Logging und lokale Secrets

Seit 0.50.x enthaelt das Projekt einen eigenen Release-/Betriebsunterbau:

- WebApi-Logging mit konfigurierbaren LogLeveln und Single-Line-Konsole.
- HTTP-Request-Logging ohne Querystrings, damit keine Tokens oder API-Keys in Logs landen.
- `.secrets/local/` und `secrets/local/` bleiben lokale, gitignored Ablagen fuer DPAPI-verschluesselte Werte.
- `scripts/Set-LocalSecret.ps1` und `scripts/Get-LocalSecret.ps1` bilden den lokalen DPAPI-Roundtrip ab.
- `scripts/Invoke-ReleaseCandidateReadiness.ps1` sammelt ReleaseGate, SecretSafety, Desktop, Portable und optional Installer in einem Run-ZIP unter `D:\Temp`.
- Agentenregeln und Skills liegen im Projekt selbst unter `AGENTS.md` und `.agents/skills/`, damit Codex, Claude Code und lokale KI-Workflows ohne externe Projektabhaengigkeiten arbeiten koennen.



### Kollegenpaket / einfache Installation

Seit 0.51.1 erzeugt `scripts/Invoke-ColleagueInstallReadiness.ps1` ein eigenstaendiges Kollegenpaket unter `output\SchachTurnierManager_Kollegenpaket_<Version>.zip`. Das Paket enthaelt Desktop-ZIP, Portable-ZIP, optional die Setup-EXE, ein `README_START_HIER.txt`, ein Manifest und SHA256-Pruefsummen.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ColleagueInstallReadiness.ps1" -BuildInstaller -AllowMissingInnoSetup
```

Beim Kollegen gilt: Setup-EXE per Doppelklick verwenden, falls vorhanden; sonst Desktop-ZIP entpacken und `SchachTurnierManager.bat` per Doppelklick starten. Es wird kein .NET, Node oder npm auf dem Zielrechner benoetigt.



### Kollegenpaket-Frischlauf testen

Seit 0.52.0 kann das erzeugte Kollegenpaket in einem frischen Testordner automatisch geprueft werden. Der Test entpackt das Paket, validiert SHA256-Pruefsummen, entpackt das Desktop-ZIP, startet die WebApi auf einem freien Loopback-Port und prueft Health, Dashboard, Turnierliste und isolierten SQLite-Datenpfad.

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ColleagueFreshRunTest.ps1" -BuildPackage -BuildInstaller -AllowMissingInnoSetup
```

Am Ende wird ein Run-ZIP unter `D:\Temp` ausgegeben. Ein echter Test auf einem Kollegenrechner bleibt fuer die finale Freigabe sinnvoll, aber der Frischlauf schliesst die haeufigsten Paketierungsfehler bereits lokal aus.


## Bewusste Grenzen

- Schweizer-System ist noch kein vollständiges FIDE-Dutch.
- Felder mit mehr als 20 aktiven Spielern nutzen den dokumentierten Greedy-Fallback.
- QR/Handy funktioniert nur im gleichen WLAN/Hotspot und muss vor Ort mit echter Laptop-IP
  getestet werden; Browser-Würfeln am Laptop bleibt der Fallback.


### Lokale Turnierhilfe / Wissensbasis

Der Reiter **Assistent** enthält eine lokale Chat-Hilfe. Seit 0.48.0 werden die Schnellfragen und Wissensartikel unter `src/SchachTurnierManager.WebApp/src/knowledge/localKnowledgeBase.json` gepflegt. Die Hilfe ist lokal-only: Es werden keine Turnierdaten, Logs, Personendaten oder Secrets an externe KI-Anbieter gesendet.
### Exportmanifest fuer Turnierleiter

Seit 0.49.0 erzeugt der Turniermanager ein lokales Exportmanifest unter `exports/manifest.json`. Es listet die wichtigsten Downloadpfade fuer Teilnehmer-CSV, Tabelle, Paarungen, Druckansicht und Audit-Bundles, nennt offene Bretter/Byes/kampflose Ergebnisse und enthaelt einen empfohlenen Veroeffentlichungs-Workflow. Das Manifest ist local-only und fuehrt keine Uploads aus.


### Lokale Secrets und DPAPI

Lokale Secrets liegen bevorzugt unter `.secrets/local/*.dpapi.txt` und werden nicht eingecheckt. `scripts/Set-LocalSecret.ps1` speichert Werte per Windows-DPAPI fuer den aktuellen Benutzer und Rechner; `scripts/Get-LocalSecret.ps1` liest sie wieder aus. Die Dateien sind dadurch nicht portabel und muessen pro Rechner/Benutzer neu gesetzt werden. Der Release-Check `scripts/Invoke-SecretSafetyReadiness.ps1` prueft GitSafety, DPAPI-Roundtrip und Gitignore-Schutz.


## Desktop-Version für Endnutzer (self-contained)

Für Rechner **ohne** Entwicklerwerkzeuge (kein .NET, kein Node nötig):

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Publish-DesktopApp.ps1"
```

Ergebnis unter `output\desktop`: Doppelklick auf **`SchachTurnierManager.bat`** startet das
Backend (minimiert) und öffnet das Dashboard unter `http://127.0.0.1:5088/`. Turnierdaten
liegen unter `%LocalAppData%\SchachTurnierManager`.

Eine Installer-EXE (Inno Setup, Desktop-Verknüpfung, Startmenü, Uninstaller) ist unter
`installer/` vorbereitet und wird mit `scripts\Build-Installer.ps1` gebaut (benötigt
lokal installiertes Inno Setup 6). Der empfohlene Prüflauf ist:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-InstallerReadiness.ps1" -BuildInstaller -AllowMissingInnoSetup
```

Der Prüflauf erzeugt ein ZIP unter `D:\Temp` mit Logs, Manifesten und manueller Testcheckliste.


## Portable-ZIP-Frischordner-Test

Für eine Endnutzer-nahe Prüfung des Portable-Pakets ohne manuelle Logflut:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-PortableFreshFolderTest.ps1"
```

Der Lauf baut standardmäßig ein self-contained Portable-ZIP, entpackt es in einen frischen
Ordner unter `D:\Temp`, startet die App auf einem Testport, prüft Healthcheck, eingebettetes
Dashboard, Turnierlisten-API und den isolierten SQLite-Datenpfad. Am Ende wird ein
`UPLOAD_ZIP=...` ausgegeben.

Der Paketmanifest-Teil toleriert leere ZIP-Ordner wie `data` und listet die
erkannten Portable-Dateien robust bis Tiefe 3 auf.


## Turnierassistent

Der Reiter **Assistent** hilft Turnierleitern bei der Vorbereitung: Teilnehmerzahl, Zeitfenster,
Bretter und Szenario erfassen; die App empfiehlt Format, Rundenzahl, Zeitbedarf, Setup-Schritte,
Turniertag-Checkliste und Exportplan. Der Assistent ist rein lokal und regelbasiert. Es werden
keine Turnierdaten, Logs, Secrets oder personenbezogenen Daten an externe KI-Dienste gesendet.

Prüflauf:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-TournamentAssistantReadiness.ps1"
```

Der Lauf erzeugt ein `UPLOAD_ZIP=...` unter `D:\Temp`.

## Mehrsprachigkeit

Die WebApp hat ein dependency-freies i18n-Fundament mit Sprachumschalter im Kopfbereich
(18 Sprachen registriert; Deutsch/Englisch/Spanisch mit Kernübersetzungen, weitere folgen).
Details und Mitmach-Anleitung: `src/SchachTurnierManager.WebApp/src/i18n/README.md`.


### Lokale Chat-Hilfe

Der Reiter **Assistent** enthaelt eine lokale, regelbasierte Chat-Hilfe. Sie beantwortet Fragen zu Turnierstart, Auslosung, Wertungen, Backup, QR/Handy, Import/Export und KI-Datenschutz. Es werden keine Daten an Claude, OpenAI oder andere externe Anbieter gesendet. Die spaetere echte KI-Anbindung ist als BYOK-/Provider-Adapter geplant und bleibt ein eigener Roadmap-Schritt.

## Schnellstart (empfohlen)

Zum Starten doppelklicken: **`RUN_TURNIERMANAGER.bat`** (im Repo-Root).

Die Datei startet Backend und Frontend in getrennten Fenstern und öffnet den Browser
auf `http://localhost:5173`. Sie nutzt PowerShell 7 (`pwsh`), falls vorhanden, sonst
Windows PowerShell, jeweils mit `-ExecutionPolicy Bypass` nur für diesen Prozess – die
globale ExecutionPolicy wird **nicht** verändert und es werden **keine** Adminrechte benötigt.

> Hinweis: Wenn PowerShell `.\scripts\Start-Dev.ps1` direkt mit der Meldung
> „cannot be loaded … is not digitally signed" blockiert, einfach `RUN_TURNIERMANAGER.bat`
> verwenden – die BAT umgeht die Signaturprüfung prozesslokal.

## Start (manuell)

Alle manuellen Befehle werden aus dem Repo-Root ausgeführt.

Backend:

```powershell
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Frontend:

```powershell
Push-Location .\src\SchachTurnierManager.WebApp; npm install; npm run dev; Pop-Location
```

Dashboard:

```text
http://localhost:5173
```

Healthcheck:

```text
http://localhost:5088/api/health
```

## Chess960-Würfeln pro Brett (Desktop + QR/Handy)

Im Rundenbereich hat jedes reguläre Brett neben der Chess960-Spalte einen
**„🎲 Würfeln"**-Button. Er öffnet ein Popup für genau dieses Turnier, diese Runde und
dieses Brett – mit zwei internen Reitern:

- **Browser würfeln:** Der Würfel arbeitet sich Feld für Feld von links nach rechts durch
  die acht Felder der Grundreihe und zeigt die Figuren. Anschließend
  „💾 Für Brett speichern" (oder „🎲 Nochmal würfeln" / „Abbrechen"). Eine bereits
  gespeicherte Stellung wird nur nach Rückfrage überschrieben. Die Stellung bleibt nach
  Reload/Backup erhalten und erscheint weiter auf dem Rundenblatt/Druck.
- **QR / Handy (nur lokal):** Zeigt einen QR-Code und eine LAN-URL, mit der
  Teilnehmer/Schiedsrichter dieses Brett am Handy auswürfeln. Funktioniert **nur im
  gleichen WLAN/Hotspot** wie der Laptop. Kein Cloud-Dienst, kein Tunnel.

Hinweise zur QR/Handy-Nutzung:

- **`localhost` funktioniert am Handy nicht** – es zeigt auf das Handy selbst. Im QR-Reiter
  die **LAN-IP des Laptops** eintragen (Windows: `ipconfig` → IPv4-Adresse). Beim Start über
  `RUN_TURNIERMANAGER.bat` werden die möglichen Laptop-Adressen im Startfenster angezeigt.
- Der Dev-Server ist für das LAN erreichbar (`vite --host 0.0.0.0`); `http://localhost:5173`
  am Laptop funktioniert weiterhin.
- Eine **Windows-Firewall** kann den Zugriff auf Port `5173` blockieren. Dann am Laptop
  würfeln – die Browser-Würfelfunktion ist davon unabhängig und immer verfügbar.
- Würfeln Laptop und Handy gleichzeitig dasselbe Brett, gilt die zuletzt gespeicherte
  Stellung; vorhandene Stellungen werden nur nach Rückfrage überschrieben.

Der bestehende Button „🎲 Schachwürfel öffnen" (alle Bretter einer Runde auf einmal) bleibt
unverändert erhalten.

## Nach jeder Runde: Audit sichern

Jede Turnierleiter-Aktion landet im Audit-Journal (DB **und** append-only Datei-Spiegel unter
`%LocalAppData%\SchachTurnierManager\audit\`). Zur Forensik nach **jeder Runde** und am
**Turnierende** ein Bundle exportieren und lokal sichern:

- **WebApp:** Audit-Journal-Karte → **„Audit-Bundle (JSONL)"** oder **„(JSON)"**.
- **Skript:** `pwsh -File .\scripts\Export-TournamentAudit.ps1` (Datei landet in `output\audit\`,
  kein Upload, keine Cloud).

Das Bundle ist in sich geschlossen (Manifest, Turnier-Snapshot, Pairing-Forensik je Runde, alle
Ereignisse) und macht spätere Nachfragen nachvollziehbar. Details: `docs/AUDIT_JOURNAL.md`.

## Release-Gate

Für lokale Build-/Test-Prüfung ohne Portable-Paket:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1" -SkipPack
```

Das vollständige Gate ohne `-SkipPack` erstellt zusätzlich ein lokales Portable-Paket
unter `output\` und gehört in einen explizit freigegebenen Release-Lauf.

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1"
```

## Operator-Readiness-Smoke

Nach einem Build kann der lokale Turniertag mit rein synthetischen Daten geprüft werden:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Smoke-OperatorWorkflow.ps1"
```

Der Smoke startet isolierte lokale API-Prozesse, prüft Health, Swiss 12/5, Round-Robin,
Manual-Pairing-Guards, Backup/Restore und Chess960/QR-URL-Form. Artefakte liegen unter
`output\operator-readiness-smoke\` und werden nicht committet.

## Sicher committen

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "Commit message"
```

`-Push` nur mit ausdrücklicher Freigabe verwenden. Das bestehende private Entwicklungsrepo soll nicht direkt öffentlich geschaltet werden, wenn historische interne Registry-URLs oder lokale Auditdateien enthalten waren. Für eine öffentliche Veröffentlichung wird ein geprüfter Clean Snapshot ohne alte Git-Historie empfohlen.
## Commit-Sicherheitscheck

Commits laufen ueber `scripts/Commit-If-Green.ps1`. Der Guard prueft Build, Tests, Frontend, Paketierung und blockiert lokale Audit-/Backup-Dateien, Artefakte, `.npmrc`, interne Registry-Referenzen und kritische Zugangsdaten-Muster. Er verwendet kein blindes `git add --all`, sondern zeigt die geaenderten Dateien an und staged nur explizit gepruefte Pfade. Fuer eine spaetere Open-Source-Veröffentlichung wird ein Clean Snapshot ohne private Historie verwendet.

## Open-Source-Clean-Snapshot

Das bestehende private Entwicklungsrepo wird nicht direkt öffentlich geschaltet. Für eine spätere Veröffentlichung kann ein geprüfter Snapshot ohne Git-Historie erzeugt werden:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\New-OpenSourceSnapshot.ps1"
```

Der Snapshot liegt unter `output\open-source-snapshot`, enthält einen Report und schließt lokale Artefakte, historische Handoffs/After-Apply-Skripte, `.codex`, `.vs`, Build-Ausgaben, Logs, Dumps, Datenbanken und Zugangsdaten-Muster aus.

### RUN-03 Frischordner-Smoke

Der Portable-Frischordner-Test liegt unter `scripts\Invoke-PortableFreshFolderTest.ps1`.
Er baut das Portable-ZIP, entpackt es in einen isolierten Ordner unter `D:\Temp`, startet
die WebApi auf einem Testport und prueft Health, eingebettetes Dashboard, Turnierlisten-API
und SQLite-Datenpfad. Leere Paketordner wie `data` werden im Manifest als optional
behandelt, weil ZIP-Werkzeuge leere Ordner nicht immer erhalten.

### RUN-08 PWA-/Handy-Basis

Die WebApp ist als Progressive Web App vorbereitet: `manifest.webmanifest`, SVG-Icons,
Theme-Farbe und Service Worker werden beim Frontend-Build in die eingebettete WebApp
uebernommen. Der Service Worker cached nur App-Shell und statische Assets. API-Aufrufe
unter `/api/*` bleiben bewusst network-only, damit Turnierdaten nicht unkontrolliert im
Browser-Cache landen.

Readiness-Test:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-PwaReadiness.ps1"
```

Am Ende wird ein `UPLOAD_ZIP=...` unter `D:\Temp` erzeugt.

## Release- und Kollegeninstallation

Für eine weitergebbare Windows-Version gibt es ab 0.50.0 einen gebündelten Release-Check:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Der Lauf erzeugt ein `UPLOAD_ZIP=...` mit Logs und Manifest. Für normale Nutzer ist aktuell die Desktop-Variante relevant:

```text
output\desktop\SchachTurnierManager.bat
```

Diese Variante ist self-contained und benötigt beim Nutzer keine separate .NET-Installation. Die echte Setup-EXE wird gebaut, sobald Inno Setup 6 lokal verfügbar ist.

Lokale Secrets für spätere KI-/Provider-Anbindungen werden innerhalb des Projekts unter `.secrets/local/` DPAPI-verschlüsselt abgelegt und nicht committed.

## Release-/Betriebspruefung

Der Release-Candidate-Lauf sammelt alle Detailausgaben in einem eigenen Ordner unter `D:\Temp` und erzeugt am Ende genau ein `UPLOAD_ZIP=...` fuer die Uebergabe an den naechsten KI-/Review-Lauf:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseCandidateReadiness.ps1" -BuildInstaller -AllowMissingInnoSetup
```

Der Lauf prueft ReleaseGate, DPAPI-/Secret-Safety, Desktop-Publish, Portable-ZIP, optional Installer-Readiness und GitSafety. Lokale Secrets liegen ausschliesslich unter `.secrets/local/` beziehungsweise `secrets/local/`, werden per Windows-DPAPI verschluesselt und sind gitignored.


## Kollegeninstallation ab 0.53.0

Das Release-/Kollegenpaket enthaelt neben Desktop-/Portable-ZIP auch einen einfachen Klickpfad:

1. `Install-SchachTurnierManager.cmd` per Doppelklick starten.
2. Danach ueber den Startmenue-Shortcut **SchachTurnierManager** starten.
3. Bei Bedarf `Uninstall-SchachTurnierManager.cmd` aus dem Paket nutzen.

Die Installation liegt standardmaessig unter `%LocalAppData%\Programs\SchachTurnierManager`. Turnierdaten bleiben getrennt unter `%LocalAppData%\SchachTurnierManager`. Lokale DPAPI-Secrets werden nicht ausgeliefert und muessen je Benutzer/Rechner neu gesetzt werden.

Pruefung fuer Maintainer:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ClickInstallReadiness.ps1 -BuildPackage -BuildInstaller -AllowMissingInnoSetup
```
