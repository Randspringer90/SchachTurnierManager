# Aktueller Zusatz 0.12.0

- Externe Profile können auf Dubletten geprüft und als neuer oder bestehender Teilnehmer angewendet werden.
- DSB/DeWIS bleibt nächster Integrationsblock nach Klärung der offiziellen Schnittstelle.

# Externe Spielersuche testen

## Grundsatz

Externe Spielerdaten sind volatil. Webseiten und Schnittstellen können sich ändern. Deshalb trennt das Projekt strikt:

- **Unit-/Snapshot-Tests:** offline, stabil, schnell.
- **Live-/Smoke-Tests:** optional, bewusst manuell aktiviert.

## Synthetischer Testspieler

Für Offline-/Snapshot-Tests verwendet das Projekt einen synthetischen Datensatz:

- FIDE-ID: `99900123`
- Name bei FIDE: `Weissbach, Lina`
- Geburtsjahr: `1990`
- Federation: `Germany`
- Vereins-/Regionalbezug: `Beispiel SV` / Thüringen

Die Daten sind bewusst fiktiv. Live-Tests sollen keine fragilen exakten Ratingwerte erzwingen und nur mit bewusst gesetzter echter Test-ID laufen.

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
$env:STM_LIVE_FIDE_ID = "<FIDE-ID bewusst setzen>"
dotnet test --filter "FullyQualifiedName~LiveExternalPlayerLookupTests"
```

## API-Smoke-Test

Wenn das Backend läuft:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId "<FIDE-ID bewusst setzen>"
```

Optional inklusive Live-xUnit:

```powershell
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Run-ExternalLookupSmoke.ps1" -FideId "<FIDE-ID bewusst setzen>" -RunLiveTests
```

## DSB/ThSB

DSB/DeWIS und ThSB sind derzeit bewusst nicht als unkontrollierte Scraper aktiviert. Der nächste fachlich saubere Schritt ist die Klärung der offiziellen API bzw. Registrierung für die DWZ-Schnittstelle. ThSB wird zunächst als Regionalfilter auf DSB/DeWIS vorbereitet.
