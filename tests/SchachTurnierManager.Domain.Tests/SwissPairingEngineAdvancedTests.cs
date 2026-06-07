using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class SwissPairingEngineAdvancedTests
{
    [Fact]
    public void GenerateNextRound_AvoidsRepeatByeWhenAlternativeExists()
    {
        var players = CreatePlayers(5);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Bye(1, players[4].Id),
                Pairing.Game(2, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(3, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new SwissPairingEngine().GenerateNextRound(tournament);
        var bye = Assert.Single(round.Pairings, p => p.IsBye);

        Assert.NotEqual(players[4].Id, bye.WhitePlayerId);
        Assert.Contains(round.Audit.Messages, message => message.Contains("Bye vergeben", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void GenerateNextRound_AvoidsRematchWhenPossible()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.BlackWin) }
            }
        });

        var round = new SwissPairingEngine().GenerateNextRound(tournament);

        Assert.DoesNotContain(round.Pairings, p => IsPair(p, players[0].Id, players[1].Id));
        Assert.DoesNotContain(round.Pairings, p => IsPair(p, players[2].Id, players[3].Id));
    }

    [Fact]
    public void GenerateNextRound_AvoidsThirdSameColorWhenAlternativeExists()
    {
        var players = CreatePlayers(4);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var round = new SwissPairingEngine().GenerateNextRound(tournament);
        var pairingWithPlayerOne = Assert.Single(round.Pairings, p => p.WhitePlayerId == players[0].Id || p.BlackPlayerId == players[0].Id);

        Assert.Equal(players[0].Id, pairingWithPlayerOne.BlackPlayerId);
        Assert.Contains(round.Audit.ColorNotes, note => note.Contains(players[0].Name, StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void GenerateNextRound_ProvidesScoreGroupAndFloaterAudit()
    {
        var players = CreatePlayers(6);
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[5].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[1].Id, players[4].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(3, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var round = new SwissPairingEngine().GenerateNextRound(tournament);

        Assert.Equal("Swiss-ScoreGroup-Greedy-V2", round.Audit.Algorithm);
        Assert.NotEmpty(round.Audit.ScoreGroups);
        Assert.NotEmpty(round.Audit.ColorNotes);
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Swiss Advanced",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers(int count)
    {
        return Enumerable.Range(1, count)
            .Select(i => new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Spieler {i}",
                StartingRank = i,
                Rating = new RatingProfile { ManualTwz = 2100 - i * 20 }
            })
            .ToList();
    }

    private static bool IsPair(Pairing pairing, Guid a, Guid b)
    {
        return (pairing.WhitePlayerId == a && pairing.BlackPlayerId == b) ||
               (pairing.WhitePlayerId == b && pairing.BlackPlayerId == a);
    }
}
