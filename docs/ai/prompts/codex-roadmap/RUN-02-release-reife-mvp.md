# RUN-02 – Release-Reife des aktuellen MVP prüfen

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Nachweisen, dass alle in `README.md` beschriebenen Funktionen wirklich funktionieren.

## Aufgaben
- Funktionsliste aus README/PLANS extrahieren und je Funktion prüfen (API-Test, UI-Smoke
  oder vorhandener Test): Schweizer System, Round Robin, Chess960/QR, Backup/Restore,
  Audit-Journal, Druckansichten, CSV-/JSON-Exporte, Kategorien, Kreuztabelle.
- `scripts/Smoke-OperatorWorkflow.ps1` als Basis nutzen; Lücken als gezielte
  zusätzliche Checks ergänzen (synthetische Daten, keine echten Personendaten).
- Abweichungen als Bugliste dokumentieren; triviale Bugs (< 30 Minuten, risikoarm)
  direkt fixen, größere nur dokumentieren.

## Ergebnis
`docs/ai/reports/<datum>-release-readiness.md`: Funktion → geprüft wie → Ergebnis;
bekannte Grenzen; Bugliste mit Priorität.
