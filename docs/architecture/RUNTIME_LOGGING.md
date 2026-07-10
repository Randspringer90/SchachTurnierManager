# Runtime Logging

Stand: ab 0.54.0.

## Zweck

Der SchachTurnierManager soll auch bei Kollegeninstallationen und Vereinsabenden ohne Entwicklerwerkzeuge diagnostizierbar bleiben. Deshalb gibt es ab 0.54.0 ein festes Laufzeit-Logkonzept neben den bereits bestehenden Run-ZIPs unter `D:\Temp`.

## Log-Orte

| Laufart | Log-Ort |
|---|---|
| Entwicklung aus dem Repo | `logs\` im Projektordner |
| Desktop-/Kollegeninstallation | `%LocalAppData%\SchachTurnierManager\logs` |
| Portable Paket | `logs\` neben `Start-SchachTurnierManager.bat` |
| Build-/Test-/Release-Readiness | `D:\Temp\<RunName>_<Timestamp>` plus Upload-ZIP |

`logs/README.md` und `logs/.gitkeep` sind im Repo erlaubt. Logdateien selbst bleiben per `.gitignore` ausgeschlossen.

## Technische Umsetzung

Die WebApi nutzt neben Single-Line-Console-Logging einen lokalen `BoundedFileLoggerProvider` ohne externe NuGet-Abhaengigkeit. Der Provider schreibt taegliche Dateien im Format `schachturniermanager-yyyyMMdd.log`, begrenzt die Dateigroesse und behaelt standardmaessig 14 Logdateien.

Die Konfiguration erfolgt ueber:

```json
{
  "SchachTurnierManager": {
    "LogDirectory": "logs",
    "FileLogging": {
      "Enabled": true,
      "RetainedFileCount": 14,
      "MaxFileSizeBytes": 5242880
    }
  }
}
```

Wenn `LogDirectory` nicht gesetzt ist, wird automatisch `DataDirectory\logs` verwendet.

## Datenschutz und Sicherheit

- HTTP-Request-Logs enthalten nur Methode, Pfad ohne Querystring, Statuscode und Laufzeit.
- Typische Secret-Key/Value-Muster wie `token=...`, `password=...`, `api_key=...` werden vor dem Schreiben redigiert.
- Logs duerfen nicht in Austausch-ZIPs, Public Snapshots oder Commits geraten.
- Echte Teilnehmerlisten, Datenbanken und private Dumps gehoeren nicht in Logs.

## Pruefung

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-LoggingReadiness.ps1 -BuildDesktop
```

Der Test baut bei Bedarf die Desktop-Version, startet die WebApi mit isoliertem Daten- und Logordner, prueft Health/Dashboard/API, kontrolliert erzeugte Logdateien und stellt sicher, dass Querystrings nicht ins Log geschrieben werden.
