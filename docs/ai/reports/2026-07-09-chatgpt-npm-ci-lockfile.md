# Report 2026-07-09 – ChatGPT: npm ci statt npm install bei Lockfile

## TL;DR

0.42.3 hat die npm-Argumentbindung repariert, aber das ReleaseGate brach beim Installationsschritt
weiter ab: `npm install` versuchte unter Windows `n@10.2.0` zu installieren. Der direkte
Frontend-Build ueber `Invoke-NpmSafe.ps1 -NpmCommand run -NpmScript build` war gruen.

## Diagnose

Der WebApp-Root besitzt eine `package-lock.json`. Bei `dependencies` mit `latest` ist
`npm install` nicht streng genug fuer ein Release-Gate, weil es erneut gegen die Registry
aufloesen und den Lockfile veraendern kann. Fuer reproduzierbare Gates und Paketierung ist
`npm ci` der passendere Befehl: installiert exakt aus dem Lockfile.

## Geaenderte Dateien

- `scripts/Invoke-ReleaseGate.ps1`
- `scripts/Pack-Portable.ps1`
- `scripts/Publish-DesktopApp.ps1`
- `src/SchachTurnierManager.WebApi/Program.cs`
- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`
- `CHANGELOG.md`
- `PLANS.md`
- `docs/ai/PROMPTS.md`
- `docs/ai/prompts/2026-07-09-chatgpt-npm-ci-lockfile.md`
- `docs/ai/reports/2026-07-09-chatgpt-npm-ci-lockfile.md`

## Verifikation

Durch Anwender auszufuehren:

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NpmSafe.ps1 -WorkingDirectory .\src\SchachTurnierManager.WebApp -NpmCommand ci
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NpmSafe.ps1 -WorkingDirectory .\src\SchachTurnierManager.WebApp -NpmCommand run -NpmScript build
```

## Risiken / Folgearbeit

- Die `latest`-Dependencies bleiben ein dokumentiertes Reproduzierbarkeitsrisiko. Sie sollten in
  einem eigenen RUN-18/RUN-03-Folgeschritt gepinnt werden.
- Kein Push/Release ohne Freigabe.
