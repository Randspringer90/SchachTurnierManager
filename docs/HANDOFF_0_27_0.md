# Handoff v0.27.0 – Bye- und Kampflos-Audit

## Ziel

v0.27.0 ergänzt ein Dashboard-Panel für spielfreie und kampflose Bretter. Turnierleiter sehen dadurch schneller, welche Runden betroffen sind und wie diese Bretter in Wertungen und Exporte eingehen.

## Enthalten

- Versionen auf 0.27.0 gesetzt.
- Neue Helfer für Bye-/Kampflos-Zählung und Auditzeilen.
- Neues Dashboard-Panel „Bye- und Kampflos-Audit“.
- Kennzahlen: Bye/spielfrei, kampflos, betroffene Runden, sichtbare Fälle.
- Tabelle mit Runde, Brett, Spielern, Ergebnis, Art und Wertungswirkung.
- Schnellaktionen: aktuelle Runde drucken, Paarungen CSV, Turnierbericht öffnen.
- CSS für Status-Badges, Warnungen und Audit-Tabelle.

## Nicht geändert

- Keine Änderung an Auslosungslogik.
- Keine Änderung an Wertungsberechnung.
- Keine Änderung an Persistenz oder Datenmodell.

## Erwartete Checks

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1