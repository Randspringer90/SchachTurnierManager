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
6. **Automatischer Operator-Smoke (empfohlen, hängesicher):**
   ```powershell
   pwsh -File .\scripts\Smoke-OperatorWorkflow.ps1
   ```
   Startet ein **eigenes, isoliertes** Backend (Port 5099, Temp-Datenverzeichnis – stört das
   echte Turnier auf Port 5088 nicht) und prüft in einem Lauf: Health, Swiss 12/5 (genau
   5 Runden, keine 6., keine vermeidbaren Rematches, Audit-Export), Round-Robin-Late-Entry-
   Sperre, manuelle Paarung (gültig/Self-Pairing/Doppelspieler), Backup/Restore und das
   Chess960-Würfeln hinter dem QR-Flow. Erwartung: `Operator-Smoke: 20 OK, 0 FEHLER`,
   Exit-Code 0. Das Skript fährt sein Backend danach selbst wieder herunter (kein
   zurückbleibender Prozess) und löscht sein Temp-Datenverzeichnis. Logs unter
   `output\smoke\`. Hängt nichts: jeder Aufruf hat ein Timeout, der Start wartet mit
   Heartbeat und bricht spätestens nach 90 s mit klarem Exit-Code ab.
7. Optionaler manueller Dry-run im echten Backend (Port 5088):
   ```powershell
   pwsh -File .\scripts\New-DemoTournament.ps1 -Players 10 -Rounds 5 -PlayOut
   ```
   Erwartung: 5 Runden werden ausgelost und gefüllt, am Ende erscheint eine Tabelle.
8. Einmal Tabelle und Rundenblatt als CSV/HTML exportieren und drucken.
9. Backup einmal testen (Schritt 6) und QR-Vorabtest am Handy durchführen (Schritt 9 unten).

Wenn der Smoke grün ist und die Generalprobe durchläuft, ist Freitag startklar.

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

Ab v0.41.0 wählt die Swiss-Engine eine **global optimale Auslosung** (siehe
`docs/SWISS_PAIRING_ENGINE.md`): Sie erzeugt ein Rematch **nur dann**, wenn es bei diesem
Feld und dieser Begegnungshistorie **keine** rematchfreie Gesamtauslosung mehr gibt. Eine
Rematch-Warnung in Vorschau/Qualität bedeutet jetzt also: das Rematch ist rechnerisch
**unvermeidbar** (Audit-Hinweis „Rematch unvermeidbar (global optimiert …)").

1. Vorschau ansehen. Meldet die Qualität `kritisch`/Rematch, ist es kein Engine-Fehler mehr,
   sondern eine echte Zwangslage des Feldes.
2. Trotzdem prüfen, ob ein **manueller Tausch** an einem anderen Brett das Rematch auflöst,
   ohne ein neues zu erzeugen. (Die Engine garantiert global rematchfrei, falls überhaupt
   möglich – ein manueller Tausch hilft nur, wenn man bewusst andere Kriterien höher gewichtet.)
3. Falls eine Korrektur erfolgt, im Notizfeld dokumentieren: `Manueller Tausch, Begründung …`.
4. Wenn das Rematch unvermeidbar ist: so auslosen, kurz auf Papier/Audit vermerken und im
   Turnierleiterkreis akzeptieren. Für Bergfest/Freestyle ist Transparenz wichtiger als eine
   perfekte FIDE-Dutch-Auslosung.
5. Bei Feldern **über 20 Spielern** schaltet die Engine in einen Greedy-Fallback (im Audit
   gekennzeichnet); dann kann ein Rematch wieder vermeidbar sein – Vorschau besonders prüfen.

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

## 9. QR/Handy-Vorabtest (vor dem ersten Würfeln)

Der QR-Flow ist nur lokal (gleiches WLAN/Hotspot), kein Cloud-Dienst. Einmal vorab am realen
Handy prüfen — das ist die bekannte offene Verifikationslücke aus dem Postmortem:

1. Laptop-IPv4 ermitteln (`ipconfig` → IPv4-Adresse, **nicht** `localhost`). Beim Start über
   `RUN_TURNIERMANAGER.bat` werden die möglichen Adressen im Startfenster angezeigt.
2. Im Rundenbereich an einem Brett **🎲 Würfeln → Reiter „QR / Handy"** öffnen, dort die
   Laptop-IP eintragen. QR mit dem Handy scannen (Handy im selben WLAN/Hotspot).
3. Lädt die Seite am Handy → würfeln und „Für Brett speichern" → am Laptop erscheint die
   Stellung. Vorabtest bestanden.
4. Lädt sie **nicht**: Windows-Firewall kann Port `5173` blockieren, oder das Handy ist im
   falschen Netz. Dann am Laptop würfeln (Browser-Reiter, immer verfügbar) — der Turniertag
   hängt nicht davon ab.

Die Datenschicht hinter dem QR-Flow (Chess960-Startstellungen je Brett) wird vom
Operator-Smoke (Schritt 6) automatisch verifiziert; nur die Handy-Anzeige selbst muss manuell
geprüft werden.

## 10. Hänger-/Timeout-Verhalten (so hängt nichts)

- **Start (`RUN_TURNIERMANAGER.bat` / `Start-Dev.ps1`):** wartet je 60 s auf Backend und
  Frontend mit Statusausgabe; bleibt eine Komponente aus, kommt eine Warnung und der Start
  läuft weiter, statt ewig zu blockieren. Backend/Frontend laufen in eigenen Fenstern.
- **Operator-Smoke (`Smoke-OperatorWorkflow.ps1`):** jeder HTTP-Aufruf hat ein Timeout; der
  Backend-Start wartet max. 90 s mit Heartbeat; danach Exit-Code 2. Das selbst gestartete
  Backend wird zuverlässig beendet (kein zurückbleibender Listener). Exit 0 = alles grün,
  1 = mind. ein Check rot, 2 = Backend nicht startbar/erreichbar.
- **Prozess klemmt trotzdem:** gezielt am Port stoppen (siehe Schritt 1/2,
  `Get-NetTCPConnection -LocalPort <5088|5173|5099> | Stop-Process`), dann neu starten.
- **Bereitschaftscheck ohne Änderung:** `pwsh -File .\scripts\Show-EventReadiness.ps1` prüft
  nur lesend Backend, Frontend, DB-Pfad, Backup-Ordner und Git-Stand.

---

## Fallback, falls die App klemmt
Siehe `docs/FRIDAY_BERGFEST_CHECKLIST.md`, Abschnitt "Fallback". Kurz:
- Backend hängt → Strg+C, Schritt 1 erneut. SQLite-Daten sind erhalten.
- Dashboard lädt nicht → Endpunkte aus Schritt 7 direkt im Browser nutzen.
- Totalausfall → letztes JSON-Backup behalten und **auf Papier** weiterspielen
  (letztes gedrucktes Rundenblatt + Tabelle als Grundlage), später nacherfassen.
- Bei unsicherer Technik während einer Runde: Runde auf Papier zu Ende spielen, erst danach
  App reparieren oder nacherfassen.
