using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class SwissPairingRegressionGateTests
{
    [Fact]
    public void FirstRound_EvenPlayerCount_PairsEveryActivePlayerExactlyOnceAndSequentialBoards()
    {
        var players = CreatePlayers(8);
        var tournament = CreateTournament(players);

        var round = new SwissPairingEngine().GenerateNextRound(tournament);

        Assert.Equal(1, round.RoundNumber);
        Assert.Equal(4, round.Pairings.Count);
        Assert.DoesNotContain(round.Pairings, pairing => pairing.IsBye);
        AssertSequentialBoardNumbers(round);
        AssertPlayersAppearExactlyOnce(round, players.Select(player => player.Id));
    }

    [Fact]
    public void FirstRound_OddPlayerCount_AssignsExactlyOneByeAndPairsAllOthersExactlyOnce()
    {
        var players = CreatePlayers(7);
        var tournament = CreateTournament(players);

        var round = new SwissPairingEngine().GenerateNextRound(tournament);

        Assert.Equal(1, round.RoundNumber);
        Assert.Equal(4, round.Pairings.Count);
        Assert.Single(round.Pairings, pairing => pairing.IsBye);
        AssertSequentialBoardNumbers(round);
        AssertPlayersAppearExactlyOnce(round, players.Select(player => player.Id));
    }

    [Fact]
    public void SecondRound_AfterDecisiveFirstRound_AvoidsImmediateRematchesAndCriticalQuality()
    {
        var players = CreatePlayers(8);
        var tournament = CreateTournament(players);
        var engine = new SwissPairingEngine();
        var firstRound = engine.GenerateNextRound(tournament);
        tournament.Rounds.Add(CompleteRound(firstRound, GameResultKind.WhiteWin));

        var secondRound = engine.GenerateNextRound(tournament);
        var report = new PairingQualityAnalyzer().Analyze(tournament, secondRound);

        Assert.Equal(2, secondRound.RoundNumber);
        Assert.DoesNotContain(secondRound.Pairings.Where(pairing => !pairing.IsBye), pairing => HasEncounteredPair(firstRound, pairing));
        Assert.Equal(0, report.RematchCount);
        Assert.False(report.HasCriticalIssues);
        AssertPlayersAppearExactlyOnce(secondRound, players.Select(player => player.Id));
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Swiss Regression Gate",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers(int count)
    {
        return Enumerable.Range(1, count)
            .Select(index => new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
                Name = $"Gate Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2300 - index * 15 }
            })
            .ToList();
    }

    private static TournamentRound CompleteRound(TournamentRound round, GameResultKind result)
    {
        return round with
        {
            Pairings = round.Pairings
                .Select(pairing => pairing.IsBye ? pairing : pairing with { Result = new GameResult(result) })
                .ToArray(),
            ResultStatus = RoundResultStatus.Complete
        };
    }

    private static bool HasEncounteredPair(TournamentRound previousRound, Pairing candidate)
    {
        return previousRound.Pairings.Any(previous => IsSamePair(previous, candidate));
    }

    private static bool IsSamePair(Pairing left, Pairing right)
    {
        if (left.WhitePlayerId is null || left.BlackPlayerId is null || right.WhitePlayerId is null || right.BlackPlayerId is null)
        {
            return false;
        }

        return (left.WhitePlayerId == right.WhitePlayerId && left.BlackPlayerId == right.BlackPlayerId) ||
               (left.WhitePlayerId == right.BlackPlayerId && left.BlackPlayerId == right.WhitePlayerId);
    }

    private static void AssertSequentialBoardNumbers(TournamentRound round)
    {
        Assert.Equal(Enumerable.Range(1, round.Pairings.Count), round.Pairings.Select(pairing => pairing.BoardNumber));
    }

    private static void AssertPlayersAppearExactlyOnce(TournamentRound round, IEnumerable<Guid> expectedPlayerIds)
    {
        var pairedPlayerIds = round.Pairings
            .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
            .Where(playerId => playerId is not null)
            .Select(playerId => playerId!.Value)
            .OrderBy(playerId => playerId)
            .ToArray();

        Assert.Equal(expectedPlayerIds.OrderBy(playerId => playerId), pairedPlayerIds);
        Assert.Equal(pairedPlayerIds.Length, pairedPlayerIds.Distinct().Count());
    }
}
