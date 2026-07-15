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
- Seit STM-FACH-001 ist das Modell in `StandingsCalculator.Calculate` verdrahtet
  (Buchholz/Cut-1/Cut-2/Median-Buchholz). Default-Modus (`IgnoreUnplayedRounds`)
  hält bestehende Wertungs-Baselines unverändert; `FideVirtualOpponent` ist
  opt-in über `TournamentSettings.UnplayedRoundBuchholzMode`. Sonneborn-Berger,
  Direktvergleich und Performance sind von dieser Änderung nicht betroffen.
- **Offener Punkt (nicht Teil dieses Laufs):** Zurückgezogene Spieler
  (`PlayerStatus.Withdrawn`) verlieren aktuell nicht nur ihren eigenen
  Tabellenplatz, sondern ihre bisherigen Gegner verlieren rückwirkend auch die
  in bereits gespielten Partien erzielten Punkte, weil `StandingsCalculator`
  nur aktive Spieler in die Berechnung aufnimmt. Das ist ein eigenständiger
  Scoring-Bug (nicht nur Tie-Break) und dokumentiert in
  `tests/SchachTurnierManager.Domain.Tests/PlayerWithdrawalStandingsTests.cs`.
  Klärung/Fix mit dem Owner separat vorschlagen (z. B. eigener Backlog-Eintrag).

## Integrationspfad
1. ✅ `UnplayedRoundBuchholzMode` in `TournamentSettings` aufgenommen (Default = Ignore).
2. ✅ `StandingsCalculator.Calculate` zählt je Spieler die eigenen ungespielten
   Runden (`MutableStanding.UnplayedRoundCount`) und nutzt
   `UnplayedRoundTiebreak.BuildBuchholzScoreList` für Buchholz/Cut/Median.
3. ✅ Regressionstests für Bye-Fälle in beiden Modi ergänzt
   (`UnplayedRoundStandingsIntegrationTests`); bestehende Tests im
   Default-Modus bleiben unverändert gültig.
4. Offen: Modus im UI sichtbar und auditierbar machen (Folgeschritt).

## Tests
`tests/SchachTurnierManager.Domain.Tests/UnplayedRoundTiebreakTests.cs` deckt das
reine Domain-Modell ab:
- normal gespielte Partie (kein virtueller Gegner),
- kampfloser Sieg (eigene ungespielte Runde, virtueller Gegner),
- spielfrei/Bye (virtueller Gegner = eigene Punktzahl),
- konfigurierbarer Beitrag je Modus,
- vorbereitete sortierte Liste für Buchholz-Cut/Streichergebnis.

`tests/SchachTurnierManager.Domain.Tests/UnplayedRoundStandingsIntegrationTests.cs`
deckt die Verdrahtung End-to-End über `StandingsCalculator` ab (Default- vs.
FIDE-Modus am selben 5-Spieler-Beispielturnier mit drei Freilosen).
