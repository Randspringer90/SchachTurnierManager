# Report 2026-07-09 – ChatGPT: NpmSafe-Flags statt PowerShell-Argumentfallen

## TL;DR

0.42.5 brachte den gewuenschten Run-Log-Bundler, aber `--fund=false` wurde beim Skriptaufruf
als PowerShell-Parameter interpretiert. 0.42.6 ersetzt diese fragile Uebergabe durch robuste
Schalter `-NoAudit` und `-NoFund` im npm-Safe-Runner. Keine fachliche Turnierlogik geaendert.

## Ursache

Der Aufruf

```powershell
-NpmArguments @('--no-audit','--fund=false')
```

kann bei Skriptaufrufen so expandieren, dass `--fund=false` nicht als Wert, sondern als
Parametername interpretiert wird.

## Aenderungen

- `scripts/Invoke-NpmSafe.ps1`: neue Schalter `-NoAudit`, `-NoFund`; daraus werden intern
  `--no-audit` und `--fund=false` fuer npm erzeugt.
- `scripts/Invoke-ReleaseGate.ps1`: npm install nutzt `-NoAudit -NoFund`.
- `scripts/Pack-Portable.ps1`: npm install nutzt `-NoAudit -NoFund`.
- `scripts/Publish-DesktopApp.ps1`: npm install nutzt `-NoAudit -NoFund`.
- Version: 0.42.5 -> 0.42.6.
- `CHANGELOG.md`, `PLANS.md`, `docs/ai/PROMPTS.md` fortgeschrieben.

## Tests

Durch Nutzer lokal auszufuehren:

- `Invoke-ReleaseGate.ps1 -SkipPack` ueber `Invoke-LoggedCommand.ps1`
- direkter `Invoke-NpmSafe.ps1 -NpmCommand install -NoAudit -NoFund`
- direkter `Invoke-NpmSafe.ps1 -NpmCommand run -NpmScript build`

## Naechster Schritt

Wenn 0.42.6 gruen ist: aktuelle Basis per Commit sichern, danach RUN-05 Installer-Test.
