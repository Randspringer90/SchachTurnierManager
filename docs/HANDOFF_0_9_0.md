# Handoff 0.9.0 - Turniereinstellungen und Wertungskette

## Inhalt

- Dashboard-Bereich für Turniereinstellungen ergänzt.
- Punktesystem im UI auswählbar: klassisch, 3-1-0, Norway/Armageddon.
- TWZ-Quelle im UI auswählbar.
- geplante Rundenzahl, Seniorenjahr, Heldenpokal-Mindestpartien konfigurierbar.
- Forfeit-/Bye-Policy im UI auswählbar.
- Wertungskette im UI konfigurierbar und sortierbar.
- Backend-Endpunkt `PUT /api/tournaments/{id}/settings` ergänzt.
- `StandingsCalculator` sortiert nach konfigurierter Wertungskette.
- Tests für Settings-Workflow und konfigurierbare Wertungskette ergänzt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.9.ps1"
```

## Commit-Vorschlag

```powershell
git status; git add .; git commit -m "Add configurable tournament settings and tiebreak order"; git push
```
