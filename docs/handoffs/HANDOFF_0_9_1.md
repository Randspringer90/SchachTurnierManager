# Handoff 0.9.1 - Stabilisierung Turniereinstellungen

## Zweck

Fix-Forward für v0.9.0: Stellt sicher, dass `TournamentService.UpdateSettings(...)` in der Application-Schicht vorhanden ist und die neuen Settings-Tests kompilieren.

## Enthalten

- `TournamentService.UpdateSettings(...)` inklusive Normalisierung der Turniereinstellungen.
- Nachkontrollskript `scripts/After-Apply-V0.9.1.ps1`.
- Versionsstand 0.9.1.

## Prüfung

Nach dem Einspielen ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.9.1.ps1"
```

Danach nur bei grünem Build/Test/Frontend-Build committen.
