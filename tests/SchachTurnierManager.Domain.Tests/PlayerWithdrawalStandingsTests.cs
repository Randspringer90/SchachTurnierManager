using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Regressionstests für den von Marcel in PR #10 gefundenen Withdrawal-Bug.
/// Historische Partien werden vollständig gerechnet; nur die sichtbare Rangliste
/// wird anschließend auf aktive Spieler begrenzt.
/// </summary>
public sealed class PlayerWithdrawalStandingsTests
{
    [Theory]
    [InlineData(GameResultKind.WhiteWin, 0.0)]
    [InlineData(GameResultKind.BlackWin, 1.0)]
    [InlineData(GameResultKind.Draw, 0.5)]
    public void WithdrawalAfterResult_ActiveOpponentKeepsHistoricalPoints(
        GameResultKind result,
        double expectedActivePoints)
    {
        var withdrawn = Player(1, PlayerStatus.Withdrawn);
        var active = Player(2);
        var tournament = Tournament(withdrawn, active);
        tournament.Rounds.Add(Round(1, Game(1, withdrawn, active, result)));

        var standings = new StandingsCalculator().Calculate(tournament);

        Assert.DoesNotContain(standings, row => row.PlayerId == withdrawn.Id);
        Assert.Equal((decimal)expectedActivePoints, Assert.Single(standings).Points);
    }

    [Fact]
    public void WithdrawnPlayer_HistoricalScoreStillContributesToActiveOpponentBuchholz()
    {
        var withdrawn = Player(1, PlayerStatus.Withdrawn);
        var active = Player(2);
        var third = Player(3);
        var tournament = Tournament(withdrawn, active, third);
        tournament.Rounds.Add(Round(1,
            Game(1, withdrawn, active, GameResultKind.Draw),
            Pairing.Bye(2, third.Id)));
        tournament.Rounds.Add(Round(2,
            Game(1, withdrawn, third, GameResultKind.WhiteWin),
            Pairing.Bye(2, active.Id)));

        var activeRow = Assert.Single(new StandingsCalculator().Calculate(tournament), row => row.PlayerId == active.Id);

        Assert.Equal(1.5m, activeRow.Points);
        Assert.Equal(1.5m, activeRow.Buchholz); // Withdrawn: Remis + Sieg = 1,5.
    }

    [Fact]
    public void WithdrawalBeforeFirstGame_IsHiddenAndDoesNotChangeActiveScores()
    {
        var withdrawn = Player(1, PlayerStatus.Withdrawn);
        var a = Player(2);
        var b = Player(3);
        var tournament = Tournament(withdrawn, a, b);
        tournament.Rounds.Add(Round(1, Game(1, a, b, GameResultKind.Draw)));

        var standings = new StandingsCalculator().Calculate(tournament);

        Assert.Equal(2, standings.Count);
        Assert.DoesNotContain(standings, row => row.PlayerId == withdrawn.Id);
        Assert.All(standings, row => Assert.Equal(0.5m, row.Points));
    }

    [Fact]
    public void MultipleWithdrawnPlayers_AreHiddenAndActivePlayerKeepsBothWins()
    {
        var withdrawnA = Player(1, PlayerStatus.Withdrawn);
        var withdrawnB = Player(2, PlayerStatus.Withdrawn);
        var active = Player(3);
        var tournament = Tournament(withdrawnA, withdrawnB, active);
        tournament.Rounds.Add(Round(1, Game(1, active, withdrawnA, GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(2, Game(1, withdrawnB, active, GameResultKind.BlackWin)));

        var row = Assert.Single(new StandingsCalculator().Calculate(tournament));

        Assert.Equal(active.Id, row.PlayerId);
        Assert.Equal(2m, row.Points);
        Assert.Equal(2, row.Wins);
    }

    private static TournamentState Tournament(params Player[] players)
    {
        var tournament = new TournamentState
        {
            Name = "Withdrawal Regression",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static TournamentRound Round(int number, params Pairing[] pairings) => new()
    {
        RoundNumber = number,
        ResultStatus = RoundResultStatus.Complete,
        Pairings = pairings
    };

    private static Pairing Game(int board, Player white, Player black, GameResultKind result) =>
        Pairing.Game(board, white.Id, black.Id) with { Result = new GameResult(result) };

    private static Player Player(int index, PlayerStatus status = PlayerStatus.Active) => new()
    {
        Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
        Name = $"P{index}",
        StartingRank = index,
        Status = status,
        Rating = new RatingProfile { ManualTwz = 2100 - index * 100 }
    };
}
