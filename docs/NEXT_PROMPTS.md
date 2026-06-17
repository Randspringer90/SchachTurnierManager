# NEXT_PROMPTS.md

Konsolidierte, vorbereitete Arbeitsaufträge für kommende Entwicklungsläufe.
Stand: 2026-06-16 (Basis: 0.38.5, Build/Tests/Frontend grün, Open-Source-Safety grün).

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
