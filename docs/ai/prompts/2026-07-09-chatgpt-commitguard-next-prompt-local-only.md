# Prompt 2026-07-09 – ChatGPT: CommitGuard NEXT_PROMPT lokal-only

Auftrag: Nach erfolgreichem 0.42.6-Gate und RUN-05-Readiness blockierte `Commit-If-Green.ps1`, weil ein bereits lokal vorhandenes `NEXT_PROMPT.md` automatisch gestaged wurde und interne Projektblocker enthaelt.

Ziel:
- `NEXT_PROMPT.md` als lokale Handoff-/Registry-Datei aus CommitGuard und Git heraushalten.
- Safety-Diagnose verbessern, damit Treffer Datei und hinzugefuegte Zeile zeigen.
- Keine fachliche Turnierlogik aendern.
- Logging/PLANS/CHANGELOG fortschreiben.
