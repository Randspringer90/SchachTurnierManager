# SchachTurnierManager

Lokaler Turniermanager für Schweizer-System-Turniere im Vereins- und Open-Kontext.

## Aktueller Stand bis 0.38.x

- Turniere lokal anlegen, speichern und als portable Version starten.
- Teilnehmer erfassen, importieren, bearbeiten, zurückziehen und löschen.
- Externe Spielerdaten per FIDE-ID suchen und übernehmen.
- Schweizer-System-Paarungen mit Audit, Bye-/kampflos-Prüfungen und Regressionstests.
- Ergebnisse, Tabellen, Kategorien, Kreuztabelle, Rundenblätter und Exporte.
- Persistentes Audit-Journal mit Dashboard, Exporten und Query-API.
- Release-Gate für Restore, Build, Tests, Frontend-Build und Portable-Paket.
- Commit-Guard mit Open-Source-Sicherheitsprüfungen gegen Artefakte, lokale Audits, Backups, interne Registry-URLs und typische Secret-Muster.

## Projektstruktur

- `src/`, `tests/`: .NET-Solution (Domain, Application, Infrastructure, WebApi) und React/TypeScript-WebApp; Architektur in `docs/architecture/ARCHITECTURE.md`.
- `docs/architecture/`: dauerhafte Architektur- und Fachkonzepte, inkl. `AI_AGENT_ARCHITECTURE.md`.
- `docs/planning/`: Roadmaps, Tickets und Abläufe, inkl. `PROJECT_ORCHESTRATION.md` (welche Aufgabe über welches Skript läuft).
- `docs/handoffs/`: historisches Handoff-Archiv (nicht mehr gepflegt, nicht im Public Snapshot).
- `scripts/`: aktive Skripte mit Übersicht in `scripts/README.md`; historische After-Apply-Skripte unter `scripts/archive/after-apply/`.
- `AGENTS.md`: verbindliche, providerneutrale Regeln für KI-Agenten; `.agents/skills/` enthält wiederverwendbare Skills, `.claude/` nur einen Adapter.

## Start

Backend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Frontend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run dev
```

Dashboard:

```text
http://localhost:5173
```

Healthcheck:

```text
http://localhost:5088/api/health
```

## Release-Gate

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1"
```

## Sicher committen

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "Commit message" -Push
```

Das bestehende private Entwicklungsrepo soll nicht direkt öffentlich geschaltet werden, wenn historische interne Registry-URLs oder lokale Auditdateien enthalten waren. Für eine öffentliche Veröffentlichung wird ein geprüfter Clean Snapshot ohne alte Git-Historie empfohlen.
## Commit-Sicherheitscheck

Commits laufen ueber `scripts/Commit-If-Green.ps1`. Der Guard prueft Build, Tests, Frontend, Paketierung und blockiert lokale Audit-/Backup-Dateien, Artefakte, interne Registry-Referenzen und kritische Zugangsdaten-Muster. Er verwendet kein blindes `git add --all`, sondern zeigt die geaenderten Dateien an und staged nur explizit gepruefte Pfade. Fuer eine spaetere Open-Source-Veröffentlichung wird ein Clean Snapshot ohne private Historie verwendet.

## Open-Source-Clean-Snapshot

Das bestehende private Entwicklungsrepo wird nicht direkt öffentlich geschaltet. Für eine spätere Veröffentlichung kann ein geprüfter Snapshot ohne Git-Historie erzeugt werden:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\New-OpenSourceSnapshot.ps1"
```

Der Snapshot liegt unter `output\open-source-snapshot`, enthält einen Report und schließt lokale Artefakte, historische Handoffs/After-Apply-Skripte, `.codex`, `.vs`, Build-Ausgaben, Logs, Dumps, Datenbanken und Zugangsdaten-Muster aus.
