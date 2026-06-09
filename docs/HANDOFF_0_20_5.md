# Handoff 0.20.5

## Ziel

Fix-Forward für den roten v0.20.2/v0.20.3/v0.20.4-Zwischenstand.

## Inhalt

- Version auf 0.20.5.
- CSV-Export-Test `TournamentExportFormatterTests.ExportStandingsCsv_ContainsStableHeaderAndPlayerRows` wird auf den tatsächlich exportierten erweiterten Tabellenkopf angepasst.
- Lokale, fehlgeschlagene Zwischenstandsartefakte aus v0.20.3/v0.20.4 werden entfernt, falls vorhanden.
- Vollständige Nachkontrolle mit hartem Abbruch bei Fehlern:
  - `dotnet restore`
  - `dotnet build --no-restore`
  - `dotnet test --no-build`
  - `npm install`
  - `npm run build`
  - `scripts/Pack-Portable.ps1`

## Erwarteter Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Fix extended tiebreak export header test"; git push
```

Nur committen, wenn das Skript vollständig grün durchläuft.
