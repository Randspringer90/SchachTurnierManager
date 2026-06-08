# Externe Spielersuche testen

## Grundsatz

Externe Spielerdaten sind volatil. Webseiten und Schnittstellen können sich ändern. Deshalb trennt das Projekt strikt:

- **Unit-/Snapshot-Tests:** offline, stabil, schnell.
- **Live-/Smoke-Tests:** optional, bewusst manuell aktiviert.

## Bekannter Testspieler

Für die Entwicklung verwenden wir Marco Geißhirt als bekannten Datensatz:

- FIDE-ID: `4610563`
- Name bei FIDE: `Geisshirt, Marco`
- Geburtsjahr: `1990`
- Federation: `Germany`
- Vereins-/Regionalbezug: `Ilmenauer SV` / Thüringen

Die genauen Ratings dürfen sich ändern. Live-Tests sollen daher keine fragilen exakten Ratingwerte erzwingen.

## Snapshot-Tests

Datei:

```text
tests/SchachTurnierManager.Application.Tests/KnownExternalPlayerSnapshotTests.cs
```

Diese Tests prüfen Mapping und Datenmodell, ohne Internetzugriff.


## Offline-FIDE-Parser-Test

Datei:

```text
tests/SchachTurnierManager.Infrastructure.Tests/FidePlayerLookupProviderTests.cs
```

Dieser Test nutzt einen injizierten `HttpClient` mit statischem HTML und prüft, ob der FIDE-Parser Name, ID, Geburtsjahr, Geschlecht sowie Standard-/Rapid-/Blitz-Elo korrekt extrahiert. Dadurch bleibt der Parser auch ohne Internetzugriff testbar.

## Live-FIDE-Test

Datei:

```text
tests/SchachTurnierManager.Infrastructure.Tests/LiveExternalPlayerLookupTests.cs
```

Standardmäßig wird der echte Live-Abruf nicht ausgeführt. Aktivierung:

```powershell
$env:STM_RUN_LIVE_LOOKUP_TESTS = "1"
dotnet test --filter "FullyQualifiedName~LiveExternalPlayerLookupTests"
```

## API-Smoke-Test

Wenn das Backend läuft:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId 4610563
```

Optional inklusive Live-xUnit:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId 4610563 -RunLiveTests
```

## DSB/ThSB

DSB/DeWIS und ThSB sind derzeit bewusst nicht als unkontrollierte Scraper aktiviert. Der nächste fachlich saubere Schritt ist die Klärung der offiziellen API bzw. Registrierung für die DWZ-Schnittstelle. ThSB wird zunächst als Regionalfilter auf DSB/DeWIS vorbereitet.
