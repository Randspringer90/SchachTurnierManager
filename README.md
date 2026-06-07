# SchachTurnierManager

Lokaler Schachturnier-Manager mit Dashboard, Backend, Turnierlogik, Paarungsalgorithmen, Wertungen, Rating-Prognosen und späteren Import-/Export-Adaptern.

## Zielpfad beim Nutzer

```powershell
D:\Schach\SchachTurnierManager
```

## Architektur

- `SchachTurnierManager.Domain`: fachliche Regeln und Algorithmen.
- `SchachTurnierManager.Application`: Use Cases und Store-Abstraktion.
- `SchachTurnierManager.Infrastructure`: SQLite-/EF-Core-Persistenz und spätere Import-/Export-Anbindung.
- `SchachTurnierManager.WebApi`: lokale ASP.NET-Core-API.
- `SchachTurnierManager.WebApp`: React/TypeScript/Vite-Dashboard.
- `tests`: Unit-, Persistenz- und Golden Tests.

## Erste Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; .\scripts\Test-All.ps1
```

Alternativ einzeln:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet restore; dotnet build; dotnet test
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run build
```

## Entwicklung starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; .\scripts\Start-Dev.ps1
```

Backend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Healthcheck:

```text
http://localhost:5088/api/health
```

Frontend:

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run dev
```

Dashboard:

```text
http://localhost:5173
```

## Funktionen in 0.4.0

- Turniere lokal anlegen und dauerhaft speichern.
- Teilnehmer erfassen, bearbeiten, löschen oder zurückziehen.
- Schweizer-System-V2 mit Scoregruppen-Audit, Floater-Hinweisen, Bye-Schutz und Farbhistorie sowie Rundenturnier-Runden erzeugen.
- Ergebnisse erfassen und Live-Tabelle berechnen.
- Kategorieauswertungen für Frauen, Jugendklassen und Senioren anzeigen.
- Kreuztabelle, Heldenpokal und Rundenaudit anzeigen.
- Teilnehmer per CSV importieren/exportieren.
- Turnier per JSON sichern und wiederherstellen.

## Lokale Datenbank

Die API legt die SQLite-Datenbank standardmäßig unter `%LOCALAPPDATA%\SchachTurnierManager\SchachTurnierManager.sqlite` an.

Optional kann der Datenordner per Konfiguration `SchachTurnierManager:DataDirectory` angepasst werden.

## GitHub

Das Repository liegt als privates Repo unter `Randspringer90/SchachTurnierManager`. In ZIPs ist bewusst kein `.git` enthalten. Inhalte in das bestehende Repo kopieren, dann:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Update SchachTurnierManager"; git push
```

## Status

Version 0.5.0: Turnierleiter-MVP mit SQLite-Persistenz, Teilnehmerpflege, Kategorieauswertungen, Kreuztabelle, Heldenpokal, CSV-/JSON-Import/Export und gehärteter Schweizer-System-Auslosung V2. Noch kein vollständiges FIDE-Dutch-Swiss und noch kein produktiver Installer.


## Entwicklerstart-Hinweis

`scripts/Start-Dev.ps1` öffnet das Dashboard bewusst über `http://127.0.0.1:5173`, weil Vite lokal an IPv4 gebunden ist und `localhost` je nach Windows-/Browser-Konfiguration zuerst IPv6 auflösen kann.


## Regelmäßige Checkpoint-Commits

Nach einem grünen Stand kann ein geprüfter Commit mit folgendem Skript erstellt werden:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Commit-Checkpoint.ps1" -Message "Checkpoint: Beschreibung" -Push
```
