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

## Lokale Datenbank

Die API legt die SQLite-Datenbank standardmäßig unter `%LOCALAPPDATA%\SchachTurnierManager\SchachTurnierManager.sqlite` an.

Optional kann der Datenordner per Konfiguration `SchachTurnierManager:DataDirectory` angepasst werden.

## GitHub

Das Repository liegt als privates Repo unter `Randspringer90/SchachTurnierManager`. In ZIPs ist bewusst kein `.git` enthalten. Inhalte in das bestehende Repo kopieren, dann:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Update SchachTurnierManager"; git push
```

## Status

Version 0.2.0: Persistentes MVP mit SQLite, API-Endpunkten, bedienbarem React-Dashboard, Frontend-Build-Fix, `.gitattributes`, erweitertem Testskript und Persistenztest. Noch kein vollständiges FIDE-Dutch-Swiss und noch kein produktiver Installer.
