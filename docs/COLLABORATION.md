# Zusammenarbeit

Ziel: Ein Bekannter kann lokal mitarbeiten, ohne Releases, private Daten oder Turnierbetrieb zu
gefaehrden.

## Grundregeln

- Kein Push, Release, Tag oder PR ohne ausdrueckliche Freigabe des Maintainers.
- Keine GitHub-Admin-Aktionen, Rechtevergaben, Branch-Protection-Aenderungen oder
  Repository-Einstellungen automatisch ausfuehren.
- Keine echten `local-input/**/*.local.json`, Datenbanken, Logs, `output/**`, `.env`, `.npmrc`
  mit Tokens oder lokale Backups committen.
- Neue Arbeit in kleinen Branches vorbereiten, z. B. `feature/operator-dashboard-export-pack`.
- Fuer fachliche Logik zuerst Tests schreiben oder erweitern; Pairing-Entscheidungen muessen
  auditierbar bleiben.

## Rollen

- **Turnierleiter:** entscheidet fachlich ueber Paarungen, Korrekturen, Warnungen,
  Wertungs-/Aushang-Freigabe und Restore im Ernstfall.
- **Operator:** bedient die lokale App am Turniertag, erfasst Ergebnisse, zieht Backups,
  exportiert Audit-Bundles und nutzt Zuschauer-/Beamer-Links.
- **Entwickler:** arbeitet in kleinen lokalen Branches, nutzt synthetische Daten und
  implementiert nur die beauftragte Scheibe.
- **Reviewer:** prueft Diff, Tests, Datenschutz, Runbook-Auswirkungen und ob Pairing-/Export-
  Entscheidungen auditierbar bleiben.

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
   Vorschlag: Titel, Ziel, Nicht-Ziele, betroffene Dateien, Tests, Datenschutzrisiken.
2. Branch lokal anlegen, z. B. `feature/help-beamer-local-display` oder
   `fix/operator-smoke-timeout`.
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

## Review-Vorschlag fuer Bekannte

- Erst lokal Diff lesen: `git diff --stat`, danach betroffene Dateien.
- Funktional pruefen: App starten, synthetisches Turnier nutzen, keine echten
  `local-input/**/*.local.json`-Dateien.
- UI-Pruefung: Desktop und schmale Breite; bei QR/Beamer echte LAN-IP nur lokal testen.
- Review-Kommentar kurz halten: Blocker, Risiko, Testluecke, Verbesserungsvorschlag.
- Keine Schreibrechte, Secrets, Tokens, GitHub-Admin-Aktionen oder PR-Erstellung ohne
  ausdrueckliche Maintainer-Freigabe.

## Review-Gates

- Import/Export: nur synthetische Fixtures; echte lokale Turnierdaten bleiben privat.
- Schweizer System: keine Algorithmusaenderung ohne Golden-/Regressionstest und Audit-Erklaerung.
- UI: keine Paarungslogik im Frontend; klare Fehler und Operator-nahe Statusmeldungen.
- KI-Hilfe: nur Mock/default-aus oder BYO-Key ueber lokale Secrets; keine Provider-Keys im Git.
- Zuschauer/Beamer: read-only, keine Operator-Controls und keine Schreib-Endpunkte.

## Offene Einstiegsthemen

- Offline-/Fallback-Test: Turniertags-Neustart, direkte Exportlinks, Backup/Restore und
  Papier-Fallback mit synthetischen Daten pruefen.
- Beamer-/Zuschaueransicht: lokale read-only Anzeige ohne Operator-Bedienelemente vorbereiten.
- Echter Handy-/Beamer-/WLAN-Test mit Vor-Ort-Geraet dokumentieren.
- Tie-Breaks: ungespielte Runden/FIDE-Virtual-Opponent opt-in integrieren.
