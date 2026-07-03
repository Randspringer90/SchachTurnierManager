# Lokaler Turnier-Preset-Import

Private Turnierdateien liegen unter `local-input/` und werden nicht versioniert.
Echte `*.local.json`-Dateien bleiben lokal; Reports/CSV-Ausgaben landen unter
`output\reports\` und werden nicht committet.

## Dry-run

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -DryRun
```

Der Dry-run erzeugt:

- eine normalisierte CSV fuer den bestehenden CSV-Importpfad,
- einen JSON-Report `output\reports\preset-import-report-*.json`,
- Zaehler fuer Rohteilnehmer, importierbare CSV-Zeilen, uebersprungene Namensdubletten,
  Rating-Fallbacks (`twzManual`, `dwz`, `eloStandard`, `missing`) und Warnungen.

Die Konsole zeigt bewusst keine komplette Teilnehmerliste. Fuer lokale Sichtpruefung:

```powershell
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -DryRun -ShowCsvPreview
```

## Import

Backend muss laufen. Vor dem echten Import immer zuerst den Dry-run-Report pruefen. Danach:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -CreateTournament
```

Das Skript erstellt ein Turnier und importiert die Teilnehmer ueber den vorhandenen
CSV-Import-Endpunkt. Vor dem Import ruft es die API-Vorschau
`/players/preview-import.csv` auf. Blocker stoppen den Import. Warnungen stoppen den Import
ebenfalls, ausser sie wurden nach Report-Pruefung bewusst freigegeben:

```powershell
.\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -ApiBaseUrl "http://localhost:5088" -CreateTournament -AllowWarnings
```

`-AllowWarnings` ist keine Automatik-Freigabe: vorher Report und Warnungen pruefen, besonders
Dubletten, fehlende Ratings/TWZ und Namensnormalisierung.

## Erwartetes Preset-Minimum

```json
{
  "tournament": {
    "name": "Bergfest Freestyle-Wuerfelschach 2026",
    "rounds": 5
  },
  "participants": [
    {
      "name": "Synthetic Player 01",
      "club": "Testverein",
      "twzManual": 1800,
      "dwz": 1750,
      "eloStandard": 1700,
      "fideId": "1234567",
      "dsbId": "TH-123"
    }
  ]
}
```

Rating-Reihenfolge fuer Startliste/TWZ: `twzManual` vor `dwz` vor `eloStandard`; fehlt alles,
wird der Teilnehmer importiert, aber im Report markiert.
