# Klick-Installation fuer Kollegen

Status: ab 0.53.0 automatisiert pruefbar.

## Ziel

Das Kollegenpaket soll ohne Entwicklungsumgebung installierbar sein. Ein Kollege soll das ZIP entpacken und danach entweder die enthaltene Setup-EXE oder den Bootstrapper `Install-SchachTurnierManager.cmd` per Doppelklick starten koennen.

## Installationsvarianten

1. **Setup-EXE**, falls Inno Setup lokal verfuegbar war und eine EXE erzeugt wurde.
2. **Klick-Bootstrapper** `Install-SchachTurnierManager.cmd`, immer im Kollegenpaket enthalten.
3. **Desktop-ZIP manuell entpacken**, als Fallback ohne Installation.
4. **Portable-ZIP**, nur fuer bewusst portable Tests.

## Bootstrapper-Verhalten

`Install-SchachTurnierManager.cmd` ruft `Install-SchachTurnierManager.ps1` auf. Das Skript:

- sucht `SchachTurnierManager_Desktop_*.zip` im Paketordner,
- prueft Starter, WebApi-EXE und `wwwroot`,
- installiert nach `%LocalAppData%\Programs\SchachTurnierManager`,
- legt einen Startmenue-Shortcut an,
- schreibt ein `INSTALLATION_MANIFEST.txt`,
- laesst Nutzerdaten getrennt unter `%LocalAppData%\SchachTurnierManager`.

`Uninstall-SchachTurnierManager.cmd` entfernt Installation und Shortcut. Nutzerdaten bleiben standardmaessig erhalten; fuer Tests kann `Uninstall-ColleagueDesktopApp.ps1 -RemoveUserData` genutzt werden.

## Readiness-Test

`Invoke-ClickInstallReadiness.ps1` prueft den Kollegenpfad in einem frischen Testordner:

- Kollegenpaket bauen oder vorhandenes Paket nutzen,
- Paket entpacken,
- README, Manifest, Checksums und Install-/Uninstall-Dateien pruefen,
- SHA256-Pruefsummen validieren,
- Installation in einen isolierten Testordner ausfuehren,
- Shortcut in einen isolierten Test-Shortcutordner erzeugen,
- installierte App auf einem freien Loopback-Port starten,
- `/api/health`, Dashboard und `/api/tournaments` pruefen,
- isolierte SQLite-Datenbank im Testdatenordner nachweisen,
- Uninstall ausfuehren und Installationsordner/Shortcut entfernen.

## Grenzen

- Die Bootstrapper sind unsigniert. SmartScreen-Warnungen sind moeglich.
- DPAPI-Secrets sind benutzer- und rechnergebunden und werden nicht mit ausgeliefert.
- Fuer echte Verteilung sollte spaeter entschieden werden, ob eine signierte Setup-EXE erstellt wird.
