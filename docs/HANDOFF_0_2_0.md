# Handoff 0.2.0

## Einspielen

ZIP-Inhalt über `D:\Schach\SchachTurnierManager` entpacken/überschreiben. `.git` bleibt im lokalen Repository erhalten, weil die ZIP kein `.git` enthält.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; .\scripts\After-Apply-V0.2.ps1
```

Danach:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Implement persistent MVP dashboard"; git push
```

## Manuelle Smoke-Test-Idee

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; .\scripts\Start-Dev.ps1
```

Dann im Browser `http://localhost:5173` öffnen, ein Turnier anlegen, mindestens zwei Teilnehmer eintragen, eine Runde auslosen und ein Ergebnis speichern.
