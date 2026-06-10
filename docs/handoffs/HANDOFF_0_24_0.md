# Handoff 0.24.0 – Auslosungsvorschau drucken und exportieren

## Ziel

v0.24.0 erweitert die in v0.23.0 sichtbare Auslosungsvorschau um turnierpraktische Ausgabewege:

- CSV-Export der nächsten Auslosungsvorschau
- HTML-Druckansicht der nächsten Auslosungsvorschau
- zusätzliche Dashboard-Aktionen in der Vorschaukarte
- deutliche Warnbox bei kritischer Paarungsqualität oder nicht speicherbarer Vorschau

## Fachlicher Nutzen

Turnierleiter können vor dem echten Auslosen eine Vorschau für Aushang, Kontrolle oder Abstimmung öffnen/exportieren, ohne die Runde zu speichern. Das passt zum Ziel: erst prüfen, dann bewusst auslosen.

## Neue API-Endpunkte

- `GET /api/tournaments/{id}/pairings/preview-next-round/export.csv`
- `GET /api/tournaments/{id}/pairings/preview-next-round/print/html`

Beide Endpunkte erzeugen die Vorschau nur temporär. Es wird keine Runde gespeichert.

## Geänderte Dateien

- `src/SchachTurnierManager.WebApi/Program.cs`
- `src/SchachTurnierManager.Application/TournamentService.cs`
- `src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs`
- `tests/SchachTurnierManager.Domain.Tests/TournamentExportFormatterTests.cs`
- `src/SchachTurnierManager.WebApp/src/main.tsx`
- `src/SchachTurnierManager.WebApp/src/styles.css`
- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`
- `CHANGELOG.md`
- `docs/HANDOFF_0_24_0.md`
- `scripts/After-Apply-V0.24.ps1`

## Nachkontrolle

Das Apply-Skript führt aus:

- `dotnet restore`
- `dotnet build`
- `dotnet test`
- `npm install`
- `npm run build`
- `scripts\Pack-Portable.ps1`
- `git status --short`

## Erwarteter Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add next round preview print export"; git push
```
