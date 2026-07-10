# Handoff 0.11.3 - FIDE-Testassert endgültig stabilisiert

## Zweck

Fix-Forward für den weiter roten v0.11.x-Stand. Der Test `FidePlayerLookupProviderTests.LookupByIdAsync_ParsesKnownProfileHtml_WithoutInternet` erwartete lokal weiterhin die relative URI `profile/99900123`, obwohl `HttpClient` bei gesetzter `BaseAddress` die absolute URI `https://ratings.fide.com/profile/99900123` an den Handler übergibt.

## Änderungen

- `FidePlayerLookupProviderTests.cs` prüft jetzt robust per `EndsWith("profile/99900123", ...)`.
- `After-Apply-V0.11.3.ps1` ersetzt die alte Assert-Zeile zusätzlich per Regex und bricht früh ab, falls sie weiterhin vorhanden ist.
- Versionen auf `0.11.3` angehoben.

## Nachkontrolle

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\After-Apply-V0.11.3.ps1"
```

Wenn grün:

```powershell
Set-Location "D:\Schach\SchachTurnierManager"; git status; git add .; git commit -m "Stabilize FIDE lookup URI assertion"; git push
```
