# FEATURE_ROADMAP.md

Priorisierter, fachlicher Implementierungsplan für SchachTurnierManager.
Stand: 2026-06-16 (Basis 0.38.5, Build/Tests/Frontend grün, Open-Source-Safety grün).

Diese Roadmap ergänzt `PLANS.md`/`docs/NEXT_PROMPTS.md` und priorisiert die offenen
fachlichen Themen. Reihenfolge ist eine Empfehlung, keine harte Abhängigkeit. Vor
fachlichen Algorithmusänderungen zuerst Tests ergänzen; Pairing- und
Wertungsentscheidungen müssen auditierbar bleiben.

## Leitplanken
- Public Repo: strengstes Open-Source-Safety-Gate, keine Secrets/privaten Daten/internen URLs.
- Keine Massenformatierung, keine großen Refactorings, kein Force-Push.
- Fachlich unklare Regeln werden als Annahme dokumentiert und Tests auf bekannte Fälle beschränkt.
- Quellen werden als Doku-Notiz/Link referenziert, kein langer Copyright-Text wird kopiert.

## P1 — Tie-Break / Buchholz / ungespielte Runden
Ziel: kampflose Partien, Bye/spielfrei und ungespielte Runden in den Wertungen
nachvollziehbar und FIDE-nah abbilden.

- [x] Forfeit-/Bye-Grundlagen vorhanden: `ForfeitTiebreakPolicy`, `ResultPolicy`,
      Buchholz-Cut-1/Cut-2/Median im `StandingsCalculator`.
- [x] **FIDE-Virtual-Opponent-Modell für eigene ungespielte Runden** als reines,
      getestetes Domain-Modell vorbereitet (`UnplayedRoundTiebreak`,
      `UnplayedRoundBuchholzMode`). Siehe `docs/TIEBREAK_UNPLAYED_ROUNDS.md`.
- [ ] Modell opt-in in `StandingsCalculator` verdrahten (eigene Baselines bewusst neu).
- [ ] Gegner-eigene ungespielte Runden gemäß FIDE Art. 16.2 (Kategorien) auswerten.
- [ ] Konfigurierbare Wertungslogik (Modus) in `TournamentSettings` und UI sichtbar machen.
Quellen: FIDE Handbook C.07 (Tie-Break), Art. 16.2/16.4.

## P2 — Import/Export (Swiss-Chess / Swiss-Manager / Chess-Results)
Ziel: Austauschformate für Teilnehmer, Paarungen und Ergebnisse.
Siehe `docs/IMPORT_EXPORT_ROADMAP.md` für die Detailspezifikation.

- [ ] CSV/Excel als pragmatische erste Stufe (Teilnehmer, Tabelle, Paarungen).
- [ ] TRF (FIDE Tournament Report Format) als späteres Standard-Ergebnisformat untersuchen.
- [ ] Swiss-Manager/Chess-Results-Ökosystem analysieren (nur Format-Spike, kein Live-Scrape).
- [ ] PGN optional, nur Partien.
- [ ] Synthetische Fixtures statt echter, privater Turnierdaten.

## P3 — FIDE-Dutch Vertiefung (Audit / Debug / Validation)
Ziel: Pairing-Entscheidungen erklärbar und prüfbar machen.

- [ ] Scoregroups/Brackets und Transpositionslogik vertiefen.
- [ ] Floater-Audit mit Nachweis ausbauen.
- [ ] Pairing-Erklärung im UI/Report (warum welche Paarung).
Quellen: FIDE Swiss Rules / FIDE Dutch System.

## P4 — Spielerimport (FIDE / DSB / DeWIS)
Ziel: externe Spielerstammdaten robust übernehmen.

- [ ] FIDE-ID/Name/Elo-Lookup festigen (Basis vorhanden).
- [ ] DSB/DeWIS erst nach Klärung der offiziellen Schnittstelle, Tests mit Fixtures.
- [ ] Datenschutz: keine privaten Vereinslisten committen.

## P5 — Portable Release / QA
Ziel: auslieferbares, geprüftes Paket.

- [ ] Portable Paket und Backup/Restore sichtbarer machen.
- [ ] Release-Checkliste und manuelle QA-Szenarien dokumentieren.
- [ ] Open-Source-Safety-Gate vor jedem Release.
