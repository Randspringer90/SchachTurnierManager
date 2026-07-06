# RUN-18 – QA und Testdaten

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Aufgaben
- Synthetische Turnierdaten-Generatoren ausbauen (`scripts/New-DemoTournament.ps1`
  als Basis): verschiedene Feldgrößen, Kategorien, Rückzüge, kampflose Ergebnisse.
  **Keine echten privaten Daten committen.**
- Golden Tests für Pairings und Wertungen erweitern: bekannte Eingaben → exakt
  erwartete Paarungen/Tabellen, als Regressionsschutz vor RUN-12/13/14.
- UI-Smoke-Tests evaluieren (z. B. Playwright): nur wenn Mehrwert > Wartungskosten;
  Entscheidung dokumentieren. Alternativ API-Smoke ausbauen.
- Backup/Restore-Tests: Backup → Restore → Zustand identisch (inkl. Chess960-Stellungen,
  Audit-Referenzen).
- Installer-/Portable-Test auf möglichst frischem Windows-Kontext dokumentieren
  (Checkliste für manuelle Durchführung, z. B. in einer VM).
