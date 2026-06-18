# FRIDAY_BERGFEST_CHECKLIST.md

Kompakte Abhakliste für den Turniertag. Details: `docs/BERGFEST_MVP_RUNBOOK.md`.

## Vor dem Turnier (zu Hause / am Vorabend)
- [ ] Generalprobe gelaufen: `pwsh -File .\scripts\New-DemoTournament.ps1 -PlayerCount 10 -PlayOut`
- [ ] Tabelle + Rundenblatt einmal probegedruckt (CSV + HTML)
- [ ] Backup-Ordner existiert: `D:\Schach\Backups\`
- [ ] Backup-Export einmal getestet
- [ ] Laptop geladen / Netzteil dabei, Drucker erreichbar

## Aufbau vor Ort (10–15 Min vor Start)
- [ ] Backend gestartet → http://localhost:5088/api/health zeigt `status`
- [ ] Dashboard offen → http://localhost:5173
- [ ] Turnier angelegt: Name `Bergfest Freestyle-Würfelschach <Datum>`, Swiss, 5 Runden
- [ ] Alle Teilnehmer erfasst, Anzahl notiert: ______
- [ ] Turnier-Id notiert (aus URL/Dashboard): ______________________

## Pro Runde (5×)
- [ ] „Vorschau nächste Runde“ angesehen
- [ ] Qualität geprüft — bei **kritisch/Rematch**: Brett per manueller Paarung korrigiert
- [ ] Runde ausgelost
- [ ] Rundenblatt gedruckt/ausgehängt
- [ ] Alle Ergebnisse eingegeben (Korrektur = Ergebnis erneut setzen)
- [ ] Backup gezogen → `bergfest_runde_<N>.json`

## Turnierende
- [ ] Letzte Ergebnisse eingegeben
- [ ] Finale Tabelle als CSV + HTML exportiert/gedruckt
- [ ] Abschluss-Backup → `bergfest_final.json`

---

## Wichtige Befehle (Copy & Paste)

Backend starten:
```powershell
Set-Location "D:\Schach\SchachTurnierManager"
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Dashboard starten:
```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"
npm run dev
```

Backup ziehen (Platzhalter `{id}` und `<N>` ersetzen):
```powershell
Invoke-RestMethod "http://localhost:5088/api/tournaments/{id}/export/json" |
  ConvertTo-Json -Depth 12 |
  Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_runde_<N>.json"
```

## Wichtige Links (`{id}` ersetzen)
- Health: http://localhost:5088/api/health
- Dashboard: http://localhost:5173
- Tabelle CSV: http://localhost:5088/api/tournaments/{id}/standings/export.csv
- Paarungen CSV: http://localhost:5088/api/tournaments/{id}/pairings/export.csv
- Druckansicht: http://localhost:5088/api/tournaments/{id}/print/html
- Rundenblatt R3: http://localhost:5088/api/tournaments/{id}/rounds/3/print/html

---

## Fallback (wenn etwas klemmt)
1. **Backend hängt** → im Backend-Fenster Strg+C, dann Backend neu starten.
   Daten sind in SQLite gesichert (Autosave nach jeder Aktion).
2. **Dashboard lädt nicht** → Export-/Druck-Links oben direkt im Browser nutzen;
   Ergebnisse notfalls per API erfassen (siehe Runbook).
3. **Rechner/App fällt ganz aus** → mit dem letzten **gedruckten Rundenblatt** und der
   letzten gedruckten **Tabelle** auf **Papier** weiterspielen. Ergebnisse später
   nacherfassen; letztes `bergfest_runde_<N>.json` ist der Wiederherstellungspunkt.
4. **Datenbank kaputt/Turnier weg** → letztes JSON-Backup via
   `POST /api/tournaments/import` (`overwriteExisting=true`) zurückspielen.

> Grundregel: Lieber eine Runde mehr auf Papier dokumentieren als Ergebnisse verlieren.
> Das gedruckte Rundenblatt ist immer die Quelle der Wahrheit am Brett.
