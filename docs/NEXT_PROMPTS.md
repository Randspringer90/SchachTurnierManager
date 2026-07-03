# NEXT_PROMPTS.md

Konsolidierte, vorbereitete Arbeitsauftraege fuer kommende Entwicklungslaeufe.
Stand: 2026-07-03 (Basis: 0.42.0 Feature-Lauf, Import-/Restore-Haertung lokal getestet).

## Erledigt am 2026-07-03
- Preset-Import fuer Bergfest/lokale Turniere gehaertet:
  `scripts\Import-TournamentPreset.ps1` erzeugt CSV plus JSON-Report, prueft Preset-Schema,
  dokumentiert Rating-Fallbacks und blockiert echte Imports mit Warnungen ohne bewusstes
  `-AllowWarnings`.
- Echter Import nutzt nach Turniererstellung die API-CSV-Vorschau als Gate
  (`players/preview-import.csv`); Dry-run bleibt ohne API-Aenderung.
- `POST /api/tournaments/import` validiert Restore-Snapshots strenger: keine doppelten
  Spieler-IDs/FIDE-/DSB-IDs, keine ungueltigen Runden/Bretter, keine Paarungen gegen
  unbekannte Spieler.
- Zusammenarbeit und KI-Hilfe sind als Doku-/Config-Basis vorbereitet:
  `docs/COLLABORATION.md`, `docs/AI_HELP_ASSISTANT.md`, `.env.example`.

## Naechster Prompt - Feature-Scheibe 2
```text
Du arbeitest lokal in D:\Schach\SchachTurnierManager.
Public-Sonderfall: lokale Commits erlaubt, aber kein Push/Release/PR.

Ziel: Operator-Dashboard und Turnierpaket fuer Bergfest/Freestyle weiter verbessern.
Erst Ist-Zustand lesen: AGENTS.md, PLANS.md, README.md, CHANGELOG.md,
docs/BERGFEST_MVP_RUNBOOK.md, docs/TOURNAMENT_PRESET_IMPORT.md,
docs/COLLABORATION.md, docs/AI_HELP_ASSISTANT.md, relevante Tests/Skripte.

Umfang:
- P0: Dashboard zeigt kompakt letzten Backup-Stand, letzten Audit-Export, offene Bretter,
  Import-/Preset-Report-Hinweis und naechste sinnvolle Operator-Aktion.
- P0: Export/Print als Turnierpaket buendeln: Tabelle, aktuelle Paarungen, Rundenblatt,
  Audit-Hinweis und Backup-Erinnerung.
- P1 klein: QR/Chess960-Vorabtest im Runbook und Smoke sichtbarer machen, aber keine neue
  QR-Architektur.
- Kein FIDE-Dutch-Umbau, keine KI-Cloud-Aufrufe, keine echten local-input-Daten committen.

Checks: dotnet test, npm run build, Import-DryRun mit synthetischem tmp-Preset,
Secret-/Token-Scan, .npmrc-Pruefung, git diff --check. Bei gruenem Gate lokal committen.
```

## Priorisierte offene Feature-Liste
- P0: Operator-Dashboard verdichten; Export-/Print-Turnierpaket; Offline-/Fallback-Test mit
  echter Vor-Ort-Ausstattung; Importbericht im Operator-Ablauf sichtbar machen.
- P1: Chess960/QR real testen; Tie-Breaks fuer kampflos/unplayed rounds integrieren;
  Swiss-Pairing Richtung FIDE-Dutch vertiefen; lokale Spielersuche beschleunigen.
- P2: Mehr-Operator-Konzept; Notizen/Kommentare; KI-Hilfe mit BYO-Key und lokaler
  Runbook-Anbindung; Beamer-/Publikumsmodus; Vereinsseite-/WhatsApp-/PDF-Exports.

## Erledigt am 2026-06-16
- Priorisierte `docs/FEATURE_ROADMAP.md` (P1–P5) angelegt.
- P1-Erststück umgesetzt: reines FIDE-Virtual-Opponent-Modell für eigene ungespielte
  Runden (`UnplayedRoundTiebreak`, `UnplayedRoundBuchholzMode`) mit Unit-Tests und
  `docs/TIEBREAK_UNPLAYED_ROUNDS.md`. Noch nicht in `StandingsCalculator` verdrahtet
  (Default-Modus = bisheriges Verhalten, keine Regression).
- `docs/IMPORT_EXPORT_ROADMAP.md` mit Format-Stufen und Schnittstellen-Skizze angelegt.

## Unmittelbar nächste Schritte (P1 fortsetzen)
- `UnplayedRoundBuchholzMode` in `TournamentSettings` aufnehmen (Default = Ignore).
- `UnplayedRoundTiebreak` opt-in in `StandingsCalculator` verdrahten; neue Bye-/Forfeit-
  Regressionstests im FIDE-Modus, bestehende Default-Tests bleiben gültig.
- Gegner-eigene ungespielte Runden nach FIDE Art. 16.2 (Kategorien) ergänzen.

Jeder Block ist als eigenständiger, sicherer Folgelauf gedacht. Reihenfolge ist eine
Empfehlung, keine harte Abhängigkeit. Vor fachlichen Algorithmusänderungen zuerst Tests
ergänzen; Pairing-Entscheidungen müssen auditierbar bleiben.

## Grundregeln je Lauf
- Erst Ist-Zustand, Build, Tests verstehen, dann ändern.
- Keine Secrets, internen URLs, privaten Audit-/Backup-/Output-Dateien.
- Kein Push/Release/PR ohne ausdrückliche Freigabe und grünes Open-Source-Safety-Gate.
- Keine Massenformatierung, keine großen Refactorings ohne Auftrag.

## Offene fachliche Punkte (aus PLANS.md v0.4)
1. Buchholz-Feinheiten, kampflose Partien und Cut-Wertungen sauber spezifizieren
   und mit Domain-Regressionstests absichern (Forfeit-/Bye-Sonderfälle).
2. Import-/Export-Adapter für das Swiss-Chess-/Chess-Results-Ökosystem untersuchen
   (zunächst nur Analyse und Format-Spike, kein produktiver Adapter).

## Schweizer-System Richtung FIDE Dutch (aus „Nächster Fokus ab 0.4.0“)
3. Bracket-/Scoregroup-Transpositionslogik und absolute Kriterien vertiefen.
4. Detaillierte Floater-Verwaltung mit Audit-Nachweis ausbauen.
   Jeweils zuerst Golden-/Unit-Tests mit konkreten Pairing-Fällen ergänzen.

## Externe Spielerdaten (aus v0.10.0 / Roadmap)
5. DSB/DeWIS-API-Zugang klären und Provider robust machen (Tests mit Fixtures,
   kein Live-Netzwerk im CI-/Gate-Pfad).
6. FIDE-Namenssuche prüfen und ggf. aktivieren; Importvorschau verbessern.

## Auslieferung / Installation (aus v0.5 / v0.9.1)
7. Portable Publish und Backup/Restore im Portable-Kontext sichtbarer machen.
8. Erste Release-Checkliste und manuelle QA-Szenarien dokumentieren.

## Qualität / Wartung
9. PLANS.md und Changelog-Historie sind über viele Versionen gewachsen und teils
   redundant. Optionaler, klar abgegrenzter Aufräumlauf (nur Doku, keine Logik),
   falls gewünscht ausdrücklich beauftragen.
