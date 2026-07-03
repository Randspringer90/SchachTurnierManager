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
- [ ] Operator-Smoke grün: `pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1` → `0 FEHLER`.
- [ ] QR-Vorabtest am Handy gemacht (Laptop-IP eingetragen, gleiches WLAN) — siehe Runbook §9.

## Turnier anlegen

- [ ] Turniername: `Bergfest Freestyle-Würfelschach 2026`.
- [ ] Format: Swiss / Schweizer System.
- [ ] Geplante Runden: 5.
- [ ] Format und Rundenzahl gegen Ausschreibung geprüft; keine 6. Runde nach 5 geplanten Runden.
- [ ] Bei Preset-Import: Dry-run ausgefuehrt und Report unter `output\reports\` geprueft.
- [ ] Teilnehmer erfasst, CSV importiert oder Preset-Import bewusst mit/ohne `-AllowWarnings` ausgefuehrt.
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
- [ ] Audit-Bundle exportiert: `pwsh -File .\scripts\Export-TournamentAudit.ps1 -TournamentId <Turnier-Id> -Format jsonl`.

## Late Entry / Grenzen

- [ ] Swiss: Nachmeldungen nur ab nächster noch nicht ausgeloster Runde; Altrunden bleiben unverändert.
- [ ] Round-Robin: Nach Start kein Late Entry/Rückzug ohne Reset oder Neuanlage.
- [ ] Swiss-Grenze bekannt: kein vollständiges FIDE-Dutch; >20 aktive Spieler = Greedy-Fallback besonders prüfen.

## Turnierende

- [ ] Alle Ergebnisse der 5. Runde eingetragen.
- [ ] Finale Tabelle als CSV exportiert.
- [ ] Finale HTML-Druckansicht geöffnet/gedruckt.
- [ ] Abschluss-Backup gezogen: `bergfest_final.json`.
- [ ] Finales Audit-Bundle exportiert.
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

Preset-Dry-run:
```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh -File .\scripts\Import-TournamentPreset.ps1 -PresetPath ".\local-input\bergfest-2026\bergfest-2026-starter.local.json" -DryRun
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
- Audit JSONL: `http://localhost:5088/api/tournaments/<Turnier-Id>/audit-journal/export.jsonl`

## Fallback

1. Backend hängt: Strg+C, Backend neu starten. Autosave liegt in SQLite.
2. Dashboard lädt nicht: Export-/Print-Links direkt im Browser öffnen.
3. App fällt aus: mit letztem gedrucktem Rundenblatt und Tabelle auf Papier weiterspielen.
4. Nach dem Turnier aus Papierbogen nacherfassen.
5. Daten weg: letztes JSON-Backup importieren (`overwriteExisting=true`) nur nach bewusster Auswahl des Backups.
6. Während laufender Runde keine Experimente: Runde auf Papier beenden, dann App reparieren/nacherfassen.

Grundregel: Das gedruckte Rundenblatt und der Papier-Ergebnisbogen sind im Notfall die Quelle der Wahrheit.
