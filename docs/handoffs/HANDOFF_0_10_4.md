# Handoff 0.10.4 - Stabilisierung externe Lookup-Tests

## Ziel

Fix-Forward nach rotem Commit `e37ad87`: Die Infrastructure-Tests dürfen nicht direkt von der Sichtbarkeit konkreter DSB-/ThSB-Providerklassen abhängen.

## Änderungen

- `LiveExternalPlayerLookupTests` referenziert keine konkreten DSB-/ThSB-Providerklassen mehr.
- FIDE-Live-Test bleibt optional über `STM_RUN_LIVE_LOOKUP_TESTS=1`.
- Offline-Snapshots für FIDE/DSB/ThSB bleiben als stabiler Testanker erhalten.
- Versionsanzeige auf `0.10.4` vereinheitlicht.
- Neues Nachkontrollskript `scripts/After-Apply-V0.10.4.ps1`.

## Erwartete Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.10.4.ps1"
```

Danach bei grünem Lauf:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize external lookup live tests"; git push
```
