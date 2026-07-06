# PROMPT_BASE – Arbeitsregeln für alle Roadmap-Läufe

Diese Regeln gelten für **jeden** RUN-Prompt in diesem Ordner. Der RUN-Prompt sagt *was*,
diese Datei sagt *wie*. Sie gilt für Codex, Claude Code und vergleichbare Agenten.

## Rolle

Arbeite wie ein vorsichtiger Senior-Entwickler/Release-Engineer, nicht wie ein kreativer
Umbauer: erst verstehen, dann kleine überprüfbare Schritte. Qualität vor Geschwindigkeit.

## Pflicht-Reihenfolge je Lauf

1. **Regeln lesen:** `AGENTS.md` (Repo-Root, verbindlich), relevanter Skill unter
   `.agents/skills/` (vor Commit-Arbeiten immer `repository-security.md`).
2. **Ist-Zustand:** `git status --short --branch`, `git remote -v`, `git pull` (Repo wird
   an mehreren Stellen parallel bearbeitet – immer zuerst synchronisieren; bei
   Netzproblemen dokumentieren und rein lokal weiterarbeiten, kein Push).
   `PLANS.md`, `CHANGELOG.md`, letzte Einträge in `docs/ai/PROMPTS.md` lesen.
3. **Grün-Basis:** `pwsh -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack` muss vor
   Beginn grün sein. Falls nicht: erst das reparieren, nichts Neues anfangen.
4. **Nur das Arbeitspaket des RUN-Prompts** umsetzen. Kein Scope-Creep, keine
   Massenformatierung, keine neuen Dependencies ohne zwingenden Grund.
5. **Verifizieren:** Release-Gate erneut, bei Bedarf `scripts/Smoke-OperatorWorkflow.ps1`.
6. **Dokumentieren:** `PLANS.md`/`CHANGELOG.md` fortschreiben; Lauf in
   `docs/ai/PROMPTS.md` eintragen; Abschlussbericht nach `docs/ai/reports/`
   (Datum, geänderte Dateien, Tests, Risiken, nächster Schritt).
7. **Committen:** nur über `pwsh -File .\scripts\Commit-If-Green.ps1 -Message "..."`.
   Kein `git add .`/`--all`. **Kein Push und kein Release ohne ausdrückliche Freigabe.**

## Harte Verbote

- Keine Secrets, Tokens, `.env`, `.npmrc`, Logs, Dumps, ZIPs, Datenbanken, `output/`,
  `tmp/` committen.
- Kein Force-Push, keine Cloud-/Kostenaktionen, keine Uploads.
- Bestehende Tests nie löschen oder abschwächen, um „grün" zu werden.
- Dirty/staged/untracked Stände anderer Sessions nie verwerfen – als eigene
  Review-Aufgabe behandeln.

## Abnahme (Definition of Done, jeder Lauf)

- Release-Gate (`-SkipPack`) grün, alle Tests bestehen.
- Doku und Lauf-Log aktualisiert.
- Commit lokal erstellt (über Commit-If-Green), Push nur nach Freigabe.
- Abschlussbericht mit: geänderte Dateien, Tests/Ergebnis, Risiken, nächster Schritt.
