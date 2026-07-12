# Completion - Hilfe/Assistent, QR/Handy/Beamer und Kollaboration (2026-07-04)

## TL;DR

Feature-Scheibe 0.44.0 abgeschlossen: Die App hat einen sicheren Reiter **Hilfe / Assistent**,
lokale Runbook-Themen mit Suche, deaktivierten KI-Default, eine read-only Zuschauer-/Beamer-
Ansicht und getrennte lokale QR-Links fuer Zuschauer/Beamer vs. Operator-Erfassung. Kein Push,
kein Release, kein PR.

## Ausgangsstatus

- Git vor Start: `main...origin/main [ahead 4]`, Arbeitsbaum sauber.
- Remote: `https://github.com/Randspringer90/SchachTurnierManager.git`.
- Letzter lokaler Commit vor diesem Lauf: `ff9f6af Add operator dashboard and tournament package`.
- Public-Sonderfall: lokale Commits erlaubt, Push/Release/PR gesperrt ohne Freigabe.
- Keine `.npmrc` gefunden; `.codex/config.toml` und `.agents/skills/**/SKILL.md` nicht vorhanden.

## Umgesetzt

- KI-Hilfe / Assistent
  - Application-Vertrag `IAiHelpProvider`, `AiHelpStatus`, `AiHelpRequest`,
    `AiHelpResponse` und lokale Themenmodelle.
  - `DisabledAiHelpProvider` als Default mit klarer Meldung `KI-Hilfe nicht konfiguriert`.
  - `LocalDocsAiHelpProvider` fuer lokale Docs-only-Antworten ohne Cloud.
  - API-Endpunkte `GET /api/help/assistant` und `POST /api/help/assistant/ask` mit weichem
    Fehlerverhalten.
  - WebApp-Reiter **Hilfe / Assistent** mit lokaler Suche ueber Runbook-Themen.
  - `.env.example` auf `STM_AI_PROVIDER=disabled` plus leere OpenAI/Claude/Custom-Shape
    aktualisiert; keine echten Keys.
- QR / Handy / Beamer
  - Read-only WebApp-Route `?view=public` / `?view=beamer` fuer aktuelle Paarungen,
    offene Bretter und Tabelle.
  - Dashboard-Panel **QR / Handy / Beamer** trennt Zuschauer-/Beamer-Link von
    Operator-Erfassung.
  - QR-Codes fuer Handy/Operator erscheinen nur bei privater LAN-IP; `localhost` wird
    sichtbar gewarnt.
  - Exportcenter verlinkt Zuschaueransicht und Beamer-Modus.
- Export / Print
  - Turnierpaket-HTML/JSON weist Paarungen, Ergebnisbogen, Backup/Audit und
    Zuschauer-/Beamer-Hinweis expliziter aus.
  - Keine PDF-Dependency; PDF weiter ueber Browser-Druck.
- Kollaboration / Doku
  - Rollen Turnierleiter, Operator, Entwickler, Reviewer dokumentiert.
  - Branch-/Issue-/Review-Vorschlag fuer Bekannte ergaenzt.
  - Runbook, Operator-Card, Checklist, Preset-Import-Doku, README, PLANS, CHANGELOG,
    NEXT_PROMPTS und lokale UI-Skill-Notiz aktualisiert.

## Tests / Checks

- `dotnet test` - gruen, 183 Tests.
- `npm run build` in `src\SchachTurnierManager.WebApp` - gruen.
- Synthetischer Preset-Dry-run mit `tmp\preset-import-smoke\synthetic.local.json` - erfolgreich,
  keine API-Aenderung; 2 erwartete Warnungen im synthetischen Testkontext.
- `pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1` - gruen, 31 OK, 0 Fehler, Health v0.44.0.
- `pwsh -File .\scripts\Test-RepositoryOpenSourceSafety.ps1` - gruen.
- `pwsh -File .\scripts\Test-GitCommitSafety.ps1` - gruen.
- `.npmrc`-Pruefung - keine `.npmrc` gefunden.
- Credential-Shape-Scan ueber versionierte und neue Dateien - keine Treffer.
- `git diff --check` - Exit 0; nur bekannte CRLF-Hinweise.
- `pwsh -File .\scripts\Test-PortablePackageGate.ps1` - gruen.
- Playwright Responsive-Smoke - gruen nach Installation des lokalen Playwright-Chromium:
  `public-mobile.png`, `beamer-desktop.png`, `operator-mobile.png`.

## Risiken / offene Punkte

- Kein echtes Handy, kein echter Beamer und kein reales Veranstaltungs-WLAN/Hotspot wurden
  getestet. Playwright pruefte nur lokale Browser-Viewports.
- Operator-QR bleibt bewusst nur fuer vertrauenswuerdige lokale Geraete gedacht; kein
  Mehr-Operator-Konfliktmodell implementiert.
- KI-Provider OpenAI/Claude/Custom-HTTP sind nicht implementiert und bleiben default-aus.
- Es wurden keine echten `local-input/**/*.local.json`-Daten gelesen, importiert oder committet.
- Schweizer System bleibt kein vollstaendiges FIDE-Dutch; >20 Spieler nutzen dokumentierten
  Greedy-Fallback.

## Naechster sinnvoller Schritt

Feature-Scheibe 4: echter Vor-Ort-Test mit Handy/Beamer/WLAN, Offline-/Fallback-Validierung,
Mehr-Operator-Konzept und weitere lokale Hilfe-Themen. Prompt steht in `docs/NEXT_PROMPTS.md`.
