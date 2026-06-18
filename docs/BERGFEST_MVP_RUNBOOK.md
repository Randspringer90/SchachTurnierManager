# BERGFEST_MVP_RUNBOOK.md

Schritt-für-Schritt-Anleitung für den Turniertag (Freitag).
Alles läuft lokal. Alle Befehle in PowerShell aus `D:\Schach\SchachTurnierManager`.

Kurzfassung zum Abhaken: `docs/FRIDAY_BERGFEST_CHECKLIST.md`.
Ein-Seiten-Karte: `docs/FRIDAY_BERGFEST_OPERATOR_CARD.md`.
Hintergrund/Architektur: `docs/BERGFEST_MVP_PLAN.md`.

---

## 0. Am Abend vorher oder 09:30 Startcheck

1. Laptop ans Netzteil, Drucker/Browser prüfen.
2. Backup-Ordner anlegen:
   ```powershell
   New-Item -ItemType Directory -Force "D:\Schach\Backups" | Out-Null
   ```
3. Backend starten (Schritt 1) und Healthcheck öffnen.
4. Frontend starten (Schritt 2).
5. Papier-Fallback bereitlegen: Pairingbogen, Ergebnisliste, Stift.
6. Optionaler Dry-run:
   ```powershell
   pwsh -File .\scripts\New-DemoTournament.ps1 -Players 10 -Rounds 5 -PlayOut
   ```
   Erwartung: 5 Runden werden ausgelost und gefüllt, am Ende erscheint eine Tabelle.
7. Einmal Tabelle und Rundenblatt als CSV/HTML exportieren und drucken.
8. Backup einmal testen (Schritt 6).

Wenn die Generalprobe durchläuft, ist Freitag startklar.

---

## 1. Backend starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:DOTNET_ENVIRONMENT = "Development"
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

- API läuft auf **http://localhost:5088**.
- Healthcheck im Browser: **http://localhost:5088/api/health** → muss `status` zeigen.
- Datenbank liegt unter `%LocalAppData%\SchachTurnierManager\SchachTurnierManager.sqlite`
  und wird **nach jeder Aktion automatisch gespeichert**.

Fenster offen lassen. Strg+C beendet das Backend. Daten bleiben in SQLite erhalten.

Backend gezielt stoppen, falls das Fenster nicht reagiert:
```powershell
Get-NetTCPConnection -LocalPort 5088 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Backend danach mit dem Startbefehl oben neu starten und Healthcheck erneut öffnen.

Falls `dotnet run` wegen lokaler SDK-/Restore-Probleme nicht startet, keine Zeit verlieren:
auf Papier weiterführen oder das zuletzt geprüfte lokale Paket/Release-Exe nur dann nutzen,
wenn es vor Ort mit Healthcheck erfolgreich startet. Keine Experimente während laufender Runde.
Das alte `output\portable`-Paket aus 0.8.0 ist kein Freitag-Fallback, solange es nicht
frisch aus dem aktuellen Stand gebaut und mit Healthcheck geprüft wurde.

## 2. Frontend (Dashboard) starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"
npm run dev
```

- Dashboard: **http://localhost:5173**

Dashboard gezielt stoppen, falls das Fenster nicht reagiert:
```powershell
Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
```

Dashboard danach mit dem Startbefehl oben neu starten.

Wenn `node_modules` fehlt, einmalig:
```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"
npm install
```

## 3. Turnier anlegen

Im Dashboard ein neues Turnier anlegen:
- **Name**: `Bergfest Freestyle-Würfelschach 2026` (Modus steht so im Namen/Export).
- **Format**: Schweizer System (Swiss).
- **Geplante Runden**: 5.

(API-Weg, falls nötig: `POST /api/tournaments` mit
`{"name":"...","settings":{"format":"Swiss","plannedRounds":5}}`.)

## 4. Teilnehmer erfassen

- **Manuell**: pro Spieler Name (+ optional Verein/TWZ) im Dashboard hinzufügen.
- **CSV-Import**: vorbereitete CSV im Dashboard importieren
  (Vorschau über `preview-import.csv`, dann Import).
- Ungerade Teilnehmerzahl ist ok — die App vergibt automatisch genau **ein Bye** pro Runde.

## 5. Runden durchführen (5×)

Für jede Runde:

1. **Vorschau ansehen**: "Vorschau nächste Runde".
   - Qualitätswert/Severity prüfen.
   - Bei ungerader Teilnehmerzahl: genau ein Bye prüfen.
   - Jeder aktive Spieler darf in der Runde höchstens einmal vorkommen.
   - **Severity kritisch / Rematch**: betroffenes Brett per manueller Paarung korrigieren.
     Im Notizfeld ggf. die gewürfelte Startstellung eintragen.
2. **Auslosen**: "Nächste Runde auslosen" übernimmt die Paarungen.
3. **Rundenblatt drucken/aushängen** (Schritt 7): HTML-Rundenblatt oder Paarungs-CSV.
4. **Ergebnisse eingeben**: pro Brett 1-0 / ½-½ / 0-1 (bzw. kampflos +/- / Bye).
   - **Korrektur**: einfach das Ergebnis am selben Brett erneut setzen; es überschreibt
     und die Tabelle aktualisiert sich sofort.
5. **Backup ziehen** (Schritt 6) — empfohlen nach jeder Runde.
6. Erst wenn alle Bretter der Runde ein Ergebnis haben, lässt sich die nächste Runde auslosen.

## 5a. Was tun bei Rematch-Warnung?

Die Swiss-Engine ist heuristisch. Späte Runden kleiner Felder können Rematches erzwingen.
Das darf am Freitag nicht still passieren.

1. Nicht direkt auslosen, wenn Vorschau oder Pairing-Qualität `kritisch` meldet.
2. Betroffenes Brett identifizieren.
3. Wenn eine einfache Tauschpaarung ohne neues Rematch möglich ist, manuell korrigieren.
4. Im Notizfeld kurz dokumentieren: `Rematch vermieden, manueller Tausch`.
5. Wenn keine saubere Korrektur möglich ist: Entscheidung auf Papier notieren und im
   Turnierleiterkreis akzeptieren. Für Bergfest/Freestyle ist Transparenz wichtiger als
   eine perfekte FIDE-Dutch-Auslosung.

## 6. Backup / Snapshot nach jeder Runde

Autosave läuft immer in SQLite. Zusätzlich pro Runde einen externen JSON-Snapshot ziehen:

```powershell
$tournamentId = Read-Host "Turnier-Id"
$round = Read-Host "Runde oder final"
Invoke-RestMethod "http://localhost:5088/api/tournaments/$tournamentId/export/json" |
  ConvertTo-Json -Depth 12 |
  Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_$round.json"
```

Wiederherstellen (falls nötig): den JSON-Inhalt an
`POST http://localhost:5088/api/tournaments/import` mit Body
`{"tournament": <json>, "overwriteExisting": true}` senden.

> Tipp: Ordner `D:\Schach\Backups\` vorher anlegen.

## 7. Export & Druck (Paarungen + Tabelle)

Im Dashboard gibt es Export-/Druckbuttons. Direkte Endpunkte (im Browser öffnen / drucken):

- **Tabelle CSV**: `http://localhost:5088/api/tournaments/{id}/standings/export.csv`
- **Paarungen CSV (alle Runden)**: `http://localhost:5088/api/tournaments/{id}/pairings/export.csv`
- **Paarungen CSV (eine Runde)**: `.../pairings/export.csv?roundNumber=3`
- **Druckansicht ganzes Turnier (HTML)**: `http://localhost:5088/api/tournaments/{id}/print/html`
- **Rundenblatt drucken (HTML)**: `http://localhost:5088/api/tournaments/{id}/rounds/3/print/html`
- **Auslosungsvorschau drucken (HTML)**: `.../pairings/preview-next-round/print/html`

HTML-Seiten enthalten ein Druck-Layout (Strg+P → drucken oder als PDF speichern).
CSV öffnet in Excel/LibreOffice (Trennzeichen **Semikolon**, UTF-8).

## 8. Turnierende

1. Letzte Ergebnisse eingeben.
2. Finale Tabelle als CSV **und** als HTML-Druckansicht exportieren/drucken.
3. Abschluss-Backup ziehen (Schritt 6, `bergfest_final.json`).

---

## Fallback, falls die App klemmt
Siehe `docs/FRIDAY_BERGFEST_CHECKLIST.md`, Abschnitt "Fallback". Kurz:
- Backend hängt → Strg+C, Schritt 1 erneut. SQLite-Daten sind erhalten.
- Dashboard lädt nicht → Endpunkte aus Schritt 7 direkt im Browser nutzen.
- Totalausfall → letztes JSON-Backup behalten und **auf Papier** weiterspielen
  (letztes gedrucktes Rundenblatt + Tabelle als Grundlage), später nacherfassen.
- Bei unsicherer Technik während einer Runde: Runde auf Papier zu Ende spielen, erst danach
  App reparieren oder nacherfassen.
