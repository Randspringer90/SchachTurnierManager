# Report: RUN-51 Kollegeninstallationslauf RunDirectory-/UploadZip-Hotfix

## Ergebnis

- `scripts/Invoke-ColleagueInstallReadiness.ps1` erstellt den Run-Ordner mit `New-ColleagueRunDirectory` selbst.
- `Resolve-UploadZipPath` berechnet das erwartete Upload-ZIP deterministisch.
- `New-RunLogBundle.ps1` wird weiterhin fuer Summary/Gitstatus/ZIP-Erzeugung genutzt, aber seine Pipeline-Ausgabe wird nicht mehr fuer Pfadvariablen ausgewertet.
- `OperationalGuardTests` pruefen die robuste Implementierung.

## Risiken

- Kein fachlicher Scope, keine Turnierlogik geaendert.
- Inno Setup bleibt optional; fehlende lokale Installation wird weiterhin ueber `-AllowMissingInnoSetup` toleriert.
