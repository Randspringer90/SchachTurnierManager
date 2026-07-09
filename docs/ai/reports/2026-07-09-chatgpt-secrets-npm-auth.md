# Report 2026-07-09 – lokale Secrets und npm-Auth

## TL;DR

Nach dem grünen 0.42.1-Gate wurde die lokale Authentifizierungs-/Secret-Struktur gehärtet:
`.secrets/local/` ist jetzt der bevorzugte gitignored Secret-Ort, `secrets/local/` bleibt als
Legacy-Ablage lesbar. npm-Aufrufe in ReleaseGate/Portable/Desktop laufen über einen Safe-Runner,
der eine isolierte temporäre npmrc unter `tmp/npm-safe/` nutzt und veraltete `always-auth`-Zeilen
entfernt. Keine fachliche Turnierlogik geändert.

## Ausgangspunkt

- Release-Gate 0.42.1: grün (Restore, Build, Tests, Frontend-Build).
- Auffällig: npm-Warnung zu global/userweit gesetztem `always-auth`.
- Bestehendes `secrets/README.md` war vorhanden, aber noch ohne durchgängige `.secrets/local/`-
  Konvention und ohne npm-Safe-Runner.

## Geänderte Dateien

- `.gitignore`
- `.secrets/README.md`
- `AGENTS.md`
- `CHANGELOG.md`
- `PLANS.md`
- `docs/ai/PROMPTS.md`
- `docs/ai/prompts/2026-07-09-chatgpt-secrets-npm-auth.md`
- `docs/ai/reports/2026-07-09-chatgpt-secrets-npm-auth.md`
- `scripts/Invoke-NpmSafe.ps1`
- `scripts/Set-LocalSecret.ps1`
- `scripts/Invoke-ReleaseGate.ps1`
- `scripts/Pack-Portable.ps1`
- `scripts/Publish-DesktopApp.ps1`
- `scripts/README.md`
- `scripts/Test-GitCommitSafety.ps1`
- `secrets/README.md`
- `src/SchachTurnierManager.WebApi/Program.cs`
- `src/SchachTurnierManager.WebApp/package.json`
- `src/SchachTurnierManager.WebApp/package-lock.json`

## Verifikation

Vom ChatGPT-Container aus wurde kein Windows-/dotnet-/npm-ReleaseGate ausgeführt. Erwartete lokale
Verifikation auf der Workstation:

1. `pwsh -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack`
2. Prüfen, dass npm über `[NpmSafe]` läuft und die vorherige `always-auth`-Warnung nicht mehr erscheint.
3. Optional: `pwsh -File .\scripts\Invoke-NpmSafe.ps1 -WorkingDirectory .\src\SchachTurnierManager.WebApp -NpmArguments run,build`
4. `pwsh -File .\scripts\Test-GitCommitSafety.ps1`

## Risiken / Hinweise

- Falls ein privater npm-Feed später wirklich `always-auth` benötigt, muss die npmrc bewusst neu
  bewertet werden. Der Standard entfernt `always-auth`, weil npm es im aktuellen Lauf bereits als
  veraltete/unerwünschte User-Konfiguration meldet.
- DPAPI-Dateien sind Windows-Benutzer-gebunden und nicht zwischen Rechnern portabel.
- Keine echten Secret-Werte in Logs, Prompts oder Reports kopieren.

## Nächster Schritt

Nach grünem Gate: Änderungen committen oder, wenn noch nicht gewünscht, als lokaler Patch stehen
lassen. Danach fachlich weiter mit RUN-05 Installer-Test oder RUN-02 Release-Reife-Prüfung.
