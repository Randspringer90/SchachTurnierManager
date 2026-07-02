# SchachTurnierManager

Lokaler Turniermanager für Schweizer-System-Turniere im Vereins- und Open-Kontext.

## Aktueller Stand bis 0.41.x

- Turniere lokal anlegen, speichern und als portable Version starten.
- Teilnehmer erfassen, importieren, bearbeiten, zurückziehen und löschen.
- Externe Spielerdaten per FIDE-ID suchen und übernehmen.
- Schweizer-System-Paarungen mit global optimaler Rematch-Vermeidung bis 20 Spieler,
  Audit, Bye-/kampflos-Prüfungen und Regressionstests.
- Ergebnisse, Tabellen, Kategorien, Kreuztabelle, Rundenblätter und Exporte.
- Persistentes Audit-Journal mit Dashboard, Exporten und Query-API.
- Operator-Readiness-Smoke für lokale synthetische Turniertagsprüfung.
- Release-Gate für Restore, Build, Tests, Frontend-Build und Portable-Paket.
- Commit-Guard mit Open-Source-Sicherheitsprüfungen gegen Artefakte, lokale Audits, Backups, interne Registry-URLs und typische Secret-Muster.

## Projektstruktur

- `src/`, `tests/`: .NET-Solution (Domain, Application, Infrastructure, WebApi) und React/TypeScript-WebApp; Architektur in `docs/architecture/ARCHITECTURE.md`.
- `docs/architecture/`: dauerhafte Architektur- und Fachkonzepte, inkl. `AI_AGENT_ARCHITECTURE.md`.
- `docs/planning/`: Roadmaps, Tickets und Abläufe, inkl. `PROJECT_ORCHESTRATION.md` (welche Aufgabe über welches Skript läuft).
- `docs/handoffs/`: historisches Handoff-Archiv (nicht mehr gepflegt, nicht im Public Snapshot).
- `scripts/`: aktive Skripte mit Übersicht in `scripts/README.md`; historische After-Apply-Skripte unter `scripts/archive/after-apply/`.
- `AGENTS.md`: verbindliche, providerneutrale Regeln für KI-Agenten; `.agents/skills/` enthält wiederverwendbare Skills, `.claude/` nur einen Adapter.

## Bewusste Grenzen

- Schweizer-System ist noch kein vollständiges FIDE-Dutch.
- Felder mit mehr als 20 aktiven Spielern nutzen den dokumentierten Greedy-Fallback.
- QR/Handy funktioniert nur im gleichen WLAN/Hotspot und muss vor Ort mit echter Laptop-IP
  getestet werden; Browser-Würfeln am Laptop bleibt der Fallback.

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
