# ADR-0006: Persistenz v2 – Revision je Turnier, Schemaversion, Liste ohne Snapshot

- Status: angenommen (2026-11-25), Umsetzung Stufe A1a

## Kontext
Die Architekturprüfung vom 2026-11-24 nennt drei Mängel der Persistenzhülle: keine Revision je Turnier
(Clients erkennen veraltete Stände nur durch Vollvergleich), keine Schemaversion und kein
Migrationsmechanismus (`EnsureCreated`), und eine Turnierliste, die alle Snapshots vollständig lädt.

## Entscheidung
1. **Revision:** `TournamentState.Revision` wird ausschließlich vom Speicher vergeben und erhöht sich bei jeder
   inhaltlichen Änderung um eins. Ein wiederholter, wirkungsloser Schreibversuch (idempotente Wiederholung)
   lässt Zeile, Zeitstempel und Revision unverändert. Die Revision gehört zur lokalen Datenbank; der Wert aus
   einer importierten Sicherung wird nicht übernommen.
2. **Schemaversion:** `PRAGMA user_version` der SQLite-Datei. `DatabaseSchemaMigrator` legt neue Datenbanken
   direkt in der aktuellen Version an und hebt bestehende an. Vor einer Schemaänderung an einer bestehenden
   Datei entsteht über die SQLite-Online-Sicherung eine vollständige Kopie unter `<Datenverzeichnis>/backups/`
   (`vor-schema-<alt>-auf-<neu>-<Zeit>.sqlite`). Eine Datenbank mit höherer Version wird unverändert abgelehnt
   (`DATABASE_SCHEMA_NEWER`). Migrationen schreiben den Turnier-Snapshot (JSON) nie um.
3. **Listenspalten (Schema 1):** `Revision`, `PlayerCount`, `RoundCount`, `Format` neben dem Snapshot.
   `GET /api/tournaments/summaries` liefert daraus eine Liste ohne Teilnehmerdaten; ein beschädigter Snapshot
   blockiert weder Migration noch Liste.
4. **Frische Daten erkennen:** `GET /api/tournaments/{id}` sendet `ETag: "<id>-<revision>"` und beantwortet
   `If-None-Match` mit `304`, solange sich nichts geändert hat.

## Folgen
- Bestehende Datenbanken und Sicherungen bleiben lesbar; alte Snapshots ohne `revision` erhalten Revision 1.
- `GET /api/tournaments` (vollständige Liste) bleibt vorerst bestehen, bis die WebApp auf die Zusammenfassung
  umgestellt ist (Paket A2/A5).
- Offen (A1b): Audit-Journal und Ergebnis-Quittungen in eigene Tabellen; allgemeine `If-Match`-Prüfung für
  schreibende Endpunkte.
