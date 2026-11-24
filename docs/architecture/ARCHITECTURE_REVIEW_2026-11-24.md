# Architekturprüfung 2026-11-24

Geprüft wurde der tatsächliche Code des lokalen Kandidaten (Basis `d168a5a`), nicht das dokumentierte
Zielbild. Zahlen sind am Code gemessen. Urteil und Umbauplan stehen in Abschnitt 3 und 4.

## 1. Ist-Architektur

```
WebApp (React 19, Vite, TS)      Android-Begleit-App (Java, WebView-Hülle, 791 Zeilen)
        │  HTTP/JSON                         │ HTTP (Health, lädt WebApp)
        ▼                                    ▼
WebApi (ASP.NET Core Minimal API, 62 Endpunkte in Program.cs, LocalApiAccessGuard)
        ▼
Application (TournamentService: 1875 Zeilen, 49 öffentliche Methoden; ExternalPlayerLookupService)
        ▼
Domain (63 Dateien, 8592 Zeilen: Paarung, Wertung, Import/Export-Codecs, Audit)
        ▲
Infrastructure (EF Core SQLite: 1 Tabelle `tournament_snapshots`; FIDE-Anbindung; Datei-Audit-Spiegel)
```

| Schicht | Dateien / Zeilen | Befund |
|---|---|---|
| Domain | 63 / 8592 | Keine Projektreferenzen, reine Fachlogik, 683 Domain- und 13 Golden-Tests. Größte Datei `TournamentExportFormatter.cs` (1021). |
| Application | 10 / 2301 | Fast alles in `TournamentService.cs`. |
| Infrastructure | 12 / 1098 | Snapshot-Speicher, FIDE-Katalog, Audit-Spiegel. `EnsureCreated`, keine Schemaversion. |
| WebApi | 4 / 1733 | `Program.cs` 1300+ Zeilen; 34 gleichartige `catch`-Blöcke, 53 manuelle Fehlercode-Abbildungen. |
| WebApp | 54 / ~12300 | `App.tsx` 4108 Zeilen, 74 `useState`, 33 asynchrone Handler, 41 API-Aufrufe. |
| Mobile | 5 Java-Dateien | Dünne Hülle ohne eigene Fachlogik. |

Abhängigkeitsrichtung: Domain ← Application ← Infrastructure ← WebApi, keine Zyklen. Dienste sind
`Scoped`, der `DbContext` wird nicht zwischen Anfragen geteilt. Jede Mutation läuft in einer
serialisierbaren SQLite-Transaktion (Lesen–Ändern–Schreiben), dadurch keine verlorenen Updates.

## 2. Bewertung

### Tragfähig (bleibt)
- **Domain**: sauber isoliert, gut getestet, enthält das eigentliche Vermögen (Schweizer System,
  FIDE-Dutch, Berger-Plan, Wertungen). Ein Neuschreiben würde geprüfte Regeln gefährden.
- **Modularer Monolith mit lokaler SQLite** (ADR-0001): passt zum Vereinsbetrieb ohne Internet.
- **Atomare Mutationen** und idempotente Offline-Ergebnisse (ADR-0002).
- **Clients ohne Fachlogik**: WebApp und Android rechnen keine Paarungen oder Wertungen.

### Strukturelle Mängel, die den restlichen Backlog blockieren
| Nr. | Mangel | Beleg | Folge |
|---|---|---|---|
| S1 | Keine API-Vertragsschicht: Endpunkte liefern das interne Aggregat. `GET /api/tournaments` gibt **alle** Turniere vollständig zurück (Spieler, Audit-Journal, Quittungen). | `Program.cs:288`, `SqliteTournamentStore.List` | Laufzeit wächst mit der gesamten Historie; Zuschauer-/Handyansichten können keine Felder ausblenden (Datenschutz); jede Modelländerung bricht die API. |
| S2 | Keine Aggregat-Revision und keine Schemaversion im Snapshot. | `TournamentState`, `TournamentSnapshot` | Clients erkennen veraltete Stände nur durch Vollvergleich (Ursache der „veralteten Projektionen“ aus STM-REV-001); keine allgemeine Konfliktprüfung; Datenmigration nur über tolerantes JSON. |
| S3 | Audit-Journal und Ergebnis-Quittungen liegen **im** Aggregat. | `TournamentState.AuditJournal`, `ResultMutationReceipts` | Jede Ergebniseingabe schreibt das gesamte, stetig wachsende JSON neu; Journal ist nicht unabhängig vom Turnierstand gesichert. |
| S4 | Kein Rollenmodell: nur „eigener Rechner“ oder „LAN-Token = alles“. | `LocalApiAccessGuard` | Zuschaueransicht, mobile Ergebniseingabe, Tablet-Turnierleitung (STM-MOB-003…009, STM-UX-012) sind nicht sicher umsetzbar. |
| S5 | Übergroße Einheiten: `TournamentService`, `Program.cs`, `App.tsx`. | Zeilenzahlen oben | Hohe Kopplung, schwer testbar, Zustandsfehler im Frontend (asynchrone Dialoge, Doppelklicks). |
| S6 | Kein Migrationsmechanismus (`EnsureCreated`). | `Program.cs:118` | Neue Tabellen (S3, Serien, Mannschaften) lassen sich bei Bestandsdatenbanken nicht nachziehen. |
| S7 | Nur Einzelturnier-Aggregat. | `ITournamentStore` | Serien-/Saisonwertung (STM-FACH-009) braucht ein turnierübergreifendes Aggregat; Mannschaftsturniere (STM-FACH-004) brauchen Erweiterungen im Turniermodell. |

### Kleinere Punkte
- Fachfehler sind `InvalidOperationException` mit Fehlercode-Metadaten und deutschem Text; funktional
  ausreichend, eine eigene Ausnahmeklasse wäre klarer.
- Datenaktualisierung im Browser per Abfrage aller Turniere; kein Push-Kanal.

## 3. Urteil

**Kein vollständiges Neuschreiben.** Kern (Domain, Schichtung, lokale Datenhaltung) ist geeignet.
Für Mehrgerätebetrieb, Rollen, Mobile, Serien und Mannschaften ist die **Hülle um den Kern** nicht
geeignet und wird umgebaut: Persistenz-Hülle, API-Vertrag, Zugriffsmodell, Application-Schnitt, Frontend.

Vergleich der Wege:
| Weg | Aufwand | Risiko | Bewertung |
|---|---|---|---|
| Alles neu schreiben | sehr hoch | hoch (Regelverlust, Datenmigration) | abgelehnt |
| So lassen, Funktionen anbauen | gering | hoch (S1–S4 verschärfen sich mit jedem Gerät) | abgelehnt |
| Gezielter Umbau in Paketen, Domain unverändert | mittel | gering, je Paket testbar | **gewählt** |

## 4. Zielbild und Umbaupakete

```
Clients ── HTTP ──► WebApi: Endpunktgruppen + Rollenprüfung + zentrale Fehlerabbildung
                        │   Vertragsschicht (DTOs, Zusammenfassungen, öffentliche Projektionen, ETag/Revision)
                        ▼
                    Application: Anwendungsfälle je Bereich (Teilnehmer, Runden, Ergebnisse, Import/Export, Audit)
                        ▼
                    Domain (unverändert)
                        ▲
                    Infrastructure: tournament_snapshots (+ revision, schema_version)
                                    audit_journal (append-only), result_receipts, device_sessions
                                    Schemaversion über PRAGMA user_version, Sicherung vor Migration
```

| Paket | Inhalt | Behebt | Reihenfolge |
|---|---|---|---|
| A1 Persistenz v2 | Schemaversion + Migrationsläufer mit Sicherung; `Revision` je Turnier; Audit-Journal und Quittungen in eigene Tabellen (gleiche Transaktion); Turnierliste aus Spalten statt JSON | S2, S3, S6 | 1 |
| A2 API-Vertrag | Zusammenfassungs-Endpunkt, DTOs, öffentliche Projektionen ohne personenbezogene Zusatzdaten, `ETag`/`If-Match`, zentrale Fehlerabbildung, Endpunktgruppen statt `Program.cs` | S1, Teil S5 | 2 |
| A3 Zugriffsmodell | Gerätekopplung per Einmalcode, Rollen `director`/`results`/`spectator` (ADR-0004) | S4 | 3 |
| A4 Application-Schnitt | `TournamentService` in Anwendungsfälle je Bereich hinter gleicher Fassade | S5 | 4 |
| A5 Frontend | `App.tsx` in Featurebereiche mit zentralem Turnierzustand und API-Hooks (STM-FE-015); Aktualisierung über Revision | S5, S2 | 5 |
| A6 Erweiterte Aggregate | Serien, Mannschaften | S7 | nach A1–A3 |

Regeln für alle Pakete: Domain-Tests bleiben unverändert grün; Bestandsdatenbanken und Sicherungen
alter Versionen müssen weiter lesbar sein (Migrationstests mit Altständen); jede Stufe einzeln
lauffähig; alte API-Routen bleiben, bis die WebApp umgestellt ist.
