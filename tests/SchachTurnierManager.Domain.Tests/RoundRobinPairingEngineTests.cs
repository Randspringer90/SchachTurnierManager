using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class RoundRobinPairingEngineTests
{
    [Fact]
    public void GenerateAllRounds_ForFourPlayers_CreatesSixUniqueGames()
    {
        var players = Enumerable.Range(1, 4)
            .Select(i => new Player { Name = $"Spieler {i}", StartingRank = i, Rating = new RatingProfile { ManualTwz = 2000 - i } })
            .ToList();

        var rounds = new RoundRobinPairingEngine().GenerateAllRounds(players, TwzSource.ManualThenDwzThenElo);

        Assert.Equal(3, rounds.Count);
        Assert.Equal(6, rounds.SelectMany(r => r.Pairings).Count(p => !p.IsBye));

        var uniquePairs = rounds
            .SelectMany(r => r.Pairings)
            .Where(p => p.WhitePlayerId is not null && p.BlackPlayerId is not null)
            .Select(p => string.Join('-', new[] { p.WhitePlayerId!.Value, p.BlackPlayerId!.Value }.OrderBy(x => x)))
            .ToHashSet();

        Assert.Equal(6, uniquePairs.Count);
    }
}
