# Skill: Klick-Installation / Kollegen-Rollout

Nutzen, wenn am SchachTurnierManager Installationspakete, Startdateien, Kollegenpakete oder Frisch-PC-Tests geaendert werden.

## Regeln

- Das Projekt muss eigenstaendig bleiben: keine Abhaengigkeit auf Nachbarprojekte, lokale Workspaces oder globale Secrets.
- Endnutzer sollen kein .NET, Node oder npm installieren muessen.
- Secrets duerfen nicht im Paket enthalten sein. Lokale DPAPI-Secrets bleiben je Benutzer/Rechner in `.secrets/local/` oder werden nach Installation neu gesetzt.
- Ein Klickpfad muss vorhanden sein: Setup-EXE oder `Install-SchachTurnierManager.cmd`.
- Installation und Uninstall muessen testbar sein, ohne echte Benutzerordner zu veraendern. Dafuer Testparameter wie `-InstallDirectory` und `-ShortcutDirectory` nutzen.
- Jede Aenderung an Packaging/Installation braucht mindestens einen Guard-Test und einen Readiness-Lauf.

## Standardpruefung

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ClickInstallReadiness.ps1 -BuildPackage -BuildInstaller -AllowMissingInnoSetup
```
