# Handoff 0.29.0 - Korrektur- und Eingriffsübersicht

## Ziel

v0.29.0 ergänzt ein Dashboard-Panel, das Turnierleiter vor Aushang, Veröffentlichung und nächster Auslosung auf manuelle Eingriffe und organisatorische Prüfpunkte hinweist.

## Enthalten

- Korrektur- und Eingriffsübersicht im Dashboard.
- Erkennung und Anzeige von:
  - manuellen Paarungen,
  - gesperrten Runden,
  - geprüften Runden,
  - vollständigen, aber ungeprüften Runden,
  - inaktiven/zurückgezogenen Teilnehmern,
  - Bye/spielfrei und kampflosen/Sonderergebnissen.
- Status-Badge: kein Turnier, unauffällig, prüfen, kritisch.
- Schnellzugriffe:
  - letzte Runde drucken,
  - Turnierbericht öffnen,
  - Paarungen CSV.

## Nicht geändert

- Keine Änderung der Auslosungslogik.
- Keine Änderung der Wertungsberechnung.
- Keine Änderung am Speicherformat.
- Noch kein persistentes Audit-Log; die Übersicht ist aus dem aktuellen Turnierzustand abgeleitet.

## Nachkontrolle

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1