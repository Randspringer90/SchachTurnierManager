using System.Diagnostics;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-FACH-003: Last-, Determinismus- und Invariantentests fuer grosse FIDE-Dutch-Felder.
/// Alle Daten sind synthetisch und deterministisch.
/// </summary>
public sealed class FideDutchLargeFieldTests
{
    [Theory]
    [InlineData(21)]
    [InlineData(50)]
    public void FirstRound_GoldenPairingMatchesDutchSplitAndColourRule(int playerCount)
    {
        var tournament = CreateTournament(playerCount);
        var strategy = new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive);

        var round = strategy.GenerateNextRound(tournament);

        Assert.Equal(ExpectedFirstRound(playerCount), DescribeRound(tournament, round));
    }

    [Theory]
    [InlineData(50, 2)]
    [InlineData(100, 10)]
    [InlineData(200, 60)]
    public void FirstRound_CompletesInsideDocumentedBudget(int playerCount, int budgetSeconds)
    {
        var tournament = CreateTournament(playerCount);
        var strategy = new FideDutchPairingStrategy();
        var stopwatch = Stopwatch.StartNew();

        var round = strategy.GenerateNextRound(tournament);

        stopwatch.Stop();
        Assert.True(
            stopwatch.Elapsed < TimeSpan.FromSeconds(budgetSeconds),
            $"{playerCount} Spieler: {stopwatch.Elapsed.TotalSeconds:0.000}s >= Budget {budgetSeconds}s.");
        AssertEveryPlayerPlacedExactlyOnce(tournament, round);
    }

    [Theory]
    [InlineData(21, 5, 17)]
    [InlineData(50, 5, 23)]
    [InlineData(100, 4, 31)]
    [InlineData(200, 3, 47)]
    public void LargeFields_PreserveAbsoluteCriteriaAcrossRounds(int playerCount, int rounds, int seed)
    {
        var tournament = PlayTournament(playerCount, rounds, seed);

        AssertNoRematches(tournament);
        AssertNoRepeatedByes(tournament);
        AssertColourBounds(tournament);

        foreach (var round in tournament.Rounds)
        {
            AssertEveryPlayerPlacedExactlyOnce(tournament, round);
        }
    }

    [Theory]
    [InlineData(21, 5, 17)]
    [InlineData(50, 5, 23)]
    [InlineData(100, 3, 31)]
    [InlineData(200, 2, 47)]
    public void LargeFields_SameInputProducesIdenticalPairings(int playerCount, int rounds, int seed)
    {
        var first = PlayTournament(playerCount, rounds, seed);
        var second = PlayTournament(playerCount, rounds, seed);

        Assert.Equal(DescribeTournament(first), DescribeTournament(second));
    }

    [Fact]
    public void SearchBudgetExceeded_FailsClosedWithoutPartialRound()
    {
        var tournament = CreateTournament(50);
        var strategy = new FideDutchPairingStrategy(new FideDutchSearchOptions
        {
            TimeoutOverride = TimeSpan.Zero
        });

        var exception = Assert.Throws<FideDutchPairingTimeoutException>(
            () => strategy.GenerateNextRound(tournament));

        Assert.Equal(50, exception.PlayerCount);
        Assert.Equal(TimeSpan.Zero, exception.Budget);
        Assert.Contains("ohne Teilergebnis", exception.Message);
        Assert.Empty(tournament.Rounds);
    }

    private static TournamentState PlayTournament(int playerCount, int rounds, int seed)
    {
        var tournament = CreateTournament(playerCount);
        var strategy = new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive);
        var results = new DeterministicResults(seed);

        for (var roundNumber = 0; roundNumber < rounds; roundNumber++)
        {
            var next = strategy.GenerateNextRound(tournament);
            tournament.Rounds.Add(next with
            {
                Pairings = next.Pairings
                    .Select(pairing => pairing.IsBye
                        ? pairing
                        : pairing with { Result = new GameResult(results.NextResult()) })
                    .ToList(),
                ResultStatus = RoundResultStatus.Complete
            });
        }

        return tournament;
    }

    private static TournamentState CreateTournament(int playerCount)
    {
        var tournament = new TournamentState
        {
            Name = $"FIDE Dutch Large Field {playerCount}",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                SwissInitialColour = ChessColor.White,
                PlannedRounds = 5
            }
        };

        for (var index = 1; index <= playerCount; index++)
        {
            tournament.Players.Add(new Player
            {
                Id = PlayerId(index),
                Name = $"Large Field Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2600 - index * 5 }
            });
        }

        return tournament;
    }

    private static string[] ExpectedFirstRound(int playerCount)
    {
        var pairCount = playerCount / 2;
        var result = new List<string>(pairCount + playerCount % 2);

        for (var tpn = 1; tpn <= pairCount; tpn++)
        {
            var opponent = pairCount + tpn;
            var white = tpn % 2 == 1 ? tpn : opponent;
            var black = tpn % 2 == 1 ? opponent : tpn;
            result.Add($"Brett {tpn}: {white} - {black}");
        }

        if (playerCount % 2 == 1)
        {
            result.Add($"Brett {pairCount + 1}: {playerCount} - bye");
        }

        return result.ToArray();
    }

    private static void AssertEveryPlayerPlacedExactlyOnce(TournamentState tournament, TournamentRound round)
    {
        var expected = tournament.Players.Select(player => player.Id).OrderBy(id => id).ToArray();
        var placed = round.Pairings
            .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
            .Where(id => id is not null)
            .Select(id => id!.Value)
            .OrderBy(id => id)
            .ToArray();

        Assert.Equal(expected, placed);
        Assert.True(round.Pairings.Count(pairing => pairing.IsBye) <= 1);
    }

    private static void AssertNoRematches(TournamentState tournament)
    {
        var repeated = tournament.Rounds
            .SelectMany(round => round.Pairings)
            .Where(pairing => !pairing.IsBye && pairing.WhitePlayerId is not null && pairing.BlackPlayerId is not null)
            .Select(pairing => pairing.WhitePlayerId!.Value.CompareTo(pairing.BlackPlayerId!.Value) < 0
                ? (pairing.WhitePlayerId!.Value, pairing.BlackPlayerId!.Value)
                : (pairing.BlackPlayerId!.Value, pairing.WhitePlayerId!.Value))
            .GroupBy(pair => pair)
            .Where(group => group.Count() > 1)
            .ToList();

        Assert.Empty(repeated);
    }

    private static void AssertNoRepeatedByes(TournamentState tournament)
    {
        var repeated = tournament.Rounds
            .SelectMany(round => round.Pairings)
            .Where(pairing => pairing.IsBye && pairing.WhitePlayerId is not null)
            .GroupBy(pairing => pairing.WhitePlayerId!.Value)
            .Where(group => group.Count() > 1)
            .ToList();

        Assert.Empty(repeated);
    }

    private static void AssertColourBounds(TournamentState tournament)
    {
        var sequences = tournament.Players.ToDictionary(player => player.Id, _ => new List<ChessColor>());

        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
            {
                if (pairing.WhitePlayerId is { } white)
                {
                    sequences[white].Add(ChessColor.White);
                }

                if (pairing.BlackPlayerId is { } black)
                {
                    sequences[black].Add(ChessColor.Black);
                }
            }
        }

        foreach (var sequence in sequences.Values)
        {
            var difference = sequence.Count(colour => colour == ChessColor.White) -
                             sequence.Count(colour => colour == ChessColor.Black);
            Assert.InRange(difference, -2, 2);

            for (var index = 2; index < sequence.Count; index++)
            {
                Assert.False(
                    sequence[index] == sequence[index - 1] && sequence[index] == sequence[index - 2],
                    "Ein Spieler erhielt dieselbe Farbe dreimal in Folge.");
            }
        }
    }

    private static string[] DescribeRound(TournamentState tournament, TournamentRound round)
    {
        var ranks = tournament.Players.ToDictionary(player => player.Id, player => player.StartingRank);

        return round.Pairings
            .OrderBy(pairing => pairing.BoardNumber)
            .Select(pairing => pairing.IsBye
                ? $"Brett {pairing.BoardNumber}: {ranks[pairing.WhitePlayerId!.Value]} - bye"
                : $"Brett {pairing.BoardNumber}: {ranks[pairing.WhitePlayerId!.Value]} - {ranks[pairing.BlackPlayerId!.Value]}")
            .ToArray();
    }

    private static string[] DescribeTournament(TournamentState tournament) =>
        tournament.Rounds
            .OrderBy(round => round.RoundNumber)
            .SelectMany(round => DescribeRound(tournament, round).Select(line => $"R{round.RoundNumber} {line}"))
            .ToArray();

    private static Guid PlayerId(int startingRank) =>
        Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}");

    private sealed class DeterministicResults(int seed)
    {
        private uint _state = (uint)(seed * 2654435761u + 1u);

        public GameResultKind NextResult()
        {
            _state = _state * 1664525u + 1013904223u;
            return ((_state >> 16) % 4) switch
            {
                0 => GameResultKind.Draw,
                1 => GameResultKind.BlackWin,
                _ => GameResultKind.WhiteWin
            };
        }
    }
}
