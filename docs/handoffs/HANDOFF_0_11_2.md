# Handoff 0.11.2 - FIDE-Testassert robust fixiert

## Ziel

Fix-Forward für den roten v0.11.1-Stand. Der FIDE-Parser-Test darf nicht mehr auf exakt `profile/99900123` prüfen, weil `HttpClient` bei gesetzter `BaseAddress` die absolute Request-URI `https://ratings.fide.com/profile/99900123` an den Handler übergibt.

## Änderungen

- `FidePlayerLookupProviderTests` prüft robust per `Assert.EndsWith("/profile/99900123", ...)`.
- `After-Apply-V0.11.2.ps1` enthält eine Schutzkorrektur für versehentlich nicht überschriebene alte Assert-Zeilen.
- Versionen auf `0.11.2` gesetzt.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.11.2.ps1"
```

Wenn grün:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize FIDE lookup URI assertion"; git push
```
