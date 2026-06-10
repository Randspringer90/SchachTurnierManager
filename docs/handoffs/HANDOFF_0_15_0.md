# Handoff 0.15.0 – CSV-Importvorschau im Dashboard

## Ziel

v0.15.0 macht die in v0.14.0 eingeführte CSV-Importvorschau im Dashboard sichtbar und nutzbar. Der Import verändert Teilnehmerdaten erst, nachdem eine aktuelle Vorschau ohne blockierende Probleme erzeugt wurde.

## Enthalten

- Dashboard-Button **Import prüfen** im CSV-Bereich.
- Vorschautabelle mit Zeile, Teilnehmer, Status, Dubletten und Hinweisen.
- Import-Button ist deaktiviert, solange keine Vorschau existiert oder blockierende Probleme vorhanden sind.
- CSV-/Optionenänderungen setzen die Vorschau zurück, damit keine veraltete Prüfung verwendet wird.
- Versionen auf `0.15.0` angehoben.
- `CHANGELOG.md` ergänzt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.15.ps1"
```

Erwartung:

- `dotnet build` grün
- `dotnet test` grün
- `npm run build` grün
- Portable-ZIP `SchachTurnierManager_Portable_0.15.0.zip`

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add CSV import preview UI"; git push
```

## Nächster sinnvoller Schritt

v0.16.0: Importvorschau weiter ausbauen mit expliziter Bestätigungslogik für Warnungen, klarerer Konfliktanzeige und optionalem Importmodus „nur unkritische Zeilen übernehmen“.
