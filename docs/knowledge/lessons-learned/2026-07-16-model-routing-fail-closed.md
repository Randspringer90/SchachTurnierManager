# Modellrouting muss Verfügbarkeit explizit prüfen

- source: STM-AI-003 Implementierung und synthetische Readiness-Matrix
- date: 2026-07-16
- trust: T2 für geprüfte Repository-Policies; Testausgaben wurden nur als T3-Daten ausgewertet
- review: Owner-PR #17 und Remote-CI abgeschlossen

## Beobachtung

Eine reine Zuordnung von Aufgaben zu Qualitätsklassen reicht nicht aus. Wenn die
aufrufende Runtime das empfohlene logische Profil nicht bereitstellt, könnte ein
impliziter Fallback die Qualitätsgrenze unbemerkt unterschreiten.

## Konsequenz

Der Resolver trennt Empfehlung und Verfügbarkeitsbestätigung. Ohne bestätigtes
Profil oder bei einer nicht abgedeckten Kombination liefert er einen blockierenden
Status. Die Entscheidung enthält Regel, Profil, Risiko, Verfügbarkeit und Begründung,
ohne ein konkretes Modell zu starten oder fremde Inhalte zu persistieren.

## Wiederverwendung

Neue Profile und Auswahlregeln benötigen neben Schema- und Integritätsprüfung immer
synthetische Positiv- und Negativfälle. Besonders wichtig sind Nichtverfügbarkeit,
unklare Aufgaben, kritische Kategorien und die Grenzen deterministischer Massenarbeit.
