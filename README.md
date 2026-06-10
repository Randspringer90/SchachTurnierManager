# SchachTurnierManager

Lokaler Turniermanager fuer Schachturniere mit WebApi, React-Dashboard, Schweizer-System-Fokus, Exporten, Audit-Funktionen und portablem Windows-Paket.

## Aktueller Stand

**Version:** 0.38.0

Der aktuelle Entwicklungsstand enthaelt die Funktionen bis 0.37.6 plus diesen Doku-/Sicherheitsbaustein fuer sichere Commits.

## Schnellstart

Backend starten:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Healthcheck:

```text
http://localhost:5088/api/health
```

Frontend starten:

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run dev
```

Dashboard:

```text
http://localhost:5173
```

Release-Gate ausfuehren:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Invoke-ReleaseGate.ps1"
```

Sicher committen und pushen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-If-Green.ps1" -Message "<Commit-Nachricht>" -Push
```

## Funktionen bis 0.37.6

- Turniere lokal anlegen und dauerhaft speichern.
- Teilnehmer erfassen, bearbeiten, loeschen oder zurueckziehen.
- Externe Spielerdaten per FIDE-ID suchen, ins Teilnehmerformular uebernehmen und speichern.
- Schweizer-System-V2 mit Scoregruppen-Audit, Floater-Hinweisen, Bye-Schutz, Farbhistorie und Rundenintervall-Historie.
- Ergebnisverwaltung mit normalen Ergebnissen, Remis, kampflosen Ergebnissen, Bye und Spielfrei.
- Live-Tabelle, Kreuztabelle, Heldenpokal, Kategorieauswertungen und Runden-/Paarungsdiagnosen.
- Naechste-Runde-Vorschau vor verbindlicher Auslosung.
- Auslosungsfreigabe mit Blocker-/Warnhinweisen.
- Bye-/kampflos-/Spielfrei-Audit im Dashboard.
- Korrektur- und Eingriffsuebersicht.
- Persistentes Audit-Journal fuer zentrale Turnierleitungsaktionen.
- Audit-Journal-Dashboardkarte mit Kennzahlen, letzten Eintraegen und CSV-/JSON-Export.
- Audit-Journal-Query-Service mit Filterung, Sortierung, Paging und Statistikzaehlung.
- Audit-Journal-Query-API fuer serverseitige Filter.
- Tabellen, Paarungen, Rundenblaetter, Ergebnisuebersichten und Turnierdaten als CSV/JSON/HTML exportieren.
- Portable Paket mit eingebettetem Dashboard erzeugen und per Start-BAT lokal ausfuehren.
- Release-Gate fuer Restore, Build, Tests, Frontend-Build und Paketierung.
- Safe Commit Guard gegen Artefakte und typische Secrets vor Git-Commits.

## Sicherheit und Git-Regeln

Nicht einchecken:

- Build-Artefakte: `bin/`, `obj/`, `dist/`, `output/`, `node_modules/`
- Archive und Pakete: `*.zip`, `*.7z`, `*.nupkg`
- Logs/Dumps/Reports: `*.log`, `*.dmp`, `logs/`, `reports/`
- Datenbanken und lokale Turnierdaten: `*.db`, `*.sqlite`, `*.sqlite3`
- lokale Konfiguration und Secrets: `.env*`, `*.key`, `*.pem`, `*.pfx`, `*.p12`, `secrets.*`

Vor einem Commit laeuft `scripts/Test-GitCommitSafety.ps1`. Der Guard bricht ab, wenn verbotene Artefakte, grosse Dateien oder typische Secret-Muster in geaenderten Dateien gefunden werden.

## Repository-Struktur

```text
src/SchachTurnierManager.Domain          Fachmodell und Domain-Services
src/SchachTurnierManager.Application     Turnierlogik und Anwendungsservices
src/SchachTurnierManager.Infrastructure  Persistenz/Infrastruktur
src/SchachTurnierManager.WebApi          HTTP-API und statisches Dashboard-Hosting
src/SchachTurnierManager.WebApp          React/Vite-Frontend
tests/                                   Domain-, Application-, Infrastructure- und Golden-Tests
scripts/                                 Release-, Paketierungs- und Sicherheits-Skripte
docs/                                    Handoffs und technische Notizen
```

## Bekannte Hinweise

- Node.js `v20.20.0` erzeugt aktuell eine EBADENGINE-Warnung fuer Vite/Rolldown. Der Build laeuft bislang trotzdem, empfohlen ist ein Update auf eine passende Node-Version.
- GitHub-README und Changelog sollen ab jetzt bei groesseren Feature-Bloecken zeitnah nachgezogen werden.