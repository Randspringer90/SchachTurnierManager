# Lokaler Turnier-Preset-Import

Private Turnierdateien liegen unter `local-input/` und werden nicht versioniert.

## Dry-run

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -DryRun
```

## Import

Backend muss laufen. Danach:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -CreateTournament
```

Das Skript erstellt ein Turnier und importiert die Teilnehmer ueber den vorhandenen CSV-Import-Endpunkt.
