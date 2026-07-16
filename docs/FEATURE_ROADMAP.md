# FEATURE_ROADMAP.md

Priorisierter, fachlicher Implementierungsplan für SchachTurnierManager.
Stand: 2026-07-16 (`development`, STM-FACH-001 über Owner-PR #14 abgeschlossen).

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
- [x] **FIDE-C.07/03-2026-Modell für Schweizer Buchholz/Cut/Median** opt-in in
      `StandingsCalculator` verdrahtet (`UnplayedRoundTiebreak`,
      `UnplayedRoundBuchholzMode`), Legacy-Default unverändert.
- [x] Gegnerstände nach den im heutigen Datenmodell unterscheidbaren Kategorien
      gemäß Art. 16.2/16.3 angepasst; Halb-/Nullpunkt-Bye bleibt explizite Modellgrenze.
- [x] Konfigurierbare Wertungslogik durch Domain, API, UI, Persistenz,
      Backup/Restore und Export/Audit transportiert.
Quelle: FIDE Handbook C.07 (Tie-Break), Fassung gültig seit 1. März 2026,
Art. 15/16; Details in `docs/TIEBREAK_UNPLAYED_ROUNDS.md`.

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
