using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Dokumentiert das aktuelle, ungeprüfte Verhalten von <see cref="StandingsCalculator"/> bei
/// zurückgezogenen Spielern (<see cref="PlayerStatus.Withdrawn"/>). Bewusst KEINE Verhaltensänderung
/// im Rahmen von STM-FACH-001 (Freilos-/Tie-Break-Wertung) - das ist eine eigenständige, groessere
/// Scoring-Frage und wird als offener Punkt fuer den Owner dokumentiert statt hier still gefixt
/// (siehe AGENTS.md "Fachlich unklare Regeln werden als Annahme dokumentiert").
///
/// BEFUND: Da <see cref="StandingsCalculator.Calculate"/> Zeilen ausschliesslich fuer aktive Spieler
/// anlegt und <c>ApplyPairing</c> eine Partie ueberspringt, sobald einer der beiden Spieler nicht in
/// der Zeilen-Map existiert, verliert nicht nur der zurueckgezogene Spieler seinen Tabellenplatz -
/// auch sein GEGNER verliert rueckwirkend die in der bereits gespielten Partie erzielten Punkte.
/// Das betrifft echte Punktzahlen, nicht nur Tie-Breaks, und sollte separat mit dem Owner geklärt
/// werden (vorgeschlagen: eigener Backlog-Eintrag, z. B. STM-FACH-002).
/// </summary>
public sealed class PlayerWithdrawalStandingsTests
{
    [Fact]
    public void Calculate_WithdrawnPlayer_OpponentLosesAlreadyEarnedPointsFromThatGame()
    {
        var a = new Player { Id = Guid.Parse("00000000-0000-0000-0000-000000000001"), Name = "A", StartingRank = 1, Rating = new RatingProfile { ManualTwz = 2000 } };
        var b = new Player { Id = Guid.Parse("00000000-0000-0000-0000-000000000002"), Name = "B", StartingRank = 2, Rating = new RatingProfile { ManualTwz = 1900 }, Status = PlayerStatus.Withdrawn };
        var c = new Player { Id = Guid.Parse("00000000-0000-0000-0000-000000000003"), Name = "C", StartingRank = 3, Rating = new RatingProfile { ManualTwz = 1800 } };

        var tournament = new TournamentState
        {
            Name = "Withdrawal Behaviour Snapshot",
            Settings = new TournamentSettings { Format = TournamentFormat.RoundRobin }
        };
        tournament.Players.AddRange(new[] { a, b, c });

        // Runde 1: A schlaegt B (bevor B zurueckgezogen wurde), C spielfrei.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, a.Id, b.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Bye(2, c.Id)
            }
        });

        // Runde 2: A - C Remis. B ist inzwischen zurueckgezogen und wird nicht mehr gepaart.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, a.Id, c.Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);

        // B ist korrekt nicht mehr in der Tabelle.
        Assert.DoesNotContain(standings, row => row.Name == "B");

        // BEFUND (kein Soll-Zustand!): A zeigt nur 0.5 statt der korrekten 1.5 Punkte - der
        // Sieg gegen B aus Runde 1 geht verloren, weil ApplyPairing die Partie ueberspringt,
        // sobald ein Spieler nicht mehr in der aktiven Zeilen-Map steht.
        var rowA = Assert.Single(standings, row => row.Name == "A");
        Assert.Equal(0.5m, rowA.Points);
    }
}
