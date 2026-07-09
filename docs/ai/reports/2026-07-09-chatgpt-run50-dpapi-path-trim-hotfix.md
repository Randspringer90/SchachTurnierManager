# Report: RUN-50 DPAPI-Pfadtrim-Hotfix

## Ergebnis

- `scripts/Get-LocalSecret.ps1` nutzt jetzt `System.IO.Path.DirectorySeparatorChar` und `AltDirectorySeparatorChar`, um relative Secret-Anzeigepfade zu trimmen.
- Die fehleranfaellige PowerShell-Konvertierung `[char]'\\'` wurde entfernt.
- `OperationalGuardTests` pruefen die robuste Separatorlogik und verhindern die Rueckkehr der fehlerhaften Variante.
- Version auf `0.50.4` angehoben.

## Erwarteter Test

```powershell
pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup
```

Erwartung: `secret-safety` wird gruen; Inno Setup darf weiterhin als dokumentierter Blocker fehlen.

## Scope

Keine fachliche Turnierlogik geaendert.
