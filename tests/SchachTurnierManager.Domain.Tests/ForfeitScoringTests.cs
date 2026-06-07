using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ForfeitScoringTests
{
    [Fact]
    public void Standings_DefaultPolicy_GivesForfeitPointButExcludesOpponentTiebreakAndPerformance()
    {
        var white = PlayerWithTwz("Weiß", 1800, 1);
        var black = PlayerWithTwz("Schwarz", 1700, 2);
        var tournament = new TournamentState
        {
            Name = "Kampflos",
            Settings = new TournamentSettings
            {
                ForfeitTiebreakPolicy = ForfeitTiebreakPolicy.ExcludeForfeitsFromTiebreaks
            },
            Players = { white, black },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[]
                    {
                        Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) }
                    }
                }
            }
        };

        var standings = new StandingsCalculator().Calculate(tournament);
        var whiteRow = Assert.Single(standings, row => row.PlayerId == white.Id);
        var blackRow = Assert.Single(standings, row => row.PlayerId == black.Id);

        Assert.Equal(1m, whiteRow.Points);
        Assert.Equal(1, whiteRow.Wins);
        Assert.Equal(0m, whiteRow.Buchholz);
        Assert.Equal(0m, whiteRow.SonnebornBerger);
        Assert.Null(whiteRow.TournamentPerformance);
        Assert.Equal(0m, blackRow.Buchholz);
    }

    [Fact]
    public void Standings_ForfeitPolicyBuchholzOnly_AddsOpponentButNoSonnebornOrPerformance()
    {
        var white = PlayerWithTwz("Weiß", 1800, 1);
        var black = PlayerWithTwz("Schwarz", 1700, 2);
        var third = PlayerWithTwz("Dritter", 1600, 3);
        var tournament = new TournamentState
        {
            Name = "Kampflos Buchholz",
            Settings = new TournamentSettings
            {
                ForfeitTiebreakPolicy = ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly
            },
            Players = { white, black, third },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[]
                    {
                        Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) },
                        Pairing.Bye(2, third.Id)
                    }
                }
            }
        };

        var standings = new StandingsCalculator().Calculate(tournament);
        var whiteRow = Assert.Single(standings, row => row.PlayerId == white.Id);

        Assert.Equal(0m, whiteRow.Buchholz);
        Assert.Equal(0m, whiteRow.SonnebornBerger);
        Assert.Null(whiteRow.TournamentPerformance);
        Assert.Equal(1700m, whiteRow.AverageOpponentRating);
    }

    [Fact]
    public void Bye_DoesNotCountAsWinByDefault()
    {
        var player = PlayerWithTwz("Bye-Spieler", 1800, 1);
        var tournament = new TournamentState
        {
            Name = "Bye",
            Players = { player },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[] { Pairing.Bye(1, player.Id) }
                }
            }
        };

        var row = Assert.Single(new StandingsCalculator().Calculate(tournament));

        Assert.Equal(1m, row.Points);
        Assert.Equal(0, row.Wins);
        Assert.Equal(0m, row.Buchholz);
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
