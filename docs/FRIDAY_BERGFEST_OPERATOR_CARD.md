# Friday Bergfest Operator Card

Ein-Seiten-Karte für den Einsatz am Freitag. Details stehen im Runbook:
`docs/BERGFEST_MVP_RUNBOOK.md`.

## 09:30 Startcheck

1. Laptop ans Netzteil, Browser und PowerShell öffnen.
2. Projekt öffnen:
   ```powershell
   Set-Location "D:\Schach\SchachTurnierManager"
   ```
3. Backup-Ordner prüfen:
   ```powershell
   New-Item -ItemType Directory -Force "D:\Schach\Backups" | Out-Null
   ```
4. Backend starten, Healthcheck öffnen, Dashboard starten.
5. Ein leeres Blatt Papier für Notfall-Paarungen und Ergebnisliste bereitlegen.

## Start

Backend:
```powershell
Set-Location "D:\Schach\SchachTurnierManager"
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:DOTNET_ENVIRONMENT = "Development"
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Dashboard:
```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"
npm run dev
```

Links:
- Health: http://localhost:5088/api/health
- Dashboard: http://localhost:5173

## Turnier anlegen

- Name: `Bergfest Freestyle-Würfelschach 2026`
- Format: Swiss / Schweizer System
- Geplante Runden: 5
- Teilnehmer manuell erfassen oder per CSV importieren.
- Turnier-Id aus Dashboard/URL notieren.

## Pro Runde

1. Vorschau nächste Runde öffnen.
2. Pairings prüfen: jeder Spieler höchstens einmal, bei ungerader Zahl genau ein Bye.
3. Bei Rematch-Warnung oder Severity `kritisch`: nicht blind übernehmen. Paarung manuell korrigieren und Notiz setzen.
4. Runde erzeugen.
5. Rundenblatt HTML drucken/aushängen.
6. Ergebnisse eintragen. Korrektur: Ergebnis am selben Brett erneut setzen.
7. Tabelle prüfen und Backup/Snapshot ziehen.

## Export und Backup

Tabelle/Pairings im Dashboard exportieren. Direkte Links stehen im Runbook.

Backup per PowerShell:
```powershell
$tournamentId = Read-Host "Turnier-Id"
$round = Read-Host "Runde oder final"
Invoke-RestMethod "http://localhost:5088/api/tournaments/$tournamentId/export/json" |
  ConvertTo-Json -Depth 12 |
  Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_$round.json"
```

## Fallback

- Backend hängt: Strg+C im Backend-Fenster, Backend neu starten.
- Dashboard hängt: direkte Export-/Print-Links aus dem Runbook nutzen.
- App fällt aus: letztes Rundenblatt und letzte Tabelle auf Papier weiterführen.
- Nach dem Turnier Ergebnisse aus Papierbogen nacherfassen.

