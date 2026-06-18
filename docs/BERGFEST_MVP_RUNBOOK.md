# BERGFEST_MVP_RUNBOOK.md

Schritt-für-Schritt-Anleitung für den Turniertag (Freitag).
Alles läuft lokal. Alle Befehle in **PowerShell** aus `D:\Schach\SchachTurnierManager`.

> Kurzfassung zum Abhaken: `docs/FRIDAY_BERGFEST_CHECKLIST.md`.
> Hintergrund/Architektur: `docs/BERGFEST_MVP_PLAN.md`.

---

## 0. Am Abend vorher (Generalprobe, ~10 Min)

1. Backend starten (siehe Schritt 1).
2. Frontend starten (siehe Schritt 2) **oder** Demo-Skript laufen lassen:
   ```powershell
   pwsh -File .\scripts\New-DemoTournament.ps1 -PlayerCount 10 -PlayOut
   ```
   Erwartung: 5 Runden werden ausgelost und gefüllt, am Ende erscheint eine Tabelle.
3. Einmal Tabelle + Rundenblatt als CSV/HTML exportieren und drucken (Schritt 7),
   damit der Druckweg am Turniertag sicher sitzt.
4. Backup einmal testen (Schritt 6).

Wenn die Generalprobe durchläuft, ist Freitag startklar.

---

## 1. Backend starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

- API läuft auf **http://localhost:5088**.
- Healthcheck im Browser: **http://localhost:5088/api/health** → muss `status` zeigen.
- Datenbank liegt unter `%LocalAppData%\SchachTurnierManager\SchachTurnierManager.sqlite`
  und wird **nach jeder Aktion automatisch gespeichert**.

Fenster offen lassen. Strg+C beendet das Backend (Daten bleiben in SQLite erhalten).

## 2. Frontend (Dashboard) starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"
npm install   # nur beim ersten Mal nötig
npm run dev
```

- Dashboard: **http://localhost:5173**

> Alternative ohne Node: Portable-Paket bauen (`scripts\Pack-Portable.ps1`) und
> `output\portable\Start-Portable.bat` starten — das Backend liefert das Dashboard
> dann selbst aus. Für Freitag genügt aber der Dev-Weg oben.

## 3. Turnier anlegen

Im Dashboard ein neues Turnier anlegen:
- **Name**: `Bergfest Freestyle-Würfelschach <Datum>` (Modus steht so im Namen/Export).
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

1. **Vorschau ansehen**: „Vorschau nächste Runde“.
   - Qualitätswert/Severity prüfen.
   - **Severity „kritisch“ / Rematch?** → betroffenes Brett per **manueller Paarung**
     (Override) korrigieren. Im Notizfeld ggf. die gewürfelte Startstellung eintragen.
2. **Auslosen**: „Nächste Runde auslosen“ übernimmt die Paarungen.
3. **Rundenblatt drucken/aushängen** (Schritt 7): HTML-Rundenblatt oder Paarungs-CSV.
4. **Ergebnisse eingeben**: pro Brett 1-0 / ½-½ / 0-1 (bzw. kampflos +/- / Bye).
   - **Korrektur**: einfach das Ergebnis am selben Brett erneut setzen — es überschreibt
     und die Tabelle aktualisiert sich sofort.
5. **Backup ziehen** (Schritt 6) — empfohlen nach jeder Runde.
6. Erst wenn alle Bretter der Runde ein Ergebnis haben, lässt sich die nächste Runde auslosen.

## 6. Backup / Snapshot nach jeder Runde

Autosave läuft immer in SQLite. Zusätzlich pro Runde einen externen JSON-Snapshot ziehen:

```powershell
# {id} = Turnier-Id (steht im Dashboard / in der URL)
Invoke-RestMethod "http://localhost:5088/api/tournaments/{id}/export/json" |
  ConvertTo-Json -Depth 12 |
  Set-Content -Encoding utf8 "D:\Schach\Backups\bergfest_runde_<N>.json"
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
Siehe `docs/FRIDAY_BERGFEST_CHECKLIST.md`, Abschnitt „Fallback“. Kurz:
- Backend hängt → Strg+C, Schritt 1 erneut. SQLite-Daten sind erhalten.
- Dashboard lädt nicht → Endpunkte aus Schritt 7 direkt im Browser nutzen.
- Totalausfall → letztes JSON-Backup behalten und **auf Papier** weiterspielen
  (letztes gedrucktes Rundenblatt + Tabelle als Grundlage), später nacherfassen.
