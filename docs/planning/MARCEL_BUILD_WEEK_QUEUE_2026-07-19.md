# Build Week Contributor Queue – 2026-07-19

Stand: 2026-07-18  ·  Koordination: Owner  ·  Ziel-Bearbeiter: `friend`

## Verbindliche Basis und Freeze

`UX_FREEZE_SHA=8fbf021ef52c41392f047e76494d3b1f671ba48c`

Dieser SHA reserviert und stabilisiert die zentrale WebApp-Shell für den Build-Week-Demo-
Pfad. Ein Prompt ist nur auf seinem genannten Base-SHA gültig. Bei Drift, geänderten
Abhängigkeiten oder einem inzwischen belegten WIP-Slot darf nicht begonnen werden; der Owner
muss einen neuen SHA-gebundenen Prompt erzeugen.

Während des Submission-Freeze sind `src/SchachTurnierManager.WebApp/src/main.tsx`,
`src/SchachTurnierManager.WebApp/src/styles.css` und die Kerntexte unter
`src/SchachTurnierManager.WebApp/src/i18n/**` für parallele Änderungen reserviert. Nur das
explizit freigegebene Accessibility-Paket darf diese Pfade nach erneuter Owner-Freigabe
berühren.

## WIP-Regel

- Maximal zwei Pakete gleichzeitig `In Progress`.
- Maximal drei Pakete `Ready`.
- Aktuell `In Progress`: keines aus dieser Queue.
- Aktuell `Ready`: STM-SEC-006, STM-UX-009, STM-UX-010.
- Ein Ready-Prompt ist keine Merge-Freigabe. Feature-Branch und PR nach `development` bleiben
  Pflicht; der Contributor merged nicht selbst.
- Planning-only-Prompts dürfen nicht ausgeführt werden. Sie sind vorbereitete, SHA-gebundene
  Scopes und brauchen ein neues Startsignal des Owners.

## Priorisierte Queue

| Reihenfolge | Paket | Queue-Status | Startbedingung | Wettbewerbsauswirkung |
|---:|---|---|---|---|
| 1 | STM-SEC-006 CSV-Formel-Injection | Ready | Freier WIP-Slot, Base-SHA unverändert | Schützt Jury- und Vereins-Exporte vor Tabellenkalkulationsformeln. |
| 2 | STM-UX-009 Benutzerhandbuch DE/EN | Ready | Freier WIP-Slot, Doku-Freeze beachten | Verkürzt den Jury-Testpfad und den Einstieg am Turniertag. |
| 3 | STM-UX-010 Geräte-Testmatrix | Ready | Freier WIP-Slot, keine neue Dependency | Macht Breakpoint- und Gerätetest reproduzierbar. |
| 4 | STM-UX-011 Accessibility-Polish | Backlog / Planning only | Einer der drei Ready-Slots frei; erneuter UX-Scope-Check | Verbessert Fokus, Tastatur, Labels und mobile Bedienbarkeit. |
| 5 | STM-REL-003 Frischinstallation | Backlog / Owner-Zuweisung | Exakter finaler Candidate-SHA und Testrechner verfügbar | Liefert reale Installations-Evidence; kein Code-/Gate-Scope. |
| 6 | STM-UX-005 Turnierassistent-Polish | Backlog / Planning only | Nach Submission-Freeze und erneuter UX-Entscheidung | Ersatz für STM-FACH-012, das im UX-Freeze bereits umgesetzt ist. |
| 7 | STM-MOB-003 Mobile Paarung/Tabelle | Blocked / Planning only | PR #49 gemergt, UX-Freeze bestätigt, neuer Base-SHA | Verbessert den Companion-Lesepfad ohne Backendlogik. |
| 8 | STM-MOB-004 Mobile Ergebniseingabe | Blocked / Planning only | STM-MOB-003 gemergt und neuer Base-SHA | Bestätigung, Undo und Audit für mobile Schreibaktionen. |
| 9 | STM-FACH-003 Schweizer Felder 21–200 | Post-freeze / Planning only | Nach Submission-Freeze; separates Regelreview | Skalierung ohne Absenkung fachlicher Korrektheit. |
| 10 | STM-IE-004 FIDE-Namenssuche | Post-freeze / Planning only | Owner-Netzwerkentscheidung, API-Prüfung, neuer Base-SHA | Roadmap; bewusst nicht im Submission Candidate. |

## Prompt-Inventar

Die vollständigen Prompts liegen unter
`docs/ai/prompts/marcel-build-week-2026-07-19/`. Sie wurden offline mit dem
vertrauenswürdigen Generator `scripts/New-ContributorTaskPrompt.ps1` erzeugt. Externe Issue-
Texte wurden nicht als Instruktionsquelle geladen.

| Paket | Prompt | Freigabeart |
|---|---|---|
| STM-SEC-006 | `codex-prompt-STM-SEC-006.md` | Ready |
| STM-UX-009 | `codex-prompt-STM-UX-009.md` | Ready |
| STM-UX-010 | `codex-prompt-STM-UX-010.md` | Ready |
| STM-UX-011 | `codex-prompt-STM-UX-011.md` | Planning only |
| STM-REL-003 | `codex-prompt-STM-REL-003.md` | Planning only; Owner-Zuweisung offen |
| STM-UX-005 | `codex-prompt-STM-UX-005.md` | Planning only |
| STM-MOB-003 | `codex-prompt-STM-MOB-003.md` | Planning only |
| STM-MOB-004 | `codex-prompt-STM-MOB-004.md` | Planning only |
| STM-FACH-003 | `codex-prompt-STM-FACH-003.md` | Planning only |
| STM-IE-004 | `codex-prompt-STM-IE-004.md` | Planning only |

## Sicherheits- und Integrationsregeln

- Kein direkter Push auf `development` oder `main`, kein eigener Merge, kein Force-Push.
- Keine Änderungen an Security-Gates, Workflows, Agentenregeln, Routing, Secrets oder
  Signaturmaterial.
- Keine APK, Setup-EXE, Archive, Datenbanken oder realen Spielerdaten committen.
- Keine parallelen Pakete mit überlappenden Dateien starten.
- Neue PRs werden zunächst nur inventarisiert und SHA-gebunden statisch geprüft. Eine
  Ausführung oder Übernahme folgt erst nach separater Freigabe.
- Nach Submission-Freeze werden nur P0, reproduzierbare P1, Doku-Korrekturen, Evidence und
  Packaging-Fixes in den Candidate aufgenommen.
