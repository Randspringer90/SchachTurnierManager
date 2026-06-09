# Handoff v0.26.0 – Rundenabschluss-Checkliste

## Ziel

v0.26.0 ergänzt ein Turnierleiter-Panel im Dashboard, das den Zustand vor Aushang, Veröffentlichung und nächster Auslosung sichtbar macht.

## Enthalten

- Versionen auf 0.26.0 gesetzt.
- Neue Rundenabschluss-Checkliste im Dashboard.
- Kennzahlen: Runden, vollständige Runden, offene Bretter, kampflose Bretter, ungeprüfte fertige Runden, gesperrte Runden und Diagnosehinweise.
- Kompakte Tabelle der wichtigsten offenen/kampflosen/auffälligen Bretter.
- Schnellaktionen für aktuelle Runde, Turnierbericht und Tabellen-CSV.
- CSS für Status-Badges, Warnungen und Review-Tabelle.

## Nicht geändert

- Keine Änderung an Swiss-/Round-Robin-Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung an Speicherformaten.

## Erwartete Checks

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1