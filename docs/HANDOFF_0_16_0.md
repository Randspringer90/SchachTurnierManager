# Handoff 0.16.0 – CSV-Import bewusst bestätigen und Vorlagen

## Ziel

v0.16.0 verbessert den CSV-Import-Workflow im Dashboard. Nach der Importvorschau können blockierende Probleme weiterhin nicht importiert werden. Warnungen und mögliche Dubletten müssen nun bewusst bestätigt werden, bevor der Import ausgeführt wird.

## Änderungen

- CSV-Beispielvorlage im Dashboard ergänzen.
- Importvorschau bleibt Pflicht vor dem Import.
- Warnungen/mögliche Dubletten müssen per Checkbox bestätigt werden.
- Änderungen an CSV-Inhalt oder Ersetzen-Option verwerfen Vorschau und Warnungsbestätigung.
- Versionsnummern auf `0.16.0` angehoben.
- `CHANGELOG.md` ergänzt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.16.ps1"
```

Erwartet:

- `dotnet build` grün
- `dotnet test` grün
- `npm run build` grün
- Portable-ZIP `SchachTurnierManager_Portable_0.16.0.zip`

## Commit

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Require confirmation for CSV import warnings"; git push
```

## Nächster sinnvoller Schritt

v0.17.0 sollte den Import weiter professionalisieren:

- Importmodus „nur unkritische Zeilen übernehmen“ fachlich modellieren.
- Bessere CSV-Vorlagen/Download als Datei.
- Importprotokoll nach erfolgreichem Import anzeigen/exportieren.
- Danach: Swiss-Golden-Tests und Pairing-Qualitätsbericht.
