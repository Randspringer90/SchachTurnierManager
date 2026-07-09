# Prompt 2026-07-09 – ChatGPT: npm ci statt npm install bei Lockfile

Auftrag aus Terminalausgabe nach 0.42.3:

- ReleaseGate bricht bei `npm install` unter Windows mit `EBADPLATFORM` fuer `n@10.2.0` ab.
- Direkter `npm run build` ueber `Invoke-NpmSafe.ps1` ist erfolgreich.
- Ursache risikoarm beheben, Logging/Doku pflegen, keine fachliche Turnierlogik aendern.

Umsetzung:

- `Invoke-ReleaseGate.ps1`, `Pack-Portable.ps1`, `Publish-DesktopApp.ps1` nutzen bei vorhandener
  `package-lock.json` `npm ci`; ohne Lockfile bleibt `npm install` Fallback.
- Version auf 0.42.4 angehoben und Doku/Prompt-Log/Report fortgeschrieben.
