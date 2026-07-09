# .secrets/ – lokale Authentifizierung und Secrets

Dieser Ordner ist der bevorzugte lokale Ablageort für Zugangsdaten, Tokens und private
Build-Konfigurationen. **Nur diese README darf committed werden.** Alles unter
`.secrets/local/` ist per `.gitignore` ausgeschlossen und bleibt ausschließlich lokal.

## Ziel

- Keine Tokens, API-Keys, `.npmrc`, `.env` oder Zertifikate im Repository.
- Secrets nur lokal speichern und höchstens als Prozess-Umgebungsvariable an Tools geben.
- npm-Builds ohne globale/userweite `.npmrc`-Altlasten ausführen, damit Warnungen wie
  veraltete `always-auth`-Einträge nicht aus deinem Benutzerprofil in Release-Gates hineinlaufen.

## Lokales Secret per Windows-DPAPI speichern

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-LocalSecret.ps1 -Name OPENAI_API_KEY
```

Das erzeugt lokal `.secrets/local/OPENAI_API_KEY.dpapi.txt`. Die Datei ist nur für deinen
Windows-Benutzer entschlüsselbar und wird nicht committed.

## Lokale npm-Konfiguration

Standardmäßig erzeugt `scripts/Invoke-NpmSafe.ps1` für npm-Aufrufe eine temporäre, leere
User-Konfiguration unter `tmp/`, damit globale `.npmrc`-Einträge nicht in Build/Release
hineinwirken.

Falls später ein privater npm-Feed nötig wird, lege lokal eine Datei unter
`.secrets/local/npmrc` oder DPAPI-verschlüsselt unter `.secrets/local/npmrc.dpapi.txt` ab.
Der Inhalt wird nur in eine temporäre npmrc-Datei unter `tmp/` kopiert und nicht ausgegeben.
Veraltete `always-auth`-Zeilen werden dabei bewusst entfernt.

## Regeln

- Keine echten Werte in Markdown, Logs, Prompts oder Commits kopieren.
- Keine `.npmrc`, `.env`, Datenbanken, Dumps oder Logs committen.
- Für öffentliche Releases weiterhin Clean Snapshot + Security-Gate verwenden.
