using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ExtendedTiebreakTests
{
    [Fact]
    public void Calculate_ExposesExtendedTiebreakValues()
    {
        var players = CreatePlayers();
        var tournament = CreateTournament(players);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[1].Id, players[0].Id) with { Result = new GameResult(GameResultKind.BlackWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);
        var playerA = Assert.Single(standings, row => row.Name == "A");

        Assert.Equal(1.5m, playerA.Points);
        Assert.Equal(1, playerA.BlackWins);
        Assert.Equal(2.5m, playerA.Buchholz);
        Assert.Equal(1.5m, playerA.BuchholzCutOne);
        Assert.Equal(2.5m, playerA.BuchholzCutTwo);
        Assert.Equal(2.5m, playerA.MedianBuchholz);
        Assert.Equal(1.5m, playerA.KoyaScore);
        Assert.Equal(2.5m, playerA.ProgressiveScore);
    }

    [Fact]
    public void Calculate_UsesBlackWinsAsConfiguredTiebreak()
    {
        var players = CreatePlayers();
        var tournament = CreateTournament(players);
        tournament.Settings = new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            Tiebreaks = new[] { TiebreakType.NumberOfBlackWins, TiebreakType.StartingRank }
        };
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[1].Id, players[0].Id) with { Result = new GameResult(GameResultKind.BlackWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        var onePointGroup = new StandingsCalculator()
            .Calculate(tournament)
            .Where(row => row.Points == 1m)
            .Take(2)
            .ToList();

        Assert.Equal("A", onePointGroup[0].Name);
        Assert.Equal(1, onePointGroup[0].BlackWins);
        Assert.Equal("C", onePointGroup[1].Name);
        Assert.Equal(0, onePointGroup[1].BlackWins);
    }

    private static TournamentState CreateTournament(IReadOnlyList<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = "Extended Tiebreaks",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static List<Player> CreatePlayers()
    {
        return new()
        {
            Player("A", 4, 2000),
            Player("B", 2, 1900),
            Player("C", 1, 1800),
            Player("D", 3, 1700)
        };
    }

    private static Player Player(string name, int startingRank, int twz) => new()
    {
        Id = Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}"),
        Name = name,
        StartingRank = startingRank,
        Rating = new RatingProfile { ManualTwz = twz }
    };
}
