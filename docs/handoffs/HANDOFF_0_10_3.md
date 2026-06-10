# Handoff 0.10.3 - Stabilisierung externe Lookup-Tests

## Ziel

Fix-Forward für v0.10.1/v0.10.2: Die neuen Infrastructure-Tests griffen auf Provider zu, die im Infrastructure-Projekt noch `internal` waren. Dadurch scheiterte `dotnet build` in `SchachTurnierManager.Infrastructure.Tests`.

## Änderungen

- `UnsupportedExternalPlayerLookupProvider` ist jetzt `public abstract`.
- `DsbPlayerLookupProvider` und `ThsbPlayerLookupProvider` sind jetzt `public sealed`.
- `LiveExternalPlayerLookupTests` nutzt die Provider über `IExternalPlayerLookupProvider`.
- FIDE-Live-Test bleibt standardmäßig inaktiv und wird nur über `STM_RUN_LIVE_LOOKUP_TESTS=1` ausgeführt.
- Offline-Snapshot-Test für Marco/FIDE-ID `4610563`, DSB/DeWIS- und ThSB-Ankerdaten bleibt stabil.
- Neues Prüfsript: `scripts/After-Apply-V0.10.3.ps1`.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.10.3.ps1"
```

Wenn grün:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize external lookup infrastructure tests"; git push
```

## Nächster fachlicher Schritt

Nach grünem v0.10.3: DSB/DeWIS-Zugang fachlich/technisch klären und dann den DSB-Adapter aktivieren, ohne fragile HTML-Scraper als Standardweg zu erzwingen.
