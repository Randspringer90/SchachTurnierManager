using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class SwissPairingEngineTests
{
    [Fact]
    public void GenerateNextRound_ForOddField_AssignsExactlyOneBye()
    {
        var tournament = new TournamentState
        {
            Name = "Test Swiss",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        for (var i = 1; i <= 5; i++)
        {
            tournament.Players.Add(new Player { Name = $"Spieler {i}", StartingRank = i, Rating = new RatingProfile { ManualTwz = 2000 - i } });
        }

        var round = new SwissPairingEngine().GenerateNextRound(tournament);

        Assert.Single(round.Pairings.Where(p => p.IsBye));
        Assert.Equal(3, round.Pairings.Count);
    }
}
