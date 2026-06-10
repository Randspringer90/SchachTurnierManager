# Archiv: After-Apply-Skripte

Historische, versionsbezogene Nachkontroll-/Patch-Skripte (`After-Apply-V*.ps1`) aus der Patch-basierten Entwicklungsphase.

- Nicht mehr ausführen: Die Skripte beziehen sich auf den damaligen Repository-Stand und verwenden teilweise Pfade, die es so nicht mehr gibt.
- Aktuelle Abläufe: `scripts/Invoke-ReleaseGate.ps1` (Build/Test/Paket) und `scripts/Commit-If-Green.ps1` (CommitGuard); Übersicht in `docs/planning/PROJECT_ORCHESTRATION.md`.
- Der gesamte Ordner `scripts/archive/` wird beim Open-Source-Clean-Snapshot (`scripts/New-OpenSourceSnapshot.ps1`) ausgeschlossen.
