# SchachTurnierManager

Lokaler Schachturnier-Manager mit Dashboard, Backend, Turnierlogik, Paarungsalgorithmen, Wertungen, Rating-Prognosen und späteren Import-/Export-Adaptern.

## Zielpfad beim Nutzer

```powershell
D:\Schach\SchachTurnierManager
```

## Architektur

- `SchachTurnierManager.Domain`: fachliche Regeln und Algorithmen.
- `SchachTurnierManager.Application`: Use Cases und In-Memory-MVP-Store.
- `SchachTurnierManager.Infrastructure`: spätere SQLite-/EF-Core- und Import-/Export-Anbindung.
- `SchachTurnierManager.WebApi`: lokale ASP.NET-Core-API.
- `SchachTurnierManager.WebApp`: React/TypeScript/Vite-Dashboard.
- `tests`: Unit- und Golden Tests.

## Erste Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet restore; dotnet build; dotnet test
```

## Backend starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet run --project .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj
```

Healthcheck:

```text
http://localhost:5088/api/health
```

## Frontend starten

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run dev
```

Dashboard:

```text
http://localhost:5173
```

## GitHub

Das Repository wurde lokal bereits als `Randspringer90/SchachTurnierManager` vorbereitet. In dieser ZIP ist bewusst kein `.git` enthalten. Inhalte in dein bestehendes Repo kopieren, dann:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Add initial application skeleton"; git push
```

## Status

Version 0.1.0: Architektur- und Codebasis, erste Algorithmen und Tests. Noch keine vollständige Turnierleiter-UI und noch kein vollständiges FIDE-Dutch-Swiss.
