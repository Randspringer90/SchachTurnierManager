# Handoff 0.38.5 - Commit-Guard-Fix und Clean-Current-Baseline

## Ziel

v0.38.5 repariert den in v0.38.4 ausgelösten Selbsttreffer des Git-Sicherheitschecks und entfernt fehlgeschlagene Zwischenpatch-Dateien aus dem aktuellen Arbeitsstand.

## Wichtig

Das private Repository bleibt wegen historischer Altlasten privat. Für eine spätere öffentliche Veröffentlichung wird ein Clean Snapshot ohne alte Git-Historie erzeugt.

## Erwartete Prüfung

- scripts/Test-GitCommitSafety.ps1 läuft ohne Treffer im aktuellen Arbeitsbaum.
- Release-Gate bleibt grün.
- Der Commit enthält keine .local-*, security-audit, Paket-Backups, Build-Artefakte oder internen Registry-Referenzen.