# Skill: Release Operations

Ziel: Das Projekt muss eigenständig installierbar, testbar und als Vereins-/Kollegen-Version ausrollbar sein.

## Regeln

- Erst `scripts/Invoke-ReleaseGate.ps1` grün, dann Paketierung.
- Für normale Anwender ist die bevorzugte Ausgabe `output/desktop` bzw. ein Installer aus `installer/`.
- Für ZIP-Übergaben werden Logs in einem eigenen `D:\Temp\<RunName>_<Timestamp>` gesammelt und am Ende als ein ZIP hochgeladen.
- Keine Downloads, Installer, Cloud-Aktionen, Pushes oder Releases ohne ausdrückliche Freigabe.
- Release-Artefakte (`output/`, ZIP, EXE, Logs, DB) werden nicht committed.

## Standard-Gate

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Wenn Inno Setup fehlt, ist das ein dokumentierter Blocker. Die Desktop- und Portable-Pakete bleiben trotzdem prüfbar.
