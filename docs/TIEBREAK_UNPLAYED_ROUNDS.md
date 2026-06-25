# Tie-Break: ungespielte Runden, Bye und kampflose Partien

Stand: 2026-06-16 (Basis 0.38.5). Dieses Dokument beschreibt das fachliche Modell
für die Behandlung ungespielter Runden in den gegnerbasierten Wertungen
(Buchholz und Varianten) und den aktuellen Implementierungsstand.

## Fachliche Grundlage (Quellen, ohne Zitat-Volltext)
- FIDE Handbook, C.07 „Play-Off and Tie-Break Regulations“ (Fassung gültig ab 2024).
  - Art. 16.2: Kategorien ungespielter Runden (pairing-allocated bye, kampfloser
    Sieg, angeforderter Bye, kampflose Niederlage, sonstige).
  - Art. 16.4: Für die *eigene* Wertung wird jede eigene ungespielte Runde wie eine
    Partie gegen einen virtuellen Gegner gewertet, der das Turnier mit der
    **eigenen Endpunktzahl des Spielers** abschließt.
- Praktische Referenz: Swiss-Manager/Chess-Results bilden dasselbe Verhalten ab.

Quellen werden nur als Notiz/Link referenziert; es wird kein langer Regeltext kopiert.

## Begriffe
- **Gespielte Partie**: Brettergebnis (Sieg/Remis/Niederlage, inkl. Armageddon).
- **Ungespielte Runde**: kein Brettergebnis — offen, Bye/spielfrei, kampfloser
  Sieg/Niederlage, doppelt kampflos.
- **Virtueller Gegner (FIDE Art. 16.4)**: fiktiver Gegner, dessen Endpunktzahl der
  eigenen Endpunktzahl des Spielers entspricht.

## Modell im Code
Reiner, zustandsloser Domain-Service:
`src/SchachTurnierManager.Domain/Services/UnplayedRoundTiebreak.cs`

- `IsUnplayedRound(GameResultKind)` — klassifiziert ein Ergebnis aus Spielersicht.
- `VirtualOpponentScore(playerOwnFinalScore)` — Art. 16.4: = eigene Endpunktzahl.
- `OwnUnplayedBuchholzContribution(mode, playerOwnFinalScore, unplayedRoundCount)`
  — Buchholz-Beitrag der eigenen ungespielten Runden (modusabhängig).
- `BuildBuchholzScoreList(mode, realOpponentScores, playerOwnFinalScore, unplayedRoundCount)`
  — sortierte Gegner-Punktliste inkl. virtueller Gegner, fertig für Buchholz-Cut/Median.

Konfiguration: `UnplayedRoundBuchholzMode`
- `IgnoreUnplayedRounds` (Default): bisheriges Verhalten, eigene ungespielte Runden
  tragen nichts zum eigenen Buchholz bei.
- `FideVirtualOpponent`: FIDE Art. 16.4, virtueller Gegner mit eigener Punktzahl.

## Bewusste Annahmen / Scope
- Implementiert ist zunächst nur die **eigene** Wertung nach Art. 16.4. Die
  feinere Auswertung der *gegner-eigenen* ungespielten Runden nach Art. 16.2
  (Kategorien 16.2.1–16.2.5, teils als Remis zu werten) ist als Folgeschritt
  vorgesehen und noch nicht umgesetzt.
- Das Modell ist **noch nicht** in `StandingsCalculator` verdrahtet. Default-Modus
  hält bestehende Wertungs-Baselines unverändert; die Integration ändert bewusst
  die Buchholz-Werte von Bye-/Forfeit-Spielern und braucht angepasste Tests.

## Integrationspfad (Folgelauf)
1. `UnplayedRoundBuchholzMode` in `TournamentSettings` aufnehmen (Default = Ignore).
2. In `StandingsCalculator.Calculate` nach der Punkteberechnung je Spieler die
   Zahl eigener ungespielter Runden zählen und `OwnUnplayedBuchholzContribution`
   bzw. `BuildBuchholzScoreList` für Buchholz/Cut/Median verwenden.
3. Regressionstests für Bye-/Forfeit-Fälle mit neuem Modus ergänzen
   (bestehende Tests im Default-Modus bleiben gültig).
4. Modus im UI sichtbar und auditierbar machen.

## Tests
`tests/SchachTurnierManager.Domain.Tests/UnplayedRoundTiebreakTests.cs` deckt ab:
- normal gespielte Partie (kein virtueller Gegner),
- kampfloser Sieg (eigene ungespielte Runde, virtueller Gegner),
- spielfrei/Bye (virtueller Gegner = eigene Punktzahl),
- konfigurierbarer Beitrag je Modus,
- vorbereitete sortierte Liste für Buchholz-Cut/Streichergebnis.
