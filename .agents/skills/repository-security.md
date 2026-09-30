# Skill: Repository Security

SECURITY-PATTERN-FILE: Diese Datei dokumentiert Sicherheitsregeln und darf Blocklist-Beispiele nennen, aber keine echten Secrets enthalten.

Ziel: Das Repository bleibt clean-snapshot-fähig und enthält keine lokalen Daten, Tokens, Dumps oder Arbeitsumgebungs-Abhängigkeiten.

## Regeln

- Echte Secrets nur lokal unter `.secrets/local/` oder legacy `secrets/local/`.
- Lokale Secrets werden per Windows-DPAPI (`ConvertFrom-SecureString`) gespeichert und bleiben gitignored.
- `.npmrc`, `.env`, Datenbanken, Logs, ZIP/EXE, `output/`, `tmp/`, `node_modules/`, `bin/`, `obj/` niemals committen.
- Screenshots, Bildschirmaufnahmen, UI-Captures und andere visuelle Laufartefakte bleiben lokal. Kein Agent legt ein Ausweich-Repository/Gist an und nutzt kein fremdes oder oeffentliches Ziel als Bild-/Artefakt-Host.
- Jede Ausnahme fuer ein visuelles Artefakt braucht eine aktuelle Owner-Freigabe, die genau Artefakt und Ziel nennt; Firmen-/TFS-/interne Inhalte sind von externer Veroeffentlichung ausgeschlossen.
- `NEXT_PROMPT.md` bleibt lokal-only, weil dort Maschinenpfade oder Handoff-Hinweise stehen können.
- Vor Commit: `scripts/Test-GitCommitSafety.ps1` und danach `scripts/Commit-If-Green.ps1`.
- Öffentliche Veröffentlichung nur über Clean Snapshot, nicht direkt aus historischer Git-Historie.

## Secret-Selftest

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-SecretSafetyReadiness.ps1
```
