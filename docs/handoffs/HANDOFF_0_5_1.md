# Handoff 0.5.1

## Zweck

Stabilisierung von v0.5.0. Der lokale Build schlug fehl, weil `RoundWorkflowTests.cs` das xUnit-Namespace nicht importierte. Zusätzlich liefen die Checkpoint-Skripte trotz fehlschlagender nativer Befehle weiter.

## Änderungen

- `using Xunit;` in `tests/SchachTurnierManager.Application.Tests/RoundWorkflowTests.cs` ergänzt.
- `scripts/After-Apply-V0.5.ps1` robust gemacht.
- `scripts/After-Apply-V0.5.1.ps1` ergänzt.
- `scripts/Commit-Checkpoint.ps1` robust gemacht: Build/Test/Frontend-Fehler stoppen den Commit.
- Version auf 0.5.1 erhöht.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.5.1.ps1"
```

Erwartung: `dotnet build`, `dotnet test` und `npm run build` erfolgreich.
