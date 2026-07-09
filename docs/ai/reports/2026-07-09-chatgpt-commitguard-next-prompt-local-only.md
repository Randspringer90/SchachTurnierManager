# Report 2026-07-09 – ChatGPT: CommitGuard NEXT_PROMPT lokal-only

## Ergebnis

Der fehlgeschlagene Commit wurde als lokaler Handoff-Stage-Konflikt eingegrenzt: `NEXT_PROMPT.md` stammt aus einer externen Projekt-Registry, ist kein Produktartefakt und kann lokale Pfade oder interne Blocker enthalten.

## Aenderungen

- `.gitignore`: `NEXT_PROMPT.md` als lokale Datei ignoriert.
- `scripts/Commit-If-Green.ps1`: lokal-only Pfade werden nicht automatisch gestaged.
- `scripts/Test-GitCommitSafety.ps1`: `NEXT_PROMPT.md` ist als verbotener Commit-Pfad markiert; staged Content meldet kuenftig Datei und hinzugefuegte Zeile.
- Version: 0.43.0 -> 0.43.1.

## Verifikation

Vom Anwender auszufuehren: erst `git reset` zum Entstagen des fehlgeschlagenen Commit-Versuchs, dann ReleaseGate/CommitGuard erneut ueber das ruhige Run-Log-Verfahren.

## Naechster Schritt

Nach erfolgreichem Commit der Basis mit RUN-05 fortfahren: entweder Inno Setup lokal verfuegbar machen und echten Installer bauen oder RUN-03 Portable-ZIP-Frischordner-Test ausfuehren.
