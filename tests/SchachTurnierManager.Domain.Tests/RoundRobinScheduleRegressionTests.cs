using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class RoundRobinScheduleRegressionTests
{
    [Theory]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    [InlineData(6)]
    [InlineData(7)]
    [InlineData(8)]
    [InlineData(9)]
    [InlineData(10)]
    [InlineData(11)]
    [InlineData(12)]
    public void CompleteSchedule_HasUniqueOpponentsBalancedColoursAndExactlyOneOddFieldBye(int count)
    {
        var players = Players(count);
        var rounds = new RoundRobinPairingEngine().GenerateAllRounds(players, TwzSource.ManualThenDwzThenElo);
        Assert.Equal(count % 2 == 0 ? count - 1 : count, rounds.Count);
        var games = rounds.SelectMany(round => round.Pairings).Where(pair => !pair.IsBye).ToList();
        Assert.Equal(count * (count - 1) / 2, games.Count);
        var opponents = games.Select(pair => string.Join('/', new[] { pair.WhitePlayerId, pair.BlackPlayerId }.OrderBy(id => id))).ToHashSet();
        Assert.Equal(games.Count, opponents.Count);
        foreach (var round in rounds)
        {
            var ids = round.Pairings.SelectMany(pair => new[] { pair.WhitePlayerId, pair.BlackPlayerId }).Where(id => id.HasValue).ToList();
            Assert.Equal(count, ids.Count);
            Assert.Equal(count, ids.Distinct().Count());
        }
        foreach (var player in players)
        {
            var whites = games.Count(pair => pair.WhitePlayerId == player.Id);
            var blacks = games.Count(pair => pair.BlackPlayerId == player.Id);
            Assert.True(Math.Abs(whites - blacks) <= 1, $"Colour balance for rank {player.StartingRank}: {whites}/{blacks}.");
            Assert.Equal(count % 2, rounds.SelectMany(round => round.Pairings).Count(pair => pair.IsBye && pair.WhitePlayerId == player.Id));
        }
    }

    [Theory]
    [InlineData(4, "1-4,2-3|4-3,1-2|2-4,3-1")]
    [InlineData(6, "1-6,2-5,3-4|6-4,5-3,1-2|2-6,3-1,4-5|6-5,1-4,2-3|3-6,4-2,5-1")]
    public void NewSchedule_MatchesOfficialSmallBergerTables(int count, string expected)
    {
        // Independent published reference: FIDE Handbook C.05 Annex 1, checked 2026-10-28.
        var players = Players(count);
        var ranks = players.ToDictionary(player => player.Id, player => player.StartingRank);
        var rounds = new RoundRobinPairingEngine().GenerateAllRounds(players, TwzSource.ManualThenDwzThenElo);
        var actual = string.Join('|', rounds.Select(round => string.Join(',', round.Pairings.Select(pair => $"{ranks[pair.WhitePlayerId!.Value]}-{ranks[pair.BlackPlayerId!.Value]}"))));
        Assert.Equal(expected, actual);
    }

    private static List<Player> Players(int count) => Enumerable.Range(1, count)
        .Select(rank => new Player { Name = $"Synthetic {rank:00}", StartingRank = rank, Rating = new RatingProfile { ManualTwz = 2000 - rank } }).ToList();
}
