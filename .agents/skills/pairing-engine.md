# Skill: Pairing Engine

Ziel: Paarungen deterministisch, testbar und auditierbar erzeugen.

Regeln:
- Keine UI-Logik in Pairing-Algorithmen.
- Keine stillen manuellen Änderungen.
- Wiederholungen im Schweizer System vermeiden.
- Farben und Byes protokollieren.
- FIDE-Dutch später als eigener austauschbarer Algorithmus.


0.5.0 ergänzt manuelle Pairing-Overrides. Jede manuelle Änderung muss als Audit-Meldung protokolliert werden und darf gesperrte/geprüfte Runden nicht verändern.
