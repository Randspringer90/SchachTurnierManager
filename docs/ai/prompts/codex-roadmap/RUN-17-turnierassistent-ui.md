# RUN-17 – Turnierassistent im UI

Vorab `PROMPT_BASE.md` lesen und befolgen.

## Ziel
Regelbasierter Assistent (ohne KI-Pflicht), der Einsteiger zum passenden Turnier führt.

## Aufgaben
- Assistent „Ich habe N Spieler und X Stunden – welches Format?": Empfehlungslogik
  (Rundenzahl, Bedenkzeit, Format) als testbare Domain-/Application-Funktion,
  nicht im Frontend versteckt.
- Vorlagen: Vereinsabend, Bergfest, Jugendturnier, Open, Mannschaftskampf –
  als Presets, die das Anlage-Formular vorbefüllen.
- Automatische Plausibilitätsprüfung vor Turnierstart: zu viele Runden für
  Spielerzahl, fehlende Bedenkzeit, ungerade Teilnehmer + Bye-Regel, Kategorien
  ohne Teilnehmer usw. – als Warnliste mit Erklärungen.
- i18n beachten: alle neuen UI-Texte über `t('…')` (siehe RUN-21).
