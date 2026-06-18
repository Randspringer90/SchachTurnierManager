# Friday Bergfest Operator Card

Ein-Seiten-Karte. Details: `docs/BERGFEST_MVP_RUNBOOK.md`.

## 09:30 Startcheck

- Netzteil, Browser, PowerShell, Drucker.
- Projekt und Backup-Ordner:
  ```powershell
  Set-Location "D:\Schach\SchachTurnierManager"; New-Item -ItemType Directory -Force "D:\Schach\Backups" | Out-Null
  ```
- Papier bereitlegen: Paarungsblatt, Ergebnisliste, Stift.
- Health muss `status` zeigen: http://localhost:5088/api/health
- Dashboard: http://localhost:5173

## Start

Backend:
```powershell
Set-Location "D:\Schach\SchachTurnierManager"; $env:ASPNETCORE_ENVIRONMENT="Development"; $env:DOTNET_ENVIRONMENT="Development"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Dashboard:
```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm run dev
```

## Stop/Restart

Backend stoppen:
```powershell
Get-NetTCPConnection -LocalPort 5088 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Dashboard stoppen:
```powershell
Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Danach Startbefehle erneut ausführen.

## Turnier/Runde

- Turnier: `Bergfest Freestyle-Würfelschach 2026`, Swiss, 5 Runden.
- Teilnehmer manuell oder CSV; Turnier-Id notieren.
- Pro Runde: Vorschau öffnen, jeden Spieler höchstens einmal prüfen, bei ungerader Zahl genau ein Bye.
- Rematch/Severity `kritisch`: nicht blind übernehmen. Manuell korrigieren, Notiz setzen.
- Runde erzeugen, HTML-Rundenblatt drucken/aushängen, Ergebnisse eingeben.
- Tabelle prüfen, Backup ziehen.

## Backup/Fallback

Backup:
```powershell
$tournamentId=Read-Host "Turnier-Id"; $round=Read-Host "Runde/final"; Invoke-RestMethod "http://localhost:5088/api/tournaments/$tournamentId/export/json" | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_$round.json"
```

- Dashboard hängt: Print-/Export-Links aus Runbook direkt im Browser öffnen.
- App fällt aus: letztes Rundenblatt und letzte Tabelle auf Papier weiterführen.
- Nach dem Turnier Papierbogen nacherfassen.
