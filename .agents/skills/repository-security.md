# Skill: Repository Security

SECURITY-PATTERN-FILE: Diese Datei dokumentiert Sicherheitsregeln und darf Blocklist-Beispiele nennen, aber keine echten Secrets enthalten.

Ziel: Das Repository bleibt clean-snapshot-fähig und enthält keine lokalen Daten, Tokens, Dumps oder Arbeitsumgebungs-Abhängigkeiten.

## Regeln

- Echte Secrets nur lokal unter `.secrets/local/` oder legacy `secrets/local/`.
- Lokale Secrets werden per Windows-DPAPI (`ConvertFrom-SecureString`) gespeichert und bleiben gitignored.
- `.npmrc`, `.env`, Datenbanken, Logs, ZIP/EXE, `output/`, `tmp/`, `node_modules/`, `bin/`, `obj/` niemals committen.
- `NEXT_PROMPT.md` bleibt lokal-only, weil dort Maschinenpfade oder Handoff-Hinweise stehen können.
- Vor Commit: `scripts/Test-GitCommitSafety.ps1` und danach `scripts/Commit-If-Green.ps1`.
- Öffentliche Veröffentlichung nur über Clean Snapshot, nicht direkt aus historischer Git-Historie.

## Secret-Selftest

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-SecretSafetyReadiness.ps1
```
