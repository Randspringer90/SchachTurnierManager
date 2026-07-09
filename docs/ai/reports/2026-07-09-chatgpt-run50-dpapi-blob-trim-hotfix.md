# Report: RUN-50 DPAPI-Blob-Trim-Hotfix

## Ergebnis

0.50.3 stabilisiert den lokalen DPAPI-Secret-Roundtrip. `Get-LocalSecret.ps1` entfernt abschliessenden Whitespace vor `ConvertTo-SecureString` und liefert bei leeren Dateien eine klare Fehlermeldung. `Set-LocalSecret.ps1` schreibt neue DPAPI-Dateien ohne abschliessende neue Zeile.

## Geaenderte Bereiche

- `scripts/Get-LocalSecret.ps1`
- `scripts/Set-LocalSecret.ps1`
- `scripts/Invoke-SecretSafetyReadiness.ps1`
- `tests/SchachTurnierManager.Application.Tests/OperationalGuardTests.cs`
- Version/Doku/Prompt-/Report-Log

## Nicht geaendert

Keine Turnierlogik, keine externen Provider, keine echten Secrets, kein Push/Release.

## Naechster Schritt

`Invoke-ReleaseCandidateReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup` erneut ausfuehren. Erwartung: `secret-safety` OK und ein nicht-leeres `UPLOAD_ZIP=...`.
