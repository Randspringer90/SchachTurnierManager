# Handoff 0.20.2 - Teststabilisierung erweiterte Wertungen

## Ziel

v0.20.1 brachte die erweiterten Swiss-Chess-nahen Tabellenwertungen in Domain, UI und Export. Die fachliche Umsetzung baute, aber ein vorhandener CSV-Export-Test erwartete noch den alten Tabellenkopf.

## Inhalt

- Versionen auf `0.20.2`.
- `TournamentExportFormatterTests.ExportStandingsCsv_ContainsStableHeaderAndPlayerRows` erwartet nun den erweiterten Tabellenkopf.
- `CHANGELOG.md` ergänzt.
- Nachkontrollskript bricht hart ab, falls ein Prüf-/Build-/Packaging-Schritt fehlschlägt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.20.2.ps1"
```

Bei grüner Nachkontrolle:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize extended tiebreak export tests"; git push
```

## Nächster sinnvoller Schritt

Nach grünem v0.20.2: Schweizer-System-Golden-Tests und Pairing-Erklärungen ausbauen, bevor weitere große Funktionspakete aufgesetzt werden.
