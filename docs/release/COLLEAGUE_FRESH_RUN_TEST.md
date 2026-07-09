# Kollegenpaket-Frischlauf-Test

Dieser Test prueft nicht nur, ob Release-Artefakte gebaut werden, sondern ob das Kollegenpaket in einem frischen Ordner entpackt und gestartet werden kann.

## Standardlauf

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ColleagueFreshRunTest.ps1 -BuildPackage -BuildInstaller -AllowMissingInnoSetup
```

## Was geprueft wird

- `SchachTurnierManager_Kollegenpaket_<Version>.zip` ist vorhanden.
- `README_START_HIER.txt`, `KOLLEGENPAKET_MANIFEST.txt` und `CHECKSUMS_SHA256.txt` sind enthalten.
- SHA256-Pruefsummen stimmen mit den enthaltenen Dateien ueberein.
- Desktop-ZIP ist enthalten und entpackbar.
- Doppelklick-Starter (`SchachTurnierManager.bat` oder `Start-SchachTurnierManager.bat`) ist vorhanden.
- `SchachTurnierManager.WebApi.exe` und `wwwroot/index.html` sind enthalten.
- Der Desktop-Server startet auf einem freien Loopback-Port.
- `/api/health`, Dashboard `/` und `/api/tournaments` liefern HTTP 2xx.
- Die SQLite-Datenbank wird in einem isolierten Testdatenordner unter `D:\Temp` erzeugt.

## Warum kein echter fremder Rechner?

Der Skriptlauf ersetzt keinen finalen Test auf einem Kollegenrechner. Er schliesst aber die haeufigsten Paketierungsfehler aus, bevor das ZIP weitergegeben wird. Fuer den echten Kollegen-Test soll das erzeugte Kollegenpaket auf einen frischen Windows-Benutzer oder Rechner kopiert und dort per Doppelklick gestartet werden.

## Secrets

Lokale DPAPI-Secrets sind benutzer- und rechnergebunden. Sie werden nicht in das Kollegenpaket aufgenommen und muessen bei Bedarf pro Zielrechner neu gesetzt werden.
