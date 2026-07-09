# Report 2026-07-09 – ChatGPT: npm-Pinning und Run-Logging

## TL;DR

0.42.4 zeigte: .NET-Build und Tests sind gruen, `npm run build` ueber `Invoke-NpmSafe.ps1`
ist gruen, aber `npm ci` landet auf der Windows-Workstation bei der npm-config-Hilfe.
Dieser Patch vermeidet `npm ci`, pinnt die WebApp-Abhaengigkeiten exakt auf den bestehenden
Lockfile-Stand und ergaenzt Hilfsskripte fuer ruhige, zipbare Run-Logs.

## Geaenderte Dateien

- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`
- `src/SchachTurnierManager.WebApi/Program.cs`
- `scripts/Invoke-ReleaseGate.ps1`
- `scripts/Pack-Portable.ps1`
- `scripts/Publish-DesktopApp.ps1`
- `scripts/Invoke-LoggedCommand.ps1`
- `scripts/New-RunLogBundle.ps1`
- `scripts/README.md`
- `CHANGELOG.md`
- `PLANS.md`
- `docs/ai/PROMPTS.md`
- `docs/ai/prompts/2026-07-09-chatgpt-npm-pinning-runlogs.md`
- `docs/ai/reports/2026-07-09-chatgpt-npm-pinning-runlogs.md`

## Inhalt

- WebApp-Dependencies von `latest` auf konkrete Versionen aus `package-lock.json` gepinnt.
- ReleaseGate/Paketierung wieder auf `npm install` gestellt, weiterhin ueber `Invoke-NpmSafe.ps1`.
- npm-Aufrufe mit `--no-audit --fund=false`, um Terminal/Logausgaben zu reduzieren.
- `Invoke-LoggedCommand.ps1`: startet lange Befehle mit kurzer Fortschrittsanzeige und schreibt
  die gesamte Ausgabe in einen Run-Logordner.
- `New-RunLogBundle.ps1`: legt Run-Ordner an bzw. sammelt Git-Status/Diff-Stat und packt alles
  als ZIP.

## Erwartete Verifikation

1. ReleaseGate `-SkipPack` mit neuem Run-Logging ausfuehren.
2. `npm install` via `Invoke-NpmSafe.ps1` direkt testen.
3. `npm run build` via `Invoke-NpmSafe.ps1` direkt testen.
4. Log-Bundle-ZIP hochladen.

## Risiken / Hinweise

- `npm ci` bleibt bewusst nicht der verwendete Pfad, weil es auf der Zielmaschine fehlschlaegt.
- Durch exaktes Pinning ist `npm install` fuer diesen kleinen Frontend-Stack ausreichend stabil.
- Keine fachliche Turnierlogik geaendert.
