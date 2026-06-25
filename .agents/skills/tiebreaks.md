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

Vorbereitet:
- FIDE-Virtual-Opponent-Modell für eigene ungespielte Runden
  (`UnplayedRoundTiebreak`, `UnplayedRoundBuchholzMode`, C.07/2024 Art. 16.4).
  Rein/getestet, noch nicht im `StandingsCalculator` verdrahtet.
  Details: docs/TIEBREAK_UNPLAYED_ROUNDS.md.

Offen:
- Modell opt-in in `StandingsCalculator` integrieren (eigene Baselines neu).
- Gegner-eigene ungespielte Runden nach FIDE Art. 16.2 (Kategorien) auswerten.
- Feinheiten für Round Robin vs Swiss trennen.
- progressive Wertungen weiter ausbauen.
