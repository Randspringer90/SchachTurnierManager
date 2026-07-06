# RUN-01 – Vollständiger Audit (keine Features)

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Verlässliches Bild des Ist-Zustands, ohne irgendetwas zu ändern (außer Doku).

## Aufgaben
- `AGENTS.md`, `PLANS.md`, `README.md`, `CHANGELOG.md`, `docs/planning/*`, `docs/ai/*`
  und `.agents/skills/*` lesen.
- Lokalen Stand gegen `origin/main` prüfen (`git fetch`, ahead/behind); falls der
  Zweitcheckout `D:\Schach\SchachTurnierManager` existiert, Commit-Stände vergleichen.
- Release-Gate (`-SkipPack`), `scripts/Smoke-OperatorWorkflow.ps1` und
  `scripts/Test-RepositoryOpenSourceSafety.ps1` ausführen.
- Offene TODOs/FIXMEs, bekannte Grenzen und rote/fehlende Tests auflisten.

## Nicht in diesem Lauf
- Keine Code-Änderungen, keine neuen Features, keine Refactorings.

## Ergebnis
Bericht `docs/ai/reports/<datum>-audit.md`: Ist-Zustand, Abweichungen, Risiken,
empfohlene Reihenfolge der nächsten RUNs.
