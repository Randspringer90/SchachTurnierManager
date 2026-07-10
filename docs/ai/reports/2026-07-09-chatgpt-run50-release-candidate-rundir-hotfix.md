# Abschlussbericht: RUN-50 Hotfix ReleaseCandidateReadiness RunDirectory

## Ergebnis

`Invoke-ReleaseCandidateReadiness.ps1` erstellt den Run-Ordner jetzt direkt ueber `New-ReleaseRunDirectory` und gibt `RUN_DIR=...` aus. Damit ist `$runDirectory` innerhalb des Skripts sicher gesetzt und `Invoke-LoggedCommand.ps1` bekommt einen gueltigen Zielordner.

## Fehlerursache

Die bisherige Variante verwendete:

```powershell
$runDirectory = & $bundleScript -RunName $RunName -CreateOnly
```

`New-RunLogBundle.ps1` schrieb den Pfad per `Write-Host`. Das ist als Konsolenausgabe sichtbar, aber nicht robust als Pipeline-Wert fuer interne Skriptaufrufe. Dadurch blieb `$runDirectory` null und die Fehlerbehandlung konnte `FAILED.txt` nicht schreiben.

## Geaenderte Bereiche

- `scripts/Invoke-ReleaseCandidateReadiness.ps1`
- `tests/SchachTurnierManager.Application.Tests/OperationalGuardTests.cs`
- Version/Doku: `CHANGELOG.md`, `PLANS.md`, `README.md`, Health und WebApp-Paketdateien

## Tests

Noch lokal durch Maintainer auszufuehren:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Erwartung: kurzer Konsolenlauf, `RUN_DIR=...`, am Ende `UPLOAD_ZIP=...`.
