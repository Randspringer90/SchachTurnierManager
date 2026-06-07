# Handoff 0.5.0

## Inhalt

- Manuelle Paarungskorrekturen pro Runde/Brett.
- Audit-Eintrag bei manuellen Paarungsänderungen.
- Rundensperre und Prüfstatus.
- Ergebnisänderungen werden bei gesperrten/geprüften Runden blockiert.
- Neue Regel: nächste Runde wird erst ausgelost, wenn die vorherige Runde vollständig ist.
- Frontend-Steuerelemente für Paarungskorrektur, Sperren/Entsperren und Prüfen.
- `Commit-Checkpoint.ps1` für regelmäßige grüne Checkpoint-Commits.

## Checks

Bitte lokal ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.5.ps1"
```

Danach Commit:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add manual pairing workflow and round locks"; git push
```

Alternativ künftig für grüne Checkpoints:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-Checkpoint.ps1" -Message "Checkpoint: describe change" -Push
```
