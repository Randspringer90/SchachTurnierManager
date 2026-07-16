# Skill: Tiebreaks

Ziel: Wertungen nachvollziehbar berechnen.

Aktuell:
- Punkte
- Siege
- Direktvergleich
- Buchholz
- Buchholz Cut-1
- Sonneborn-Berger
- Durchschnittsgegner
- Performance

Implementiert (opt-in):
- FIDE-C.07/03-2026-Modell für Schweizer Buchholz/Cut/Median
  (`UnplayedRoundTiebreak`, `UnplayedRoundBuchholzMode`, Art. 16.2–16.5).
- Default bleibt `IgnoreUnplayedRounds`; die `ForfeitTiebreakPolicy` entscheidet
  zuerst über reale Gegner und verhindert Doppelzählung.
- Details und Modellgrenzen: `docs/TIEBREAK_UNPLAYED_ROUNDS.md`.

Offen:
- Separate Ergebnisarten für angeforderte Halbpunkt-/Nullpunkt-Byes modellieren,
  bevor diese FIDE-Kategorien fachlich behauptet werden.
- Feinheiten für Round Robin vs Swiss trennen.
- progressive Wertungen weiter ausbauen.
