# Handoff 0.22.2

## Ziel

v0.22.2 stabilisiert den abgebrochenen v0.22.1-Patchlauf für die Auslosungsvorschau.

## Inhalt

- Entfernt defekte Zwischenstandsdateien aus v0.22.0/v0.22.1.
- Setzt API-, Dashboard- und Paketversionen auf 0.22.2.
- Prüft, dass die v0.22-Auslosungsvorschau vorhanden ist.
- Ergänzt CHANGELOG.md.
- Führt Restore, Build, Tests, Frontend-Build und Portable-Packaging mit hartem Abbruch bei Fehlern aus.

## Erwartetes Ergebnis

- `dotnet build` grün
- `dotnet test` grün
- `npm run build` grün
- Portable-ZIP `SchachTurnierManager_Portable_0.22.2.zip`

## Commit-Vorschlag

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize next round pairing preview"; git push
```
