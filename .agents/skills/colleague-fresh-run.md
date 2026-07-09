# Skill: Kollegenpaket-Frischlauf

Nutze diesen Skill, wenn ein KI-Agent pruefen soll, ob ein SchachTurnierManager-Releasepaket wirklich auf einem frischen Zielordner startfaehig ist.

## Pflichtregeln

1. Keine Secrets, Logs, Datenbanken oder lokalen Run-Ordner committen.
2. Erst `Invoke-ColleagueInstallReadiness.ps1`, dann `Invoke-ColleagueFreshRunTest.ps1` verwenden.
3. Details gehoeren in `D:\Temp\<RunName>_<Timestamp>`, die Konsole zeigt nur Status und `UPLOAD_ZIP`.
4. Der Test muss einen isolierten Datenordner verwenden, niemals echte Benutzerdaten.
5. Fehlendes Inno Setup ist ein dokumentierter Blocker fuer Setup-EXE, aber kein Blocker fuer Desktop-/Portable-ZIP.

## Standardkommando

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ColleagueFreshRunTest.ps1 -BuildPackage -BuildInstaller -AllowMissingInnoSetup
```

## Erfolgsbedingungen

- ReleaseGate gruen.
- Kollegenpaket vorhanden.
- Checksums gueltig.
- Desktop-ZIP startet im Frischordner.
- Health, Dashboard und Turnierliste antworten.
- Upload-ZIP wurde erzeugt.
