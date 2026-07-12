# Completion - Operator-Dashboard und Export-/Print-Turnierpaket (2026-07-04)

## TL;DR

Feature-Scheibe 0.43.0 abgeschlossen: Das Dashboard zeigt den Operator-Zustand kompakter,
Turnierpaket-HTML/JSON sind lokal exportierbar, der Smoke prueft die Paket-Endpunkte, und die
Runbooks sind aktualisiert. Kein Push, kein Release, kein PR.

## Ausgangsstatus

- Git vor Start: `main...origin/main [ahead 3]`, Arbeitsbaum sauber.
- Remote: `https://github.com/Randspringer90/SchachTurnierManager.git`.
- Letzter lokaler Commit vor diesem Lauf: `3a8d253 Harden preset import and restore guard`.
- Public-Sonderfall: lokale Commits erlaubt, Push/Release/PR gesperrt ohne Freigabe.

## Umgesetzt

- Operator-Dashboard
  - Uebersicht um Operator-Aktionen, Warnungen/Handlungsbedarf, Sicherungs-/Exportstand und
    lokale Handy-/Operator-Preview mit QR/URL ergaenzt.
  - Fehler werden als ausblendbare Meldung angezeigt; die restliche UI bleibt bedienbar.
  - Schnellaktionen: Teilnehmer/Import, Backup JSON, Turnierpaket HTML/JSON, aktuelle
    Paarungen CSV, Audit-Bundle JSONL.
- Export-/Print-Turnierpaket
  - Neue Endpunkte:
    - `GET /api/tournaments/{id}/package/print/html`
    - `GET /api/tournaments/{id}/package/export.json`
  - Paketinhalt: Teilnehmerliste, aktuelle Runde/Paarungen, Ergebnisbogen, Tabelle/Standings,
    Backup-/Audit-Hinweise und Export-Dateiverweise.
  - Keine PDF-Dependency; PDF bleibt Browser-Druckfunktion.
- Smoke/Runbooks
  - `Smoke-OperatorWorkflow.ps1` baut das Release-Backend vor dem isolierten Start frisch,
    damit keine veraltete DLL getestet wird.
  - Smoke prueft zusaetzlich Turnierpaket HTML/JSON.
  - README, PLANS, CHANGELOG, NEXT_PROMPTS, Runbook, Checklist, Operator-Card,
    Preset-Import-Hinweis und Collaboration-Doku aktualisiert.
- Version
  - Health, `package.json`, Lockfile-Root und UI-Version auf `0.43.0`.

## Tests / Checks

- `dotnet test` - gruen, 181 Tests.
- `npm run build` in `src\SchachTurnierManager.WebApp` - gruen.
- Synthetischer Preset-Dry-run in `tmp\preset-import-smoke\synthetic.local.json` - erfolgreich,
  keine API-Aenderung; 2 erwartete Warnungen im Report wegen synthetischem Testkontext.
- `pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1`
  - erster Lauf rot: vorhandene Release-DLL war noch `0.42.0`, Paket-Endpunkte fehlten.
  - Script korrigiert: Release-WebApi wird vor isoliertem Start frisch gebaut.
  - Wiederholung gruen: 31 OK, 0 Fehler.
- `pwsh -File .\scripts\Test-RepositoryOpenSourceSafety.ps1` - gruen.
- `pwsh -File .\scripts\Test-GitCommitSafety.ps1` - gruen.
- `.npmrc`-Pruefung - keine `.npmrc` gefunden.
- Secret-/Token-Regex ueber geaenderte Dateien - keine credential-foermigen Treffer.
- `git diff --check` - gruen; nur CRLF-Hinweise.
- `pwsh -File .\scripts\Test-PortablePackageGate.ps1` - gruen.

## Risiken / offene Punkte

- Echter Handy-/Hotspot-/WLAN-Test wurde nicht mit realem Geraet ausgefuehrt.
- Beamer-/Zuschaueransicht ist noch keine getrennte read-only Ansicht; die lokale QR/URL ist nur
  Vorbereitung fuer den Operator-/Hotspot-Test.
- Kein echter `local-input/**/*.local.json`-Import wurde ausgefuehrt oder committet.
- Schweizer System bleibt kein vollstaendiges FIDE-Dutch; >20 Spieler nutzen dokumentierten
  Greedy-Fallback.

## Naechster sinnvoller Schritt

Feature-Scheibe 3: Offline-/Fallback-Betrieb und lokale Beamer-/Zuschaueransicht vorbereiten.
Prompt steht in `docs/NEXT_PROMPTS.md`.
