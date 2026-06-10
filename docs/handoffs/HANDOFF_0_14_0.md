# Handoff 0.14.0 - CSV-Importvorschau und Dublettenprüfung

## Ziel

Dieser Patch ergänzt die technische Grundlage für eine sichere CSV-Importvorschau. Der bestehende CSV-Import kann damit vor dem Ausführen analysiert werden, ohne das Turnier zu verändern.

## Enthalten

- Neues Modell `PlayerImportPreview`
- Neuer Service `PlayerImportPreviewService`
- Neue API-Vorschau über `TournamentService.PreviewPlayersCsv(...)`
- Neuer Endpunkt `POST /api/tournaments/{id}/players/preview-import.csv`
- Tests für:
  - bestehende FIDE-Dublette,
  - doppelte FIDE-ID innerhalb der Importdatei,
  - blockiertes Ersetzen nach bereits ausgelosten Runden.
- Version auf `0.14.0`

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.14.ps1"
```

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add CSV import preview diagnostics"; git push
```

## Nächster Schritt

v0.15.0 sollte die CSV-Importvorschau sichtbar ins Dashboard integrieren:

- Button „Import prüfen“
- Vorschautabelle mit Status Ready/Warnung/Blockiert
- Dublettenhinweise je Zeile
- erst danach „Import ausführen“ aktivieren
