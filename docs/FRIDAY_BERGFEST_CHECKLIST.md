# Friday Bergfest Checklist

Kompakte Abhakliste für Freitag. Details: `docs/BERGFEST_MVP_RUNBOOK.md`.
Kurzkarte: `docs/FRIDAY_BERGFEST_OPERATOR_CARD.md`.

## 09:30 Startcheck

- [ ] Laptop am Netzteil, Browser/PowerShell offen.
- [ ] Projekt geöffnet: `D:\Schach\SchachTurnierManager`.
- [ ] Backup-Ordner vorhanden: `D:\Schach\Backups`.
- [ ] Backend gestartet, Healthcheck zeigt `status`.
- [ ] Dashboard geöffnet: http://localhost:5173.
- [ ] Papier-Fallback bereit: leeres Paarungsblatt und Ergebnisliste.
- [ ] Druckweg geprüft: HTML-Rundenblatt kann geöffnet/gedruckt werden.

## Turnier anlegen

- [ ] Turniername: `Bergfest Freestyle-Würfelschach 2026`.
- [ ] Format: Swiss / Schweizer System.
- [ ] Geplante Runden: 5.
- [ ] Teilnehmer erfasst oder CSV importiert.
- [ ] Teilnehmerzahl notiert: ______.
- [ ] Turnier-Id notiert: ______________________________.

## Pro Runde

- [ ] Vorschau nächste Runde geöffnet.
- [ ] Pairings geprüft: jeder Spieler höchstens einmal.
- [ ] Ungerade Teilnehmerzahl: genau ein Bye, Bye-Spieler notiert.
- [ ] Rematch-/kritisch-Warnung geprüft.
- [ ] Bei Rematch-Warnung: manuelle Paarung korrigiert und Notiz gesetzt.
- [ ] Runde erzeugt.
- [ ] Rundenblatt HTML gedruckt/ausgehängt.
- [ ] Ergebnisse eingetragen.
- [ ] Korrekturen geprüft: falsches Ergebnis am selben Brett erneut gesetzt.
- [ ] Tabelle geprüft.
- [ ] Backup gezogen: `bergfest_<runde>.json`.

## Turnierende

- [ ] Alle Ergebnisse der 5. Runde eingetragen.
- [ ] Finale Tabelle als CSV exportiert.
- [ ] Finale HTML-Druckansicht geöffnet/gedruckt.
- [ ] Abschluss-Backup gezogen: `bergfest_final.json`.
- [ ] Papiernotizen gegen App-Tabelle geprüft.

## Wichtige Befehle

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

Backend stoppen:
```powershell
Get-NetTCPConnection -LocalPort 5088 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Dashboard stoppen:
```powershell
Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Backup:
```powershell
$tournamentId = Read-Host "Turnier-Id"
$round = Read-Host "Runde oder final"
Invoke-RestMethod "http://localhost:5088/api/tournaments/$tournamentId/export/json" |
  ConvertTo-Json -Depth 12 |
  Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_$round.json"
```

## Links

- Health: http://localhost:5088/api/health
- Dashboard: http://localhost:5173
- Tabelle CSV: `http://localhost:5088/api/tournaments/<Turnier-Id>/standings/export.csv`
- Paarungen CSV: `http://localhost:5088/api/tournaments/<Turnier-Id>/pairings/export.csv`
- Turnierdruck: `http://localhost:5088/api/tournaments/<Turnier-Id>/print/html`
- Rundenblatt: `http://localhost:5088/api/tournaments/<Turnier-Id>/rounds/<Runde>/print/html`

## Fallback

1. Backend hängt: Strg+C, Backend neu starten. Autosave liegt in SQLite.
2. Dashboard lädt nicht: Export-/Print-Links direkt im Browser öffnen.
3. App fällt aus: mit letztem gedrucktem Rundenblatt und Tabelle auf Papier weiterspielen.
4. Nach dem Turnier aus Papierbogen nacherfassen.
5. Daten weg: letztes JSON-Backup importieren (`overwriteExisting=true`).

Grundregel: Das gedruckte Rundenblatt und der Papier-Ergebnisbogen sind im Notfall die Quelle der Wahrheit.
