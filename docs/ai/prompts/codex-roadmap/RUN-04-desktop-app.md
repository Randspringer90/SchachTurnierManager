# RUN-04 – Self-contained Desktop-App feinschleifen

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ausgangslage (bereits erledigt, 2026-07-06)
- `scripts/Publish-DesktopApp.ps1`: self-contained win-x64, Frontend in `wwwroot`,
  Ausgabe `output\desktop`, Klick-Start `SchachTurnierManager.bat` (Daten unter
  `%LocalAppData%\SchachTurnierManager`, Backend-Default).
- Smoke-Test bestanden (Health + eingebettetes Dashboard).

## Aufgaben
- Test auf möglichst „frischem" Kontext: Paket in fremden Ordner kopieren, ohne
  gesetzte Dev-Umgebungsvariablen starten.
- Beenden-Erlebnis verbessern: minimiertes Konsolenfenster ist ok für v1, aber prüfen,
  ob ein sauberer „Beenden"-Weg (z. B. Tray-Hinweis im Dashboard oder Shutdown-Endpoint
  mit Bestätigung) risikoarm machbar ist.
- Portbelegung 5088 robust behandeln (klare Fehlermeldung, wenn belegt; optional
  automatische Portwahl mit Anzeige).
- App-Icon (.ico) ergänzen und in csproj/Installer verdrahten.
- README-Desktop.md für Endnutzer verständlich halten.

## Nicht in diesem Lauf
- Kein Electron/WebView2-Umbau ohne separate Entscheidung.
