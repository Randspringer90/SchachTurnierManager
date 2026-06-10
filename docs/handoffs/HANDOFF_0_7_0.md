# Handoff 0.7.0

## Ziel

Druck- und Exportpaket für die praktische Turnierleitung: Tabelle, Paarungen, Turnierbericht und Rundenblätter sollen lokal als CSV/HTML erzeugbar sein.

## Enthalten

- `TournamentExportFormatter` für CSV-/HTML-Ausgaben.
- API-Endpunkte:
  - `GET /api/tournaments/{id}/standings/export.csv`
  - `GET /api/tournaments/{id}/pairings/export.csv`
  - `GET /api/tournaments/{id}/pairings/export.csv?roundNumber=1`
  - `GET /api/tournaments/{id}/print/html`
  - `GET /api/tournaments/{id}/rounds/{roundNumber}/print/html`
- Dashboard-Buttons im Import-/Exportbereich.
- Tests für Exportformatierung.

## Lokale Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.7.ps1"
```

## Nächster Schritt

v0.8.0 sollte den portable Publish / Nicht-Entwickler-Start angehen: Backend liefert gebautes Frontend aus, Startskript startet die App und öffnet den Browser ohne separate Vite-Entwicklungsumgebung.
