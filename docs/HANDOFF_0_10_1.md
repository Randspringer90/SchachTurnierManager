# Handoff 0.10.1 - Externe Spielersuche stabilisieren

## Ziel

Dieser Patch stabilisiert den neuen externen Spielerdaten-Block aus v0.10.0. Schwerpunkt ist Testbarkeit: reale FIDE-Daten sollen nutzbar sein, ohne den normalen Build von Internetzugriffen abhängig zu machen.

## Enthalten

- Snapshot-Tests für Marco Geißhirt als bekannten Spieler:
  - FIDE-Kontext mit FIDE-ID `4610563`
  - DSB/DeWIS-Kontext als Mapping-Snapshot
  - ThSB-Kontext als Regional-/Vereins-Snapshot
- Optionaler Live-Test `LiveExternalPlayerLookupTests`:
  - Standardmäßig ohne Internetzugriff effektiv inaktiv.
  - Aktivierung über `STM_RUN_LIVE_LOOKUP_TESTS=1`.
- Smoke-Skript:
  - `scripts/Run-ExternalLookupSmoke.ps1`
  - prüft laufendes Backend, Providerliste und FIDE-ID-Lookup.
- Version auf `0.10.1`.

## Warum Snapshot + Live-Test?

Normale Unit Tests müssen stabil und offline laufen. FIDE/DSB/ThSB können ihre Webseiten, API-Antworten, Ratenbegrenzung oder Erreichbarkeit jederzeit ändern. Darum:

- Unit Tests: feste Snapshot-Daten, schnell und stabil.
- Live-/Smoke-Tests: manuell oder per opt-in, wenn Internet und Backend verfügbar sind.

## Lokale Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.10.1.ps1"
```

## Optionaler FIDE-Smoke-Test

Backend/Frontend starten:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Start-Dev.ps1"
```

Dann in einem zweiten Terminal:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId 4610563
```

Optional inklusive Live-xUnit:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId 4610563 -RunLiveTests
```

## Nächster Schritt

v0.11.0 sollte die DSB/DeWIS-Anbindung konkretisieren:

1. Offiziellen API-Zugang bzw. erlaubte Schnittstelle prüfen.
2. DTOs und Provider-Contract erweitern.
3. DWZ + Index + Verein + Verband abrufen.
4. ThSB als Filter auf Verband/Verein/Region modellieren, sofern keine eigene offizielle ThSB-API existiert.
