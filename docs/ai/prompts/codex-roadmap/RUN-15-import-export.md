# RUN-15 – Import/Export ausbauen (CSV/Excel zuerst, TRF vorbereiten)

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Aufgaben
- CSV-Import/-Export produktiv härten: Teilnehmer, Paarungen, Ergebnisse, Tabellen;
  Excel-kompatibel (BOM/Trennzeichen/Umlaute), Importvorschau mit Validierungsfehlern.
- TRF16 (FIDE Tournament Report Format) analysieren und als Export implementieren;
  Spezifikation und Feldzuordnung in `docs/architecture/` dokumentieren.
- Swiss-Manager-/Chess-Results-Formate nur über offiziell dokumentierte bzw. frei
  einsehbare Formatbeschreibungen analysieren – **kein Scraping, keine rechtlich
  fragwürdigen Reverse-Engineering-Aktionen.**
- PGN-Export optional und nur für Partien (niedrige Priorität).
- Round-Trip-Tests: Export → Import → identischer Zustand (synthetische Daten).
