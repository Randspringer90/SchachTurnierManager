# Handoff 0.7.1

## Ziel

Stabilisierung von v0.7.0 nach lokalem Buildfehler im Druck-/Exportpaket.

## Korrektur

- `TournamentExportFormatter` verwendet bei der Rundenprüfung jetzt `RoundDiagnostics.Warnings`.
- Die vorherige Referenz auf `RoundDiagnostics.Messages` war falsch, weil `RoundDiagnostics` nur `Warnings` und Board-Diagnosen enthält.

## Erwartete Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.7.1.ps1"
```

Danach committen:

```powershell
git status
git add .
git commit -m "Stabilize print export diagnostics"
git push
```

## Hinweis

Der v0.7.0-Commit auf `main` war rot. v0.7.1 ist der direkte Fix-Forward, kein Revert.
