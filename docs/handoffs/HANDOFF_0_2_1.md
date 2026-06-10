# Handoff 0.2.1

## Zweck

Kleiner Stabilisierungspatch nach 0.2.0. Der fachliche Stand bleibt gleich; korrigiert wird der Infrastrukturtest, der unter Windows die temporäre SQLite-Datei beim Aufräumen noch gelockt fand.

## Einspielen

ZIP-Inhalt über `D:\Schach\SchachTurnierManager` entpacken/überschreiben. Die ZIP enthält kein `.git`, kein `node_modules`, kein `dist` und keine Build-Ausgaben.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; dotnet build; dotnet test
```

Frontend zusätzlich:

```powershell
Set-Location "D:\Schach\SchachTurnierManager\src\SchachTurnierManager.WebApp"; npm install; npm run build
```

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize SQLite persistence test"; git push
```
