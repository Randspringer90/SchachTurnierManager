# RUN-16 – Weitere Turnierformate

Vorab `PROMPT_BASE.md` lesen und befolgen. Setzt stabiles Strategie-Interface (RUN-12)
voraus. **Nicht alles in einem Lauf** – pro Lauf ein Format inkl. Tests und UI.

## Formate (empfohlene Reihenfolge)
1. Double Round Robin (naheliegend, RR existiert).
2. Knockout (Setzliste, Freilose, Bracket-Anzeige).
3. Gruppenphase + Finalrunde (Qualifikationslogik).
4. Team-Schweizer / Mannschaftsturniere mit mehreren Brettern (Brettpunkte vs.
   Mannschaftspunkte – größter Brocken, eigenes Domain-Konzept zuerst).
5. Scheveningen-System.
6. Playoffs/Stichkampf/Armageddon (Armageddon-Grundlage existiert bereits).

## Querschnitt
- Schnellschach/Blitz/Chess960 sind Zeit-/Modus-Eigenschaften, keine eigenen Formate –
  als Turniereinstellung modellieren.
- Jugend-/Rating-/Vereinswertungen als Auswertungsschicht, nicht in die Pairing-Logik
  mischen.
- Je Format: Domain-Tests, UI-Anlage, Rundenlogik, Tabellenlogik, Druck/Export.
