# Zusammenarbeit

Ziel: Ein Bekannter kann lokal mitarbeiten, ohne Releases, private Daten oder Turnierbetrieb zu
gefaehrden.

## Grundregeln

- Kein Push, Release, Tag oder PR ohne ausdrueckliche Freigabe des Maintainers.
- Keine echten `local-input/**/*.local.json`, Datenbanken, Logs, `output/**`, `.env`, `.npmrc`
  mit Tokens oder lokale Backups committen.
- Neue Arbeit in kleinen Branches vorbereiten, z. B. `feature/operator-dashboard-export-pack`.
- Fuer fachliche Logik zuerst Tests schreiben oder erweitern; Pairing-Entscheidungen muessen
  auditierbar bleiben.

## Lokales Setup

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
dotnet restore
dotnet build
Set-Location ".\src\SchachTurnierManager.WebApp"
npm install
npm run build
```

Start fuer Entwicklung:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
.\RUN_TURNIERMANAGER.bat
```

## Arbeitsablauf

1. Issue oder kurze Aufgabenbeschreibung in `docs/NEXT_PROMPTS.md`/Ticket festhalten.
2. Branch lokal anlegen.
3. Kleine Scheibe umsetzen.
4. Checks ausfuehren:
   ```powershell
   dotnet test
   Set-Location ".\src\SchachTurnierManager.WebApp"; npm run build
   Set-Location "D:\Schach\SchachTurnierManager"
   pwsh -File .\scripts\Test-RepositoryOpenSourceSafety.ps1
   git diff --check
   ```
5. Lokaler Commit ist ok, wenn Gates gruen sind. Push/PR erst nach Freigabe.

## Review-Gates

- Import/Export: nur synthetische Fixtures; echte lokale Turnierdaten bleiben privat.
- Schweizer System: keine Algorithmusaenderung ohne Golden-/Regressionstest und Audit-Erklaerung.
- UI: keine Paarungslogik im Frontend; klare Fehler und Operator-nahe Statusmeldungen.
- KI-Hilfe: nur Mock/default-aus oder BYO-Key ueber lokale Secrets; keine Provider-Keys im Git.

## Offene Einstiegsthemen

- Operator-Dashboard: Backup-/Audit-Stand und naechste Aktion kompakter anzeigen.
- Exportpaket: Tabelle, Paarungen, Rundenblatt, Audit-Hinweis und Backup-Erinnerung buendeln.
- Tie-Breaks: ungespielte Runden/FIDE-Virtual-Opponent opt-in integrieren.
- Beamer-/Publikumsmodus ohne Operator-Bedienelemente.
