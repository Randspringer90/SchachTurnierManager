# BERGFEST_MVP_PLAN.md

Einsatzplan für den ersten praktischen Einsatz des SchachTurnierManager am
**Freitag** als Bergfest-/Freestyle-Würfelschach-Prototyp.

Stand: 2026-06-18. Basis-Commit: `2b92d68` (lokal, noch nicht gepusht).
Fokus: praktische Turnierdurchführung, nicht Vollständigkeit.

## Turnier-Eckdaten
- Format: Schweizer System, **5 Runden**, ca. 10:00–13:00 Uhr.
- Charakter: Bergfest / Freestyle-Würfelschach (lockerer Modus, casual).
- Teilnehmer: erwartet ~8–12.
- Betrieb: rein lokal (kein Internet nötig, keine Cloud).

## MVP-Pflicht (Freitag) — Status

| # | Anforderung | Status | Umsetzung |
|---|-------------|--------|-----------|
| 1 | Teilnehmer manuell/synthetisch erfassen | ✅ vorhanden | Dashboard + `POST /players`, CSV-Import, Demo-Skript |
| 2 | 5 Runden Schweizer System | ✅ vorhanden | `SwissPairingEngine`, `PlannedRounds=5` |
| 3 | Paarungen erzeugen/anzeigen/drucken/exportieren | ✅ vorhanden | Vorschau, CSV, HTML-Rundenblatt |
| 4 | Ergebnisse eingeben und korrigieren | ✅ vorhanden | `POST .../boards/{n}/result` (überschreibt = Korrektur) |
| 5 | Tabelle mit Punkten, Buchholz, Cut-Buchholz | ✅ vorhanden | `StandingsCalculator`, Tabellen-CSV/HTML |
| 6 | Bye/spielfrei robust | ✅ vorhanden + getestet | `Pairing.Bye`, Dry-Run-Test 11 Spieler |
| 7 | Lokale Speicherung/Snapshot/Backup nach jeder Runde | ✅ Autosave + Backup-Export | SQLite-Autosave je Mutation, JSON-Export/Import |
| 8 | Demo-/Dry-run mit 8–12 synthetischen Spielern | ✅ neu | `scripts/New-DemoTournament.ps1` |
| 9 | Kurzes Runbook Freitag | ✅ neu | `docs/BERGFEST_MVP_RUNBOOK.md` |
| 10 | Papier-/CSV-Fallback | ✅ neu dokumentiert | Runbook + Checkliste, CSV/HTML-Druck |

## Architektur-Kurzüberblick (relevant für den Einsatz)
- **Domain**: Paarungen (`SwissPairingEngine`), Wertungen (`StandingsCalculator`),
  Export (`TournamentExportFormatter`), Qualitätsprüfung (`PairingQualityAnalyzer`).
- **Application**: `TournamentService` orchestriert; speichert nach **jeder** Mutation.
- **Infrastructure**: `SqliteTournamentStore` → SQLite-Datei (Autosave).
- **WebApi**: Minimal-API auf `http://localhost:5088`, REST-Endpunkte für alles.
- **WebApp**: React/Vite-Dashboard auf `http://localhost:5173` (Dev) bzw. eingebettet im
  Portable-Paket.

## Persistenz / Datensicherheit
- Datenbank: `%LocalAppData%\SchachTurnierManager\SchachTurnierManager.sqlite`.
- **Autosave**: Jede Aktion (Spieler, Auslosung, Ergebnis, Korrektur) wird sofort
  in SQLite geschrieben — es gibt keinen „Speichern“-Knopf, nichts geht durch einen
  Absturz verloren außer der gerade nicht bestätigten Eingabe.
- **Manueller Snapshot/Backup pro Runde**: `GET /api/tournaments/{id}/export/json`
  → Datei sichern (siehe Runbook). Wiederherstellen via `POST /api/tournaments/import`.

## Bewusste Einschränkung (wichtig für Freitag)
Die Swiss-Auslosung ist heuristisch. In **frühen Runden** sind Wiederholungspaarungen
(Rematches) zuverlässig ausgeschlossen. In **späten Runden kleiner Felder** kann die
Auslosung in seltenen Fällen ein Rematch erzwingen. Das ist **nie still**: Die App
markiert es in der Paarungsqualität als **kritisch** (`RematchCount > 0`).

Mitigation (im Runbook beschrieben):
1. Vor dem Auslosen **„Vorschau nächste Runde“** ansehen — Qualitätswert/Severity prüfen.
2. Bei „kritisch“ die betroffene Paarung per **manueller Paarung** (Override) korrigieren.
3. Der Override wird auditiert.

Eine vollständige FIDE-Dutch-Rematch-Vermeidung ist Roadmap (P3), kein Freitag-Blocker:
Für ein 5-Runden-Bergfest mit ~10 Leuten ist der Vorschau-+-Override-Workflow ausreichend.

## Turniermodus-Label & Startstellungen (Freestyle/Würfelschach)
Billig integriert, ohne Modelländerung:
- **Modus-Label**: in den Turniernamen schreiben, z. B. „Bergfest Freestyle-Würfelschach“.
- **Startstellung pro Brett/Runde**: Beim manuellen Paarungs-Override gibt es ein
  Notizfeld (`Notes`) pro Brett — dort die ausgewürfelte Chess960-Startstellung
  (z. B. Position-Nr. oder FEN-Kürzel) eintragen. Die Notiz erscheint in CSV-Export
  und HTML-Rundenblatt (Spalte „Hinweise“).

## Out of Scope für Freitag
- Keine FIDE-Dutch-Vollimplementierung, keine externen Spielerdaten-Provider nötig.
- Kein PR/Release/Deployment, kein Force-Push.
- Keine großen Refactorings, keine Massenformatierung.

## Verwandte Dokumente
- `docs/BERGFEST_MVP_RUNBOOK.md` — Schritt-für-Schritt am Turniertag.
- `docs/FRIDAY_BERGFEST_CHECKLIST.md` — kompakte Abhakliste + Fallback.
