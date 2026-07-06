# RUN-13 – Große Schweizer Turniere (> 20 Spieler)

Vorab `PROMPT_BASE.md` lesen und befolgen. Setzt idealerweise RUN-12(a) voraus
(Strategie-Interface).

## Ziel
Den dokumentierten Greedy-Fallback für Felder > 20 Spieler durch eine qualitativ
bessere Lösung ersetzen.

## Aufgaben
- Polynomiales Maximum-Weight-Matching (Blossom-Algorithmus) für die
  Minimum-Penalty-Paarung evaluieren; eigene Implementierung ohne neue Dependency
  bevorzugen (Domain bleibt dependency-frei).
- Synthetische große Opens testen (50/100/200 Spieler, mehrere Seeds, alle Runden):
  keine vermeidbaren Rematches, Bye-/Farbregeln eingehalten.
- Performance messen (Zeit je Auslosung) und Grenzen dokumentieren.
- Pairing-Qualität Greedy vs. neu vergleichen und im Bericht quantifizieren.
- Invariantentests analog zu den bestehenden ≤ 20-Tests ergänzen.
