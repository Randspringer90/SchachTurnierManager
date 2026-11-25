# ADR-0001: Modularer Monolith mit lokaler SQLite-Datenbank

- Status: angenommen (bestätigt 2026-11-24, beschreibt den bestehenden Stand)

## Kontext
Vereine betreiben Turniere auf einem einzelnen Turnierrechner, häufig ohne verlässliches Internet.
Weitere Geräte (Handy, Tablet, Beamer) greifen im lokalen Netz zu.

## Entscheidung
Ein Prozess (ASP.NET Core) mit klaren Schichten: Domain ← Application ← Infrastructure ← WebApi,
dazu die WebApp (React) und ein Android-Begleitclient als reine API-Clients. Daten liegen in einer
lokalen SQLite-Datei. Keine Microservices, keine Pflicht-Cloud, keine Container-Pflicht.

## Folgen
- Installation ohne Entwicklungswerkzeuge möglich (Setup/Portable, self-contained).
- Alle Schachregeln liegen einmal in der Domain; Clients enthalten keine Paarungs- oder Wertungslogik.
- Geprüfte Abhängigkeitsrichtung (2026-11-24): keine Zyklen; Domain hat keine Projektreferenzen.
- Bekannte Wartungsschulden: übergroße Dateien `WebApp/src/app/App.tsx`, `Application/TournamentService.cs`,
  `WebApi/Program.cs` (siehe STM-FE-015 und Architekturbericht).
