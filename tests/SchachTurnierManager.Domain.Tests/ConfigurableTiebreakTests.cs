using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ConfigurableTiebreakTests
{
    [Fact]
    public void Standings_UseConfiguredTiebreakOrderAfterPoints()
    {
        var playerA = new Player { Id = Guid.NewGuid(), Name = "Alice", StartingRank = 2, Rating = new RatingProfile { ManualTwz = 1800 } };
        var playerB = new Player { Id = Guid.NewGuid(), Name = "Bernd", StartingRank = 1, Rating = new RatingProfile { ManualTwz = 1800 } };
        var playerC = new Player { Id = Guid.NewGuid(), Name = "Clara", StartingRank = 3, Rating = new RatingProfile { ManualTwz = 1800 } };
        var playerD = new Player { Id = Guid.NewGuid(), Name = "David", StartingRank = 4, Rating = new RatingProfile { ManualTwz = 1800 } };
        var tournament = new TournamentState
        {
            Name = "Wertungstest",
            Settings = new TournamentSettings
            {
                Tiebreaks = new[] { TiebreakType.StartingRank }
            }
        };
        tournament.Players.AddRange(new[] { playerA, playerB, playerC, playerD });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, playerA.Id, playerC.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, playerB.Id, playerD.Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, playerA.Id, playerD.Id) with { Result = new GameResult(GameResultKind.BlackWin) },
                Pairing.Game(2, playerB.Id, playerC.Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);

        Assert.True(standings.ToList().FindIndex(row => row.PlayerId == playerB.Id) < standings.ToList().FindIndex(row => row.PlayerId == playerA.Id));
    }
}
