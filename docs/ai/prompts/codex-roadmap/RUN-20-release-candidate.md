# RUN-20 – Finaler Release Candidate (zuletzt ausführen)

Vorab `PROMPT_BASE.md` und `.agents/skills/repository-security.md` lesen.

## Voraussetzung
Alle für das Release vorgesehenen RUNs abgeschlossen; keine offenen roten Punkte.

## Ablauf
1. **Frischer Klon** in ein neues Verzeichnis (nicht im bestehenden Checkout arbeiten).
2. Vollständiges Release-Gate (ohne `-SkipPack`).
3. `scripts/Smoke-OperatorWorkflow.ps1` (Operator-Smoke) grün.
4. Installer bauen und Installations-/Deinstallations-Test (RUN-05-Checkliste).
5. Portable-ZIP-Test aus frischem Ordner (RUN-03-Checkliste).
6. Open-Source-Safety: Snapshot + `Test-RepositoryOpenSourceSafety.ps1`; Report
   vollständig lesen, nicht nur Exit-Code.
7. Versionsnummern konsistent (package.json, Health-Endpoint, Installer, CHANGELOG).
8. Abschlussbericht mit allen Ergebnissen nach `docs/ai/reports/`.

## Harte Regel
**Manuelle Freigabe durch den Nutzer vor jeder Veröffentlichung** (Tag, Release,
öffentlicher Snapshot, Website-Upload). Dieser Lauf bereitet nur vor und beweist Reife.
