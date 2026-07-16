# Tie-Break: ungespielte Runden, Bye und kampflose Partien

Stand: 2026-07-16. Dieses Dokument beschreibt die in STM-FACH-001 implementierte,
opt-in aktivierbare Buchholz-Behandlung für Schweizer Turniere.

## Fachliche Grundlage

- FIDE Handbook C.07, „Play-Off and Tie-Break Regulations“, gültig seit
  1. März 2026, abgerufen am 2026-07-16:
  https://handbook.fide.com/chapter/TieBreakRegulations032026
- Art. 16.2 klassifiziert ungespielte Runden.
- Art. 16.3 definiert den angepassten Stand eines Teilnehmers für die Tie-Breaks
  seiner Gegner.
- Art. 16.4 wertet die eigene ungespielte Runde gegen einen Dummy mit der eigenen
  Endpunktzahl; Forfeits werden durch den angepassten Stand des vorgesehenen
  Gegners, andere Fälle durch Remispunkte mal Rundenzahl gedeckelt.
- Art. 16.5 verlangt für VURs eine besondere Reihenfolge bei niedrigsten
  Streichern (Cut-1/Cut-2/Median).

Die Regeln gelten in diesem Paket ausschließlich für Buchholz und dessen
Cut-/Median-Varianten im Schweizer System. Sonneborn-Berger, Direktvergleich und
Performance bleiben bewusst unverändert; dafür ist keine stillschweigende
Scope-Erweiterung erfolgt.

## Konfiguration und Rückwärtskompatibilität

`TournamentSettings.UnplayedRoundBuchholzMode` besitzt zwei Werte:

- `IgnoreUnplayedRounds` (Default): bisheriges Verhalten; eigene ungespielte
  Runden erzeugen keinen Dummy, und bestehende Buchholz-Baselines bleiben erhalten.
- `FideVirtualOpponent`: Art.-16-Behandlung für Schweizer Buchholz/Cut/Median.

Alte JSON-/SQLite-/Backup-Daten ohne das Feld laden mit dem Enum-Default 0.
Application-Normalisierung verwirft unbekannte Enumwerte ebenfalls auf den
Legacy-Default. Round-Robin-Turniere ignorieren den FIDE-Modus, weil Art. 16 nur
für Schweizer Turniere gilt.

## Präzedenz der Forfeit-Policy

`ForfeitTiebreakPolicy` wird zuerst ausgewertet:

1. Zählt die Policy den vorgesehenen realen Gegner für Buchholz, bleibt dieser
   reale Beitrag erhalten und es wird kein zusätzlicher Dummy ergänzt.
2. Schließt die Policy den realen Gegner aus, ergänzt der FIDE-Modus genau einen
   Dummy aus Sicht des jeweiligen Spielers.
3. Dadurch werden reale und virtuelle Gegner nie doppelt gezählt.

Diese Präzedenz erhält die vorhandene, ausdrücklich konfigurierbare Turnierpolicy.
Sie wird im UI erklärt und in Export-/Audit-Ausgaben nachvollziehbar transportiert.

## Kanonische Berechnung

`StandingsCalculator` berechnet zunächst historische Resultate über alle Spieler.
Erst die fertige sichtbare Rangliste wird auf aktive Spieler begrenzt. Dadurch
behalten aktive Gegner bereits erspielte Punkte, auch wenn ein damaliger Gegner
später pausiert oder zurückgezogen wurde.

Für den FIDE-Buchholzmodus entsteht pro Spieler genau eine kanonische Liste aus:

- realen Gegnerständen gemäß `ForfeitTiebreakPolicy`,
- Art.-16.3-angepassten Gegnerständen,
- höchstens einem Dummy je eigener endgültig ungespielter Runde,
- einer VUR-Markierung je relevanter Runde für Art. 16.5.

Buchholz, Cut-1, Cut-2 und Median werden ausschließlich aus dieser Liste berechnet.
Offene `NotPlayed`-Partien und fehlende Pairings in offenen Runden erzeugen keinen
Dummy. Explizite Byes und Forfeit-Ergebnisse sind bereits endgültige Ergebnisse;
ein `NotPlayed`-Ergebnis beziehungsweise ein fehlendes Pairing wird erst nach
Abschluss/Verifikation/Sperre der Runde berücksichtigt.

## Im heutigen Datenmodell unterscheidbare Fälle

- `Bye`: pairing-allocated/full-point bye, keine VUR.
- `WhiteForfeitWin`/`BlackForfeitWin`: Gewinner nicht VUR, Verlierer VUR.
- `DoubleForfeit`: VUR für beide Spieler.
- finalisiertes `NotPlayed`: sonstige/angeforderte ungespielte Runde; offen bleibt offen.
- kein Pairing in finalisierter Runde: angeforderte/sonstige ungespielte Runde.
- spätere Nicht-VUR vorhanden: Bewertung entsprechend dem vergebenen Ergebnis.
- nur abschließende solche Runden: für gegnerseitige Art.-16.3-Berechnung als Remis.

Das Modell besitzt derzeit keine separaten Ergebnisarten für angeforderte Halbpunkt-
und Nullpunkt-Byes. Diese Kategorien werden deshalb nicht vorgetäuscht; eine spätere
Erweiterung benötigt zuerst ein explizites, persistierbares Domainfeld.

## Transport und Nachvollziehbarkeit

Die Einstellung läuft durch Domain, Application-Normalisierung, API-Verträge,
React-Formular, SQLite-JSON, JSON-Backup/Restore, Exportmanifest und Druckmetadaten.
Das Settings-Audit protokolliert sowohl `ForfeitTiebreakPolicy` als auch
`UnplayedRoundBuchholzMode`.

## Tests

- Default und FIDE-Bye inklusive 2026-Cap
- Forfeit Win/Loss, Double Forfeit und alle Policy-Präzedenzen
- offene/finalisierte `NotPlayed`-Partien und nicht gepaarte Runden
- keine Doppelzählung
- Buchholz, Cut-1, Cut-2, Median und VUR-Streicher
- unveränderte Sonneborn-/Direktvergleich-/Performance-Werte
- Withdrawal nach Sieg/Niederlage/Remis, vor erster Partie und mehrfach
- UI-/API-/JSON-/SQLite-/Backup-/Legacy-/Export-/Audit-Transport
- unveränderte Golden-Szenarien
