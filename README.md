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

## Start

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
