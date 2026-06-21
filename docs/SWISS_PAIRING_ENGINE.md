# Swiss-Paarungs-Engine (V2: optimales Matching)

**Stand:** 2026-06-21 · Reaktion auf „falsche/wiederholte Paarungen" aus dem
`POSTMORTEM_BERGFEST_2026.md`. Alle Beispiele synthetisch.

## Was sich geändert hat

Bis v0.40.x war die Schweizer-Auslosung eine reine **Greedy-Heuristik**: Sie nahm den
stärksten ungepaarten Spieler, suchte dessen besten Gegner, fixierte das Paar und ging weiter.
Das ist lokal sinnvoll, aber **nicht global optimal** – Greedy kann sich früh festlegen und
spätere Spieler in **vermeidbare Wiederholungspaarungen (Rematches)** zwingen.

Das war reproduzierbar: schon bei 8 Spielern erzeugte Greedy ab Runde 4 in der Mehrzahl
zufälliger Verläufe ein Rematch, obwohl eine rematchfreie Gesamtauslosung existierte
(siehe `SwissPairingOptimalMatchingTests`).

Ab v0.41.0 berechnet die Engine ein **global optimales Minimum-Penalty-Matching**:

- Für jede mögliche Paarung wird eine Strafe (Penalty) bestimmt:
  - Punktdifferenz × 1000 (hält Paarungen innerhalb der Scoregruppe),
  - Wiederholungspaarung += 1 000 000 000 (dominiert alles andere sicher),
  - Farbstrafen (Bilanz, dritte gleiche Farbe in Folge, Präferenzen).
- Über alle Bretter wird die **Gesamtstrafe minimiert** – per exakter
  Maximum-Weight-Matching-Suche (Bitmasken-DP) für Felder bis **20 Spieler**.
- Weil die Rematch-Strafe jede Kombination der übrigen Strafen übersteigt, gilt:
  **Ein Rematch entsteht nur dann, wenn es überhaupt keine rematchfreie Gesamtauslosung
  mehr gibt.** Genau dann (und nur dann) erscheint im Audit der Hinweis
  „Rematch unvermeidbar (global optimiert …)".

Bye-Vergabe, Farbentscheidung und die gesamte **Pairing-Forensik** (siehe
`AUDIT_JOURNAL.md`) bleiben unverändert; sie beschreiben jetzt automatisch das verbesserte
Ergebnis.

## Determinismus

Gleiche Eingabe → gleiche Auslosung. Spieler werden nach Punkten, TWZ und Startrang sortiert;
bei strafgleichen Alternativen gewinnt die zuerst gefundene (stärkster verfügbarer Gegner).
Die Auslosung ist damit testbar und nachvollziehbar.

## Bewusste Grenzen (Roadmap „Swiss v2 / FIDE-Dutch")

Die Engine ist **kein vollständiges FIDE-Dutch**. Bewusst noch offen:

1. **Bracket-/Transpositionsregeln:** FIDE-Dutch paart innerhalb einer Scoregruppe streng
   obere gegen untere Hälfte (S1–S(k+1)) mit definierten Transpositionen/Austauschen. Die
   V2-Engine minimiert stattdessen global die Gesamtstrafe. Ergebnis-Qualität (Rematch,
   Scoregruppen, Farben) ist sehr gut, die **exakte FIDE-Dutch-Paarreihenfolge** wird aber
   nicht garantiert – insbesondere die Erstrunden-Setzung obere vs. untere Hälfte.
2. **Downfloat-/Upfloat-Regeln** nach FIDE (C.04.1, Floater-Wahl, „same float twice"):
   Floater werden protokolliert, aber nicht nach dem vollständigen FIDE-Regelwerk ausgewählt.
3. **Farb-Sonderregeln** (absolute Farbpräferenz, C.04.2) werden über Strafgewichte
   angenähert, nicht als harte FIDE-Constraints erzwungen.
4. **Beschleunigtes Schweizer System** und alternative Systeme (Dubov/Burstein/Monrad).
5. **Große Felder (> 20 Spieler):** Hier fällt die Auslosung bewusst auf die dokumentierte
   Greedy-Heuristik zurück (im Audit als „Greedy-Fallback" gekennzeichnet). Für große Opens
   ist ohnehin ein vollständiges FIDE-Dutch das Ziel.

### Nächste Schritte Swiss v2

- FIDE-Dutch-Bracket-Pairing als eigene, austauschbare Strategie (Strategie-Interface), damit
  V2-Optimal und FIDE-Dutch nebeneinander wähl- und vergleichbar sind.
- Erstrunden-Setzung obere vs. untere Hälfte als optionale, getestete Verbesserung.
- Polynomiales Matching (Blossom) statt Bitmasken-DP, um auch große Opens optimal zu paaren.
- Golden-Tests gegen Referenzauslosungen, sobald ein FIDE-Dutch-Referenzkatalog vorliegt.

Siehe auch `docs/SWISS_CHESS_PARITY_ROADMAP.md`.
