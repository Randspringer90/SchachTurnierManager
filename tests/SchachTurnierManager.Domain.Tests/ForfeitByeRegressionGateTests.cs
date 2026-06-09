using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ForfeitByeRegressionGateTests
{
    [Fact]
    public void ForfeitPolicy_NormalGames_CountsOpponentForBuchholzAndSonnebornButNotPerformanceForForfeitGame()
    {
        var white = PlayerWithTwz("Weiß", 1800, 1);
        var black = PlayerWithTwz("Schwarz", 1700, 2);
        var third = PlayerWithTwz("Dritter", 1600, 3);
        var fourth = PlayerWithTwz("Vierter", 1500, 4);
        var tournament = CreateTournament(ForfeitTiebreakPolicy.CountForfeitsAsNormalGames, white, black, third, fourth);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) },
                Pairing.Game(2, third.Id, fourth.Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, black.Id, third.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, white.Id, fourth.Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);
        var whiteRow = Assert.Single(standings, row => row.PlayerId == white.Id);

        Assert.Equal(1.5m, whiteRow.Points);
        Assert.Equal(1.5m, whiteRow.Buchholz);
        Assert.Equal(1.25m, whiteRow.SonnebornBerger);
        Assert.Equal(1600m, whiteRow.AverageOpponentRating);
        Assert.NotNull(whiteRow.TournamentPerformance);
    }

    [Fact]
    public void ForfeitPolicy_BuchholzOnly_CountsOpponentForBuchholzButNotSonnebornForForfeitGame()
    {
        var white = PlayerWithTwz("Weiß", 1800, 1);
        var black = PlayerWithTwz("Schwarz", 1700, 2);
        var third = PlayerWithTwz("Dritter", 1600, 3);
        var fourth = PlayerWithTwz("Vierter", 1500, 4);
        var tournament = CreateTournament(ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly, white, black, third, fourth);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) },
                Pairing.Game(2, third.Id, fourth.Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, black.Id, third.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, white.Id, fourth.Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);
        var whiteRow = Assert.Single(standings, row => row.PlayerId == white.Id);

        Assert.Equal(1.5m, whiteRow.Points);
        Assert.Equal(1.5m, whiteRow.Buchholz);
        Assert.Equal(0.25m, whiteRow.SonnebornBerger);
        Assert.Equal(1600m, whiteRow.AverageOpponentRating);
        Assert.NotNull(whiteRow.TournamentPerformance);
    }

    [Fact]
    public void ForfeitPolicy_Default_ExcludesForfeitOpponentFromBuchholzSonnebornAndOpponentAverage()
    {
        var white = PlayerWithTwz("Weiß", 1800, 1);
        var black = PlayerWithTwz("Schwarz", 1700, 2);
        var third = PlayerWithTwz("Dritter", 1600, 3);
        var fourth = PlayerWithTwz("Vierter", 1500, 4);
        var tournament = CreateTournament(ForfeitTiebreakPolicy.ExcludeForfeitsFromTiebreaks, white, black, third, fourth);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) },
                Pairing.Game(2, third.Id, fourth.Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);
        var whiteRow = Assert.Single(standings, row => row.PlayerId == white.Id);

        Assert.Equal(1m, whiteRow.Points);
        Assert.Equal(0m, whiteRow.Buchholz);
        Assert.Equal(0m, whiteRow.SonnebornBerger);
        Assert.Equal(0m, whiteRow.AverageOpponentRating);
        Assert.Null(whiteRow.TournamentPerformance);
    }

    [Fact]
    public void Bye_CountByeAsWinSettingControlsWinCounterWithoutAddingOpponentTiebreaks()
    {
        var player = PlayerWithTwz("Bye-Spieler", 1800, 1);
        var tournament = new TournamentState
        {
            Name = "Bye Regression Gate",
            Settings = new TournamentSettings { CountByeAsWin = true },
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
        Assert.Equal(1, row.Wins);
        Assert.Equal(0m, row.Buchholz);
        Assert.Equal(0m, row.SonnebornBerger);
        Assert.Equal(0m, row.AverageOpponentRating);
        Assert.Null(row.TournamentPerformance);
    }

    private static TournamentState CreateTournament(ForfeitTiebreakPolicy policy, params Player[] players)
    {
        var tournament = new TournamentState
        {
            Name = "Forfeit Regression Gate",
            Settings = new TournamentSettings { ForfeitTiebreakPolicy = policy }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static Player PlayerWithTwz(string name, int twz, int startingRank)
    {
        return new Player
        {
            Id = Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}"),
            Name = name,
            StartingRank = startingRank,
            Rating = new RatingProfile { ManualTwz = twz }
        };
    }
}
