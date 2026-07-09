# Report 2026-07-09 – ChatGPT: npm-Safe-Runner Argumentbindung 0.42.3

## TL;DR

0.42.2 fuehrte npm zwar isoliert aus, aber der mehrteilige Aufruf `-NpmArguments @('run','build')`
konnte unter `pwsh -File` so gebunden werden, dass `build` als positionaler `Root`-Parameter
interpretiert wurde. 0.42.3 ersetzt diesen Aufruf durch explizite Parameter und haelt die
Secret-/npmrc-Isolation bei.

## Ursache

- `Invoke-NpmSafe.ps1` hatte einen `[string[]]$NpmArguments`-Parameter neben optionalen
  positionalen Parametern.
- Beim Aufruf aus Skripten bzw. direkt aus der Konsole wurde `npm run build` nicht stabil als
  Array uebergeben; der zweite Wert konnte in `Root` landen.
- Folge: `Resolve-Path -LiteralPath $Root` suchte nach `build` und brach ab.

## Aenderungen

- `scripts/Invoke-NpmSafe.ps1`
  - `CmdletBinding(PositionalBinding = $false)` ergaenzt.
  - Neue explizite Syntax: `-NpmCommand install` bzw. `-NpmCommand run -NpmScript build`.
  - Optionales `-NpmArguments` bleibt fuer zusaetzliche einfache Argumente erhalten.
  - Fehlertext ergaenzt, falls kein npm-Befehl angegeben wurde.
- `scripts/Invoke-ReleaseGate.ps1`, `scripts/Pack-Portable.ps1`,
  `scripts/Publish-DesktopApp.ps1`
  - Auf neue robuste Syntax umgestellt.
- Version auf 0.42.3 angehoben.
- `CHANGELOG.md`, `PLANS.md`, `docs/ai/PROMPTS.md` fortgeschrieben.

## Tests / Erwartung

Lokal beim Nutzer auszufuehren:

- `Invoke-ReleaseGate.ps1 -SkipPack`
- direkter `Invoke-NpmSafe.ps1 -NpmCommand run -NpmScript build`
- `Test-GitCommitSafety.ps1`

## Risiken

- Kein fachlicher Code wurde geaendert.
- `-NpmArguments @('run','build')` ist nicht mehr die empfohlene Aufrufweise; bestehende interne
  Skripte wurden auf die neue Syntax angepasst.
- Falls externe lokale Notizen noch die alte Syntax enthalten, muessen sie angepasst werden.

## Naechster Schritt

Nach gruenem Gate: 0.42.1/0.42.2/0.42.3 zusammen als lokalen Commit sichern oder direkt den
naechsten kleinen Lauf beginnen (RUN-05 Installer-Test oder RUN-02 Release-Reife-Pruefung).
