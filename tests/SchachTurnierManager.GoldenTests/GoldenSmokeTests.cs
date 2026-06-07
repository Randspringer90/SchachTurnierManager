using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.GoldenTests;

public sealed class GoldenSmokeTests
{
    [Fact]
    public void FourPlayerRoundRobin_HasExpectedRoundAndGameCount()
    {
        var players = new[]
        {
            new Player { Name = "A", StartingRank = 1 },
            new Player { Name = "B", StartingRank = 2 },
            new Player { Name = "C", StartingRank = 3 },
            new Player { Name = "D", StartingRank = 4 }
        };

        var rounds = new RoundRobinPairingEngine().GenerateAllRounds(players, TwzSource.ManualThenDwzThenElo);

        Assert.Equal(3, rounds.Count);
        Assert.All(rounds, round => Assert.Equal(2, round.Pairings.Count));
    }
}
