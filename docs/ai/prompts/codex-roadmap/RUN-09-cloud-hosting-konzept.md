# RUN-09 – Cloud-/Hosting-Konzept (nur Konzept)

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Schriftliches Konzept in `docs/architecture/HOSTING_CONCEPT.md` – **keine Umsetzung,
keine Kosten- oder Cloud-Aktionen.**

## Inhalte
- ASP.NET-Hosting-Optionen vergleichen (eigener Windows-/Linux-Server, verwalteter
  Anbieter); Anforderungen des Backends (SQLite → Serverdatenbank-Migrationspfad).
- Rollenmodell: Turnierleiter, Helfer/Ergebnismelder, Zuschauer; Authentifizierung.
- Öffentliche Links für Paarungen/Tabellen (read-only, ohne Login).
- Backups/Restore im Serverbetrieb.
- Datenschutz (DSGVO): welche personenbezogenen Daten, Rechtsgrundlage,
  Löschkonzept, Impressum/Verantwortlichkeit beim Verein.
- Aufwands-/Risikoschätzung und empfohlener Migrationspfad (lokal bleibt Default).
