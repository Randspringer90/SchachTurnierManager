# Handoff 0.16.1 - CSV-Import mit Warnungsbestätigung

## Zweck

Fix-Forward für v0.16.0: Das ursprüngliche Nachkontrollskript enthielt eine PowerShell-Parserstelle mit `$Path:` in einem interpolierten String. v0.16.1 korrigiert die Interpolation mit `${Path}:` und wendet den geplanten CSV-Import-Workflow erneut an.

## Inhalt

- Versionen auf `0.16.1` angehoben.
- CSV-Beispielvorlage im Dashboard.
- Import mit Warnungen/Dubletten erfordert bewusste Bestätigung.
- Änderungen an CSV-Inhalt oder Ersetzen-Option verwerfen Vorschau und Bestätigung.
- Blockierende Probleme verhindern den Import weiterhin hart.

## Nachkontrolle

Ausführen:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.16.1.ps1"
```

Wenn grün:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Require confirmation for CSV import warnings"; git push
```
