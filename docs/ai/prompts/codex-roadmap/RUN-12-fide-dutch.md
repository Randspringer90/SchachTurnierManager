# RUN-12 – FIDE-Dutch als eigene Pairing-Strategie

Vorab `PROMPT_BASE.md` lesen und befolgen. Fachgrundlage: `docs/SWISS_PAIRING_ENGINE.md`.

## Harte Leitplanke
Die bestehende Optimal-V2-Engine (global optimale Minimum-Penalty-Paarung ≤ 20 Spieler)
bleibt unverändert erhalten und Default. Bestehende Pairing-Tests dürfen nicht brechen.

## Aufgaben
- Strategie-Interface für Pairing-Engines einziehen (Domain-Ebene), Optimal-V2 als
  erste Implementierung dahinter, ohne Verhaltensänderung (Golden Tests beweisen das).
- FIDE-Dutch (C.04.3) als zweite, auswählbare Strategie schrittweise implementieren:
  Brackets/Scoregroups, Transpositions, Floater (Up/Down), Farbregeln (absolute/starke
  Präferenz), Erstrunden-Setzung nach Setzliste.
- Audit-Erklärung im UI: warum wurde so gepaart (Bracket, Floater, Farbentscheid).
- Testfälle aus offiziellen FIDE-Beispielen/bekannten Referenzpaarungen ableiten.

## Empfehlung
Mehrere Läufe: (a) Interface + Umbau ohne Verhaltensänderung, (b) Dutch-Grundgerüst
R1 + einfache Brackets, (c) Floater/Transpositions, (d) Farbfeinheiten + UI-Audit.
