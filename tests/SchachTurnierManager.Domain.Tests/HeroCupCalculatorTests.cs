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

    [Theory]
    [InlineData(PlayerStatus.Withdrawn, true)]
    [InlineData(PlayerStatus.Withdrawn, false)]
    [InlineData(PlayerStatus.Paused, true)]
    [InlineData(PlayerStatus.Paused, false)]
    public void InactiveOpponent_DoesNotRemoveRatedGameFromActivePlayersScore(PlayerStatus status, bool activeIsWhite)
    {
        var white = PlayerWithTwz("Synthetic White", 1600, 1);
        var black = PlayerWithTwz("Synthetic Black", 1900, 2);
        var activeId = activeIsWhite ? white.Id : black.Id;
        var tournament = new TournamentState
        {
            Players = { white, black },
            Settings = new TournamentSettings { HeroCupMinimumRatedGames = 1 },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    ResultStatus = RoundResultStatus.Complete,
                    Pairings = new[] { Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteWin) } }
                }
            }
        };
        var calculator = new HeroCupCalculator();
        var before = calculator.Calculate(tournament).Single(row => row.PlayerId == activeId);
        var inactiveIndex = activeIsWhite ? 1 : 0;
        tournament.Players[inactiveIndex] = tournament.Players[inactiveIndex] with { Status = status };

        var after = Assert.Single(calculator.Calculate(tournament));

        // Only visibility/rank may change; the played game's complete contribution stays intact.
        Assert.Equal(before with { Rank = 1 }, after);
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
