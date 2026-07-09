# Report: RUN-50 SecretSafety/UploadZip-Hotfix

## Ergebnis

0.50.2 stabilisiert die verschachtelten Run-Bundles des Release-Candidate-Laufs. Der SecretSafety-Selftest erstellt seinen Run-Ordner jetzt selbst, `New-RunLogBundle.ps1` gibt Pfade ueber die Pipeline aus und `Invoke-ReleaseCandidateReadiness.ps1` validiert den Upload-ZIP-Pfad.

## Geaenderte Dateien

- `scripts/Invoke-SecretSafetyReadiness.ps1`
- `scripts/Invoke-ReleaseCandidateReadiness.ps1`
- `scripts/New-RunLogBundle.ps1`
- `tests/SchachTurnierManager.Application.Tests/OperationalGuardTests.cs`
- Versions-/Doku-Dateien

## Tests

Vorgesehen: `scripts/Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup`. Erwartung: `secret-safety` OK und am Ende ein nicht-leeres `UPLOAD_ZIP=...`.

## Scope

Keine fachliche Turnier-, Pairing-, Wertungs-, Persistenz- oder UI-Logik geaendert.
