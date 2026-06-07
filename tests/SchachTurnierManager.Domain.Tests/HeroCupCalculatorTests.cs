using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class HeroCupCalculatorTests
{
    [Fact]
    public void Calculate_RanksPlayerWithBestScoreAgainstExpectationFirst()
    {
        var favorite = PlayerWithTwz("Favorit", 2200, 1);
        var underdog = PlayerWithTwz("Held", 1500, 2);
        var tournament = new TournamentState
        {
            Name = "Heldenpokal",
            Players = { favorite, underdog },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[] { Pairing.Game(1, underdog.Id, favorite.Id) with { Result = new GameResult(GameResultKind.WhiteWin) } }
                }
            }
        };

        var heroRows = new HeroCupCalculator().Calculate(tournament);

        Assert.Equal(underdog.Id, heroRows[0].PlayerId);
        Assert.True(heroRows[0].OverPerformance > 0.9m);
    }

    private static Player PlayerWithTwz(string name, int twz, int startingRank)
    {
        return new Player
        {
            Id = Guid.NewGuid(),
            Name = name,
            StartingRank = startingRank,
            Rating = new RatingProfile { ManualTwz = twz }
        };
    }
}
