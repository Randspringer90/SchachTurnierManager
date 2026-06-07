# Handoff 0.5.2

## Zweck

Stabilisierung nach v0.5.1: Die xUnit2031-Warnungen in den Round-Workflow-Tests wurden entfernt, damit Checkpoint-Builds möglichst warnungsarm bleiben.

## Änderungen

- `RoundWorkflowTests.cs`: `Assert.Single(collection, predicate)` statt `Where(...).Single(...)` verwendet.
- Version auf 0.5.2 erhöht.
- `After-Apply-V0.5.2.ps1` ergänzt.

## Lokale Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.5.2.ps1"
```

## Commit-Vorschlag

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Remove xUnit warnings from round workflow tests"; git push
```
