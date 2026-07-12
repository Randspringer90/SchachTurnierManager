# Completion - Preset-Import, Restore-Guard, Zusammenarbeit/KI (2026-07-03)

## TL;DR

Feature-Scheibe 0.42.0 abgeschlossen: Bergfest-/Preset-Import ist reportgestuetzt
gehaertet, Restore-Import validiert defekte Snapshots, Zusammenarbeit und KI-Hilfe sind
als Doku-/Config-Basis vorbereitet. Kein Push, kein Release, kein PR.

## Ausgangsstatus

- Angeforderter Pfad `D:\KFM\Schach\SchachTurnierManager` existierte lokal nicht.
- Gearbeitet wurde im vorhandenen Repo `D:\Schach\SchachTurnierManager`.
- Git vor Start: `main...origin/main [ahead 2]`, Arbeitsbaum sauber.
- Remote: `https://github.com/Randspringer90/SchachTurnierManager.git`.
- Public-Sonderfall: lokale Commits erlaubt, Push/Release/PR gesperrt ohne Freigabe.

## Umgesetzt

- `scripts\Import-TournamentPreset.ps1`
  - Preset-Aufloesung inkl. `-AutoSelectSinglePreset`.
  - Schema-/Runden-/Teilnehmerpruefung.
  - Rating-Fallback-Report (`twzManual`, `dwz`, `eloStandard`, `missing`).
  - Strukturierter JSON-Report unter `output\reports\preset-import-report-*.json`.
  - Konsole bleibt kurz; CSV-Liste nur mit `-ShowCsvPreview`.
  - Echter Import nutzt API-Vorschau `players/preview-import.csv`.
  - Warnungen stoppen echte Imports, bis `-AllowWarnings` bewusst gesetzt wird.
- `TournamentService.SaveImportedTournament(...)`
  - validiert Restore-Snapshots gegen leere Kernfelder, doppelte IDs/Namen/FIDE-/DSB-IDs,
    ungueltige Runden/Bretter, Self-Pairings, Mehrfachpaarungen und unbekannte Spieler.
  - normalisiert Settings beim Restore.
- Safety-Gates
  - `.env.example` als leeres Beispiel erlaubt.
  - echte `.env`/`.env.*` bleiben blockiert.
  - unstaged Safety-Scan prueft aktuelle Aenderungen statt alte getrackte Baseline-Treffer.
- Portable-Packaging
  - `Pack-Portable.ps1` behandelt PowerShell-Cmdlets wie `Compress-Archive` korrekt:
    kein Fehlalarm mehr durch leeres `$LASTEXITCODE`, solange `$?` erfolgreich ist.
- Dokumentation
  - `PLANS.md`, `docs/NEXT_PROMPTS.md`, README, Changelog, Preset-Import-Runbook,
    Bergfest-Runbook, Friday-Checkliste und Operator-Card aktualisiert.
  - `docs/COLLABORATION.md` fuer Mitarbeit.
  - `docs/AI_HELP_ASSISTANT.md` und `.env.example` fuer spaetere BYO-Key KI-Hilfe.

## Tests / Checks

- `dotnet test` - gruen, 179 Tests.
- `npm run build` in `src\SchachTurnierManager.WebApp` - gruen.
- Import-Dry-run mit synthetischem `tmp\preset-import-smoke\synthetic.local.json` - gruen;
  eine erwartete Warnung, weil die Testdatei bewusst in `tmp/**` statt `local-input/**` lag.
- `pwsh -File .\scripts\Test-RepositoryOpenSourceSafety.ps1` - gruen.
- `pwsh -File .\scripts\Test-GitCommitSafety.ps1` - gruen.
- `.npmrc`-Pruefung - keine `.npmrc` gefunden.
- `git diff --check` - gruen; nur CRLF-Hinweise.
- `pwsh -File .\scripts\Test-PortablePackageGate.ps1` - gruen.
- `pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1` - gruen, 29 OK, 0 Fehler.
- Offizieller Commit-Guard/Release-Gate wurde nach dem ZIP-Wrapper-Fix erneut ausgefuehrt
  und vor dem lokalen Commit gruen abgeschlossen.

## Risiken / offene Punkte

- Kein echter `local-input/**/*.local.json`-Import wurde ausgefuehrt oder committet.
- `-AllowWarnings` bleibt eine bewusste Operator-Entscheidung; Report vorher pruefen.
- KI-Hilfe ist nur vorbereitet, nicht produktiv implementiert.
- QR/Handy-Flow muss weiterhin mit echtem Geraet im Veranstaltungs-WLAN/Hotspot getestet werden.
- Schweizer System bleibt kein vollstaendiges FIDE-Dutch; >20 Spieler nutzen dokumentierten
  Greedy-Fallback.

## Naechster sinnvoller Schritt

Feature-Scheibe 2: Operator-Dashboard und Export-/Print-Turnierpaket ausbauen:
letzter Backup-/Audit-Stand, offene Bretter, Importreport-Hinweis und naechste Operator-Aktion
kompakter sichtbar machen. Prompt steht in `docs/NEXT_PROMPTS.md`.
