# Gradle-Wrapper-Provenienz (Android-App)

Die Android-Begleit-App vendort den offiziellen Gradle-Wrapper. Dieser Eintrag
bindet die getrackten Wrapper-Dateien an ihre Herkunft und ihren Inhalt, damit
Manipulationen auffallen und das zentrale BAT-Fleet-Gate den Batch-Launcher
eindeutig zuordnen kann.

## Gebundene Dateien

| Datei | Zweck |
|---|---|
| `src/SchachTurnierManager.WebApp/android/gradlew` | POSIX-Wrapper-Launcher |
| `src/SchachTurnierManager.WebApp/android/gradlew.bat` | Windows-Wrapper-Launcher |
| `src/SchachTurnierManager.WebApp/android/gradle/wrapper/gradle-wrapper.properties` | Distributionsbindung |
| `src/SchachTurnierManager.WebApp/android/gradle/wrapper/gradle-wrapper.jar` | Wrapper-Bootstrap |

## Herkunft und Version

- Gradle-Version: **8.11.1** (`distributionUrl=https://services.gradle.org/distributions/gradle-8.11.1-all.zip`)
- `validateDistributionUrl=true` bleibt aktiv: Der Wrapper akzeptiert nur die
  offizielle Gradle-Distributionsquelle.
- `gradlew.bat` ist der unveraenderte Standard-Wrapper aus der
  Gradle-8.11.1-Distribution (Capacitor-7-Android-Template).

## Inhaltsbindung `gradlew.bat`

- Git-Blob (LF, wie getrackt): `9d21a21834d5195c278ba17baec3115b2aaab06e`, 2872 Bytes
- Working-Tree (CRLF via Git-EOL-Konvertierung): SHA-256
  `57931B17DD228E5C24DAC90E815D0BF82477E831A4618DFAB4136F5446B42A9F`, 2966 Bytes

## Zentrale BAT-Fleet-Registrierung

Der Launcher ist im zentralen Register
(`WS-KFM-Codex-Zentrale/config/bat-test-registry.json`) als genau **ein**
Einzeleintrag mit exaktem relativem Pfad, Content-SHA256 und versionsgebundener
Funktions-Evidence registriert. Es existiert keine generische Allowlist fuer
BAT-, Wrapper- oder Binaerdateien; Inhaltsdrift fuehrt zu
`REGISTRY_HASH_STALE` und blockiert den Commit fail-closed.

Bei einem Gradle-Upgrade muss die Registrierung mit dem neuen Wrapper-Inhalt
und frischer Evidence aktualisiert werden
(`WS-KFM-Codex-Zentrale/scripts/Update-KFMBatchRegistryRepo.ps1`).
