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
- Optional vorab (eigenes isoliertes Backend, hängesicher): `pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1` → `0 FEHLER`.
- Turnierpaket einmal öffnen: Dashboard → Druck / Backup → Paket HTML drucken / Paket JSON.
- QR-Vorabtest am Handy (Laptop-IP, gleiches WLAN) — Runbook §9.

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
- Vor Runde 1: Format und geplante Runden prüfen. Nach 5 geplanten Runden keine 6. Runde.
- Teilnehmer manuell, CSV oder Preset. Bei Preset zuerst:
  `pwsh -File .\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -DryRun`
  und Report pruefen; Warnungen nur bewusst mit `-AllowWarnings`.
- Turnier-Id notieren.
- Pro Runde: Vorschau öffnen, jeden Spieler höchstens einmal prüfen, bei ungerader Zahl genau ein Bye.
- Rematch/Severity `kritisch`: nicht blind übernehmen. Manuell korrigieren, Notiz setzen.
- Runde erzeugen, HTML-Rundenblatt drucken/aushängen, Ergebnisse eingeben.
- Tabelle prüfen, Backup ziehen.
- Turnierpaket HTML/JSON bei Bedarf aus Dashboard → Druck / Backup erzeugen
  (enthält Teilnehmerliste, aktuelle Runde, Ergebnisbogen, Tabelle, Backup-/Audit-Hinweise).
- **Nach jeder Runde Audit sichern:** Audit-Journal-Karte → „Audit-Bundle (JSONL)" oder
  `pwsh -File .\scripts\Export-TournamentAudit.ps1`. Macht jede Auslosung/Korrektur nachvollziehbar.
- Late Entry: Swiss ab nächster Runde ok; Round-Robin nach Start blockiert.
- Grenzen: kein vollständiges FIDE-Dutch; >20 Spieler = Greedy-Fallback besonders prüfen.
- QR/Handy: URL darf nicht `localhost` enthalten; bei Firewall/Netzproblem am Laptop würfeln.
  Dashboard-Übersicht zeigt zusätzlich eine lokale Operator-Preview-URL/QR für den Hotspot-Test.

## Backup/Fallback

Backup:
```powershell
$tournamentId=Read-Host "Turnier-Id"; $round=Read-Host "Runde/final"; Invoke-RestMethod "http://localhost:5088/api/tournaments/$tournamentId/export/json" | ConvertTo-Json -Depth 12 | Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_$round.json"
```

- Dashboard hängt: Print-/Export-Links aus Runbook direkt im Browser öffnen.
- App fällt aus: letztes Rundenblatt und letzte Tabelle auf Papier weiterführen.
- Nach dem Turnier Papierbogen nacherfassen.
- Während laufender Runde keine Experimente: erst Papierstand sichern, dann neu starten/restore.
