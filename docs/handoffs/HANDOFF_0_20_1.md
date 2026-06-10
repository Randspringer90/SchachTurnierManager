# Handoff 0.20.1 - Erweiterte Wertungen

## Inhalt

Dieser Fix-Forward-Patch ersetzt den abgebrochenen v0.20.0-Skriptstand und erweitert die Swiss-Chess-Paritätsroadmap um konkrete Wertungsfunktionen:

- Buchholz Cut-2
- Median-Buchholz
- Progressivwertung
- Koya-Wertung
- Schwarzsiege

Die neuen Werte werden berechnet, als Sortierkriterien angeboten, in der Live-Tabelle angezeigt und in CSV-/HTML-Exporten ausgegeben.

## Nachkontrolle

Das Skript `scripts/After-Apply-V0.20.1.ps1` führt aus:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts/Pack-Portable.ps1`

## Erwartung

Nach erfolgreicher Nachkontrolle:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add extended tiebreak calculations"; git push
```
