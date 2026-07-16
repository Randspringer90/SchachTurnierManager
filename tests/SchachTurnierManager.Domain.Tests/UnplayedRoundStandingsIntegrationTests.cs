using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-FACH-001: Owner-adaptierte Integrationsmatrix auf Basis von Marcels PR #10.
/// Die Szenarien bilden den seit 1. März 2026 gültigen Buchholz-Scope ab, ohne
/// Sonneborn-Berger, Direktvergleich oder Performance auszuweiten.
/// </summary>
public sealed class UnplayedRoundStandingsIntegrationTests
{
    [Fact]
    public void DefaultMode_KeepsByeOutsideBuchholz()
    {
        var tournament = ThreePlayerTournament(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, plannedRounds: 1);
        var (a, b, c) = (tournament.Players[0], tournament.Players[1], tournament.Players[2]);
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteWin),
            Pairing.Bye(2, c.Id)));

        var cRow = Row(tournament, c);

        Assert.Equal(1m, cRow.Points);
        Assert.Equal(0m, cRow.Buchholz);
        Assert.Equal(0m, cRow.BuchholzCutOne);
    }

    [Fact]
    public void FideMode_ByeUsesOwnScoreCappedByDrawPointsTimesRounds()
    {
        var tournament = ThreePlayerTournament(UnplayedRoundBuchholzMode.FideVirtualOpponent, plannedRounds: 1);
        var (a, b, c) = (tournament.Players[0], tournament.Players[1], tournament.Players[2]);
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteWin),
            Pairing.Bye(2, c.Id)));

        var cRow = Row(tournament, c);

        Assert.Equal(1m, cRow.Points);
        Assert.Equal(0.5m, cRow.Buchholz);
        Assert.Equal(0.5m, cRow.BuchholzCutOne);
        Assert.Equal(0.5m, cRow.BuchholzCutTwo);
        Assert.Equal(0.5m, cRow.MedianBuchholz);
    }

    [Theory]
    [InlineData(ForfeitTiebreakPolicy.ExcludeForfeitsFromTiebreaks, 4.0)]
    [InlineData(ForfeitTiebreakPolicy.CountForfeitOpponentForBuchholzOnly, 5.0)]
    [InlineData(ForfeitTiebreakPolicy.CountForfeitsAsNormalGames, 5.0)]
    public void ForfeitPolicy_PrecedesDummyAndNeverDoubleCounts(
        ForfeitTiebreakPolicy policy,
        double expectedBuchholz)
    {
        var players = Players(4);
        var (a, b, c, d) = (players[0], players[1], players[2], players[3]);
        var tournament = Tournament(players, new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 3,
            ForfeitTiebreakPolicy = policy,
            UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent
        });
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteForfeitWin),
            Game(2, c, d, GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(2,
            Game(1, a, c, GameResultKind.BlackWin),
            Game(2, b, d, GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(3,
            Game(1, a, d, GameResultKind.BlackWin),
            Game(2, b, c, GameResultKind.WhiteWin)));

        var aRow = Row(tournament, a);

        Assert.Equal(1m, aRow.Points);
        Assert.Equal((decimal)expectedBuchholz, aRow.Buchholz);
    }

    [Fact]
    public void DoubleForfeit_IsPlayerSpecificVurAndUsesFideCutRule()
    {
        var players = Players(4);
        var (a, b, c, d) = (players[0], players[1], players[2], players[3]);
        var tournament = Tournament(players, FideSettings(plannedRounds: 2));
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.DoubleForfeit),
            Game(2, c, d, GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(2,
            Game(1, a, c, GameResultKind.WhiteWin),
            Game(2, b, d, GameResultKind.WhiteWin)));

        var aRow = Row(tournament, a);
        var bRow = Row(tournament, b);

        Assert.Equal(2m, aRow.Buchholz);
        Assert.Equal(1m, aRow.BuchholzCutOne);
        Assert.Equal(1m, bRow.Buchholz);
        Assert.Equal(0m, bRow.BuchholzCutOne); // VUR-Beitrag 1 wird vor realem Minimum 0 gestrichen.
    }

    [Fact]
    public void ForfeitDummyCap_UsesScheduledOpponentsArticle16AdjustedScore()
    {
        var players = Players(3);
        var (a, b, c) = (players[0], players[1] with { Status = PlayerStatus.Withdrawn }, players[2]);
        var tournament = Tournament(new[] { a, b, c }, FideSettings(plannedRounds: 2));
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteForfeitWin),
            Pairing.Bye(2, c.Id)));
        tournament.Rounds.Add(Round(2, Game(1, a, c, GameResultKind.WhiteWin)));

        var aRow = Row(tournament, a);

        // B hat 0 reale Punkte; die abschließende Nullpunkt-Bye nach dem Rückzug
        // wird für seine Gegner nach Art. 16.3.2 als Remis bewertet: Dummy-Cap = 0,5.
        // Dazu kommt der reale Gegner C mit 1,0 Punkt aus seinem Bye.
        Assert.Equal(1.5m, aRow.Buchholz);
    }

    [Fact]
    public void NotPlayed_IsIgnoredWhileOpenAndAddedOnlyAfterRoundFinalization()
    {
        var open = NotPlayedScenario(RoundResultStatus.Open);
        var complete = NotPlayedScenario(RoundResultStatus.Complete);

        Assert.Equal(1m, Row(open.Tournament, open.A).Buchholz);
        Assert.Equal(2m, Row(complete.Tournament, complete.A).Buchholz);
    }

    [Fact]
    public void UnpairedPlayer_GetsDummyOnlyInFinalizedRound()
    {
        var open = UnpairedScenario(RoundResultStatus.Open);
        var complete = UnpairedScenario(RoundResultStatus.Complete);

        Assert.Equal(1m, Row(open.Tournament, open.C).Buchholz);
        Assert.Equal(2m, Row(complete.Tournament, complete.C).Buchholz);
    }

    [Fact]
    public void FideMode_DoesNotApplyArticle16ToRoundRobin()
    {
        var players = Players(3);
        var tournament = Tournament(players, FideSettings(plannedRounds: 1) with { Format = TournamentFormat.RoundRobin });
        tournament.Rounds.Add(Round(1,
            Game(1, players[0], players[1], GameResultKind.WhiteWin),
            Pairing.Bye(2, players[2].Id)));

        Assert.Equal(0m, Row(tournament, players[2]).Buchholz);
    }

    [Fact]
    public void FideBuchholzMode_DoesNotChangeSonnebornDirectEncounterOrPerformance()
    {
        var defaultTournament = UnchangedTiebreakScenario(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds);
        var fideTournament = UnchangedTiebreakScenario(UnplayedRoundBuchholzMode.FideVirtualOpponent);
        var defaultRow = Row(defaultTournament, defaultTournament.Players[0]);
        var fideRow = Row(fideTournament, fideTournament.Players[0]);

        Assert.NotEqual(defaultRow.Buchholz, fideRow.Buchholz);
        Assert.Equal(defaultRow.SonnebornBerger, fideRow.SonnebornBerger);
        Assert.Equal(defaultRow.DirectEncounter, fideRow.DirectEncounter);
        Assert.Equal(defaultRow.TournamentPerformance, fideRow.TournamentPerformance);
    }

    private static (TournamentState Tournament, Player A) NotPlayedScenario(RoundResultStatus status)
    {
        var players = Players(3);
        var (a, b, c) = (players[0], players[1], players[2]);
        var tournament = Tournament(players, FideSettings(plannedRounds: 2));
        tournament.Rounds.Add(Round(1,
            Game(1, a, c, GameResultKind.WhiteWin),
            Pairing.Bye(2, b.Id)));
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            ResultStatus = status,
            Pairings = new[]
            {
                Pairing.Game(1, a.Id, b.Id),
                Pairing.Bye(2, c.Id)
            }
        });
        return (tournament, a);
    }

    private static (TournamentState Tournament, Player C) UnpairedScenario(RoundResultStatus status)
    {
        var players = Players(3);
        var (a, b, c) = (players[0], players[1], players[2]);
        var tournament = Tournament(players, FideSettings(plannedRounds: 2));
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteWin),
            Pairing.Bye(2, c.Id)));
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            ResultStatus = status,
            Pairings = new[] { Game(1, a, b, GameResultKind.WhiteWin) }
        });
        return (tournament, c);
    }

    private static TournamentState UnchangedTiebreakScenario(UnplayedRoundBuchholzMode mode)
    {
        var players = Players(3);
        var (a, b, c) = (players[0], players[1], players[2]);
        var tournament = Tournament(players, FideSettings(plannedRounds: 2) with { UnplayedRoundBuchholzMode = mode });
        tournament.Rounds.Add(Round(1,
            Game(1, a, b, GameResultKind.WhiteWin),
            Pairing.Bye(2, c.Id)));
        tournament.Rounds.Add(Round(2,
            Pairing.Bye(1, a.Id),
            Game(2, b, c, GameResultKind.WhiteWin)));
        return tournament;
    }

    private static TournamentState ThreePlayerTournament(UnplayedRoundBuchholzMode mode, int plannedRounds) =>
        Tournament(Players(3), new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = plannedRounds,
            UnplayedRoundBuchholzMode = mode
        });

    private static TournamentSettings FideSettings(int plannedRounds) => new()
    {
        Format = TournamentFormat.Swiss,
        PlannedRounds = plannedRounds,
        UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent
    };

    private static StandingRow Row(TournamentState tournament, Player player) =>
        Assert.Single(new StandingsCalculator().Calculate(tournament), row => row.PlayerId == player.Id);

    private static TournamentState Tournament(IEnumerable<Player> players, TournamentSettings settings)
    {
        var tournament = new TournamentState { Name = "STM-FACH-001", Settings = settings };
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

    private static List<Player> Players(int count) => Enumerable.Range(1, count).Select(index => new Player
    {
        Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
        Name = $"P{index}",
        StartingRank = index,
        Rating = new RatingProfile { ManualTwz = 2100 - index * 100 }
    }).ToList();
}
