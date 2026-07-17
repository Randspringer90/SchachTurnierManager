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

## FIDE-Dutch steht seit STM-FACH-002 daneben

Seit STM-FACH-002 gibt es das **FIDE-Dutch-System als eigene, austauschbare Strategie**
(`FideDutchPairingStrategy`, C.04.3 in der ab 01.02.2026 gültigen Fassung) hinter dem
Interface `ISwissPairingStrategy`. Regelgrundlage mit allen Fundstellen:
`docs/FIDE_DUTCH_REFERENCE.md`.

**Die hier beschriebene V2-Engine bleibt unverändert und Standard.** Sie wird durch FIDE-Dutch
nicht ersetzt: Beide Verfahren sind grundverschieden — V2 minimiert global eine Gesamtstrafe,
FIDE-Dutch arbeitet eine vorgeschriebene Reihenfolge Bracket für Bracket ab. Sie stehen
nebeneinander und bleiben vergleichbar. Umgestellt wird bewusst über
`TournamentSettings.PairingStrategy`.

Die Punkte 1–3 der folgenden Liste sind damit **für FIDE-Dutch erledigt** und beschreiben nur
noch die Grenzen dieser V2-Engine.

## Bewusste Grenzen dieser V2-Engine

Die V2-Engine ist **kein FIDE-Dutch**. Bewusst offen:

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

- ✅ **Erledigt (STM-FACH-002):** FIDE-Dutch-Bracket-Pairing als eigene, austauschbare Strategie
  hinter `ISwissPairingStrategy`; V2-Optimal und FIDE-Dutch sind nebeneinander wähl- und
  vergleichbar.
- ✅ **Erledigt (STM-FACH-002):** Erstrunden-Setzung obere vs. untere Hälfte — in FIDE-Dutch nach
  C.04.3 Art. 3.2.2/3.3.1, getestet.
- ✅ **Erledigt (STM-FACH-002):** Golden-Tests gegen Referenzauslosungen. Der „Referenzkatalog",
  auf den dieser Punkt wartete, ist nicht nötig: **C.04.2 Art. 1.4 verlangt, dass zugelassene
  Programme zu identischen Paarungen kommen** — der Abgleich gegen eine solche Engine ist damit
  der von der Regel selbst definierte Maßstab. Drei Golden-Turniere à fünf Runden sind von Hand
  aus dem Regeltext hergeleitet und gegen bbpPairings 6.0.0 gegengeprüft.
- Polynomiales Matching (Blossom) statt Bitmasken-DP, um auch große Opens optimal zu paaren
  (**STM-FACH-003**, gilt auch für die Kandidatensuche von FIDE-Dutch).
- Setzliste nach C.04.2 Art. 2.2–2.3 vergeben (Spielstärke → Titel → alphabetisch). Aktuell
  vergibt die App Startnummern in Eingabereihenfolge; FIDE-Dutch warnt darüber im Audit, korrigiert
  aber nicht selbst. Eigenes Folge-Ticket.

Siehe auch `docs/SWISS_CHESS_PARITY_ROADMAP.md`.
