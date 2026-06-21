using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Invariante: Die Swiss-Engine darf nur dann ein Rematch erzeugen, wenn es bei dem von der Engine
/// gewählten Spielfeld (nach Bye-Vergabe) und der bisherigen Begegnungshistorie keine
/// rematchfreie vollständige Paarung mehr gibt. Eine reine Greedy-Heuristik verletzt das, weil sie
/// sich früh festlegt und später Spieler in unnötige Wiederholungen zwingt; eine global optimale
/// Minimum-Penalty-Paarung erfüllt die Invariante.
/// </summary>
public sealed class SwissPairingOptimalMatchingTests
{
    [Theory]
    [InlineData(8, 6)]
    [InlineData(10, 7)]
    [InlineData(12, 7)]
    [InlineData(13, 7)]
    [InlineData(16, 7)]
    public void GenerateNextRound_NeverCreatesAvoidableRematch_AcrossManySeeds(int playerCount, int rounds)
    {
        var violations = new List<string>();

        for (var seed = 0; seed < 60; seed++)
        {
            var random = new Random(seed * 7919 + playerCount);
            var tournament = CreateTournament(playerCount);
            var engine = new SwissPairingEngine();

            for (var roundNumber = 1; roundNumber <= rounds; roundNumber++)
            {
                if (tournament.Players.Count(p => p.IsActive) < 2)
                {
                    break;
                }

                var round = engine.GenerateNextRound(tournament);

                // Begegnungshistorie aus dem Stand VOR dieser Runde.
                var history = BuildOpponentHistory(tournament);
                var gamePlayers = round.Pairings
                    .Where(p => !p.IsBye && p.WhitePlayerId is not null && p.BlackPlayerId is not null)
                    .SelectMany(p => new[] { p.WhitePlayerId!.Value, p.BlackPlayerId!.Value })
                    .ToList();

                var engineHasRematch = round.Pairings.Any(p =>
                    !p.IsBye && p.WhitePlayerId is not null && p.BlackPlayerId is not null &&
                    history.TryGetValue(p.WhitePlayerId.Value, out var opps) && opps.Contains(p.BlackPlayerId.Value));

                if (engineHasRematch && RematchFreePerfectMatchingExists(gamePlayers, history))
                {
                    violations.Add($"P={playerCount} seed={seed} Runde={roundNumber}: vermeidbares Rematch erzeugt.");
                }

                // Zufällige, aber deterministische Ergebnisse anwenden.
                tournament.Rounds.Add(round with
                {
                    Pairings = round.Pairings
                        .Select(p => p.IsBye ? p : p with { Result = RandomResult(random) })
                        .ToList()
                });
            }
        }

        Assert.True(violations.Count == 0, string.Join(Environment.NewLine, violations.Take(20)));
    }

    private static GameResult RandomResult(Random random) => random.Next(3) switch
    {
        0 => new GameResult(GameResultKind.WhiteWin),
        1 => new GameResult(GameResultKind.BlackWin),
        _ => new GameResult(GameResultKind.Draw)
    };

    private static Dictionary<Guid, HashSet<Guid>> BuildOpponentHistory(TournamentState tournament)
    {
        var history = tournament.Players.ToDictionary(p => p.Id, _ => new HashSet<Guid>());
        foreach (var round in tournament.Rounds)
        {
            foreach (var pairing in round.Pairings)
            {
                if (pairing.IsBye || pairing.WhitePlayerId is null || pairing.BlackPlayerId is null)
                {
                    continue;
                }

                history[pairing.WhitePlayerId.Value].Add(pairing.BlackPlayerId.Value);
                history[pairing.BlackPlayerId.Value].Add(pairing.WhitePlayerId.Value);
            }
        }

        return history;
    }

    private static bool RematchFreePerfectMatchingExists(IReadOnlyList<Guid> players, Dictionary<Guid, HashSet<Guid>> history)
    {
        if (players.Count % 2 != 0)
        {
            return false;
        }

        var matched = new bool[players.Count];
        return Match(0);

        bool Match(int from)
        {
            var i = from;
            while (i < players.Count && matched[i])
            {
                i++;
            }

            if (i >= players.Count)
            {
                return true;
            }

            matched[i] = true;
            for (var j = i + 1; j < players.Count; j++)
            {
                if (matched[j])
                {
                    continue;
                }

                if (history[players[i]].Contains(players[j]))
                {
                    continue; // wäre Rematch
                }

                matched[j] = true;
                if (Match(i + 1))
                {
                    matched[j] = false;
                    matched[i] = false;
                    return true;
                }

                matched[j] = false;
            }

            matched[i] = false;
            return false;
        }
    }

    private static TournamentState CreateTournament(int playerCount)
    {
        var tournament = new TournamentState
        {
            Name = "Swiss Optimal Matching",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 9 }
        };

        for (var i = 1; i <= playerCount; i++)
        {
            tournament.Players.Add(new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Spieler {i}",
                StartingRank = i,
                Rating = new RatingProfile { ManualTwz = 2200 - i * 17 }
            });
        }

        return tournament;
    }
}
