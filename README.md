# SchachTurnierManager

Lokaler Turniermanager für Schweizer-System-Turniere im Vereins- und Open-Kontext.

## Aktueller Stand bis 0.38.x

- Turniere lokal anlegen, speichern und als portable Version starten.
- Teilnehmer erfassen, importieren, bearbeiten, zurückziehen und löschen.
- Externe Spielerdaten per FIDE-ID suchen und übernehmen.
- Schweizer-System-Paarungen mit Audit, Bye-/kampflos-Prüfungen und Regressionstests.
- Ergebnisse, Tabellen, Kategorien, Kreuztabelle, Rundenblätter und Exporte.
- Persistentes Audit-Journal mit Dashboard, Exporten und Query-API.
- Release-Gate für Restore, Build, Tests, Frontend-Build und Portable-Paket.
- Commit-Guard mit Open-Source-Sicherheitsprüfungen gegen Artefakte, lokale Audits, Backups, interne Registry-URLs und typische Secret-Muster.

## Schnellstart (empfohlen)

Zum Starten doppelklicken: **`RUN_TURNIERMANAGER.bat`** (im Repo-Root).

Die Datei startet Backend und Frontend in getrennten Fenstern und öffnet den Browser
auf `http://localhost:5173`. Sie nutzt PowerShell 7 (`pwsh`), falls vorhanden, sonst
Windows PowerShell, jeweils mit `-ExecutionPolicy Bypass` nur für diesen Prozess – die
globale ExecutionPolicy wird **nicht** verändert und es werden **keine** Adminrechte benötigt.

> Hinweis: Wenn PowerShell `.\scripts\Start-Dev.ps1` direkt mit der Meldung
> „cannot be loaded … is not digitally signed" blockiert, einfach `RUN_TURNIERMANAGER.bat`
> verwenden – die BAT umgeht die Signaturprüfung prozesslokal.

## Start (manuell)

Backend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Frontend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run dev
```

Dashboard:

```text
http://localhost:5173
```

Healthcheck:

```text
http://localhost:5088/api/health
```

## Chess960-Würfeln pro Brett (Desktop + QR/Handy)

Im Rundenbereich hat jedes reguläre Brett neben der Chess960-Spalte einen
**„🎲 Würfeln"**-Button. Er öffnet ein Popup für genau dieses Turnier, diese Runde und
dieses Brett – mit zwei internen Reitern:

- **Browser würfeln:** Der Würfel arbeitet sich Feld für Feld von links nach rechts durch
  die acht Felder der Grundreihe und zeigt die Figuren. Anschließend
  „💾 Für Brett speichern" (oder „🎲 Nochmal würfeln" / „Abbrechen"). Eine bereits
  gespeicherte Stellung wird nur nach Rückfrage überschrieben. Die Stellung bleibt nach
  Reload/Backup erhalten und erscheint weiter auf dem Rundenblatt/Druck.
- **QR / Handy (nur lokal):** Zeigt einen QR-Code und eine LAN-URL, mit der
  Teilnehmer/Schiedsrichter dieses Brett am Handy auswürfeln. Funktioniert **nur im
  gleichen WLAN/Hotspot** wie der Laptop. Kein Cloud-Dienst, kein Tunnel.

Hinweise zur QR/Handy-Nutzung:

- **`localhost` funktioniert am Handy nicht** – es zeigt auf das Handy selbst. Im QR-Reiter
  die **LAN-IP des Laptops** eintragen (Windows: `ipconfig` → IPv4-Adresse). Beim Start über
  `RUN_TURNIERMANAGER.bat` werden die möglichen Laptop-Adressen im Startfenster angezeigt.
- Der Dev-Server ist für das LAN erreichbar (`vite --host 0.0.0.0`); `http://localhost:5173`
  am Laptop funktioniert weiterhin.
- Eine **Windows-Firewall** kann den Zugriff auf Port `5173` blockieren. Dann am Laptop
  würfeln – die Browser-Würfelfunktion ist davon unabhängig und immer verfügbar.
- Würfeln Laptop und Handy gleichzeitig dasselbe Brett, gilt die zuletzt gespeicherte
  Stellung; vorhandene Stellungen werden nur nach Rückfrage überschrieben.

Der bestehende Button „🎲 Schachwürfel öffnen" (alle Bretter einer Runde auf einmal) bleibt
unverändert erhalten.

## Release-Gate

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1"
```

## Sicher committen

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "Commit message" -Push
```

Das bestehende private Entwicklungsrepo soll nicht direkt öffentlich geschaltet werden, wenn historische interne Registry-URLs oder lokale Auditdateien enthalten waren. Für eine öffentliche Veröffentlichung wird ein geprüfter Clean Snapshot ohne alte Git-Historie empfohlen.
## Commit-Sicherheitscheck

Commits laufen ueber scripts/Commit-If-Green.ps1. Der Guard prueft Build, Tests, Frontend, Paketierung und blockiert lokale Audit-/Backup-Dateien, Artefakte, interne Registry-Referenzen und kritische Zugangsdaten-Muster. Fuer eine spaetere Open-Source-Veröffentlichung wird ein Clean Snapshot ohne private Historie verwendet.
