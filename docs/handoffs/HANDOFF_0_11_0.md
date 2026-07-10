# Handoff 0.11.0 - FIDE-Adapter testbar gemacht

## Ziel

Der FIDE-Provider soll nicht nur live manuell prüfbar sein, sondern auch offline reproduzierbar getestet werden.

## Änderungen

- `FidePlayerLookupProvider` akzeptiert jetzt einen injizierten `HttpClient`.
- Standardkonstruktor bleibt für die produktive DI-Registrierung erhalten.
- Offline-Parser-Test mit HTML-Snapshot für `99900123` ergänzt.
- Invalid-ID-Test ergänzt.
- Versionen auf `0.11.0` angehoben.
- Nachkontrollskript `scripts/After-Apply-V0.11.ps1` ergänzt.

## Erwartete Prüfung

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.11.ps1"
```

Erwartung: `dotnet build`, `dotnet test`, Frontend-Build und Portable-Paket grün.

## Nächster Schritt

Danach DSB/DeWIS-Integration konkretisieren: zunächst Schnittstellen-/Registrierungsweg dokumentieren, DTOs vorbereiten und keine unkontrollierten Scraper aktivieren.
