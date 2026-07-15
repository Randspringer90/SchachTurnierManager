using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-TB-001: Deterministische Golden-Tests fuer Buchholz, Buchholz-Cut-1 und
/// Sonneborn-Berger an vollstaendig durchgerechneten Beispielturnieren. Rein additiv,
/// keine Verhaltensaenderung an StandingsCalculator. Erwartete Werte sind von Hand
/// nachgerechnet (siehe CHANGELOG.md-Notiz zu diesem Lauf).
/// </summary>
public sealed class TiebreakGoldenScenarioTests
{
    [Fact]
    public void Calculate_FourPlayerRoundRobin_MatchesHandComputedTiebreaks()
    {
        var players = FourPlayers();
        var tournament = new TournamentState
        {
            Name = "Golden 4-Spieler Rundenturnier",
            Settings = new TournamentSettings { Format = TournamentFormat.RoundRobin }
        };
        tournament.Players.AddRange(players);

        // Runde 1: A schlaegt B, C schlaegt D.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[1].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[2].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        // Runde 2: A - C Remis, B schlaegt D.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, players[1].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) }
            }
        });

        // Runde 3: A schlaegt D, B - C Remis.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 3,
            Pairings = new[]
            {
                Pairing.Game(1, players[0].Id, players[3].Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, players[1].Id, players[2].Id) with { Result = new GameResult(GameResultKind.Draw) }
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);

        // Endstand: A 2.5 / C 2.0 / B 1.5 / D 0.0.
        AssertRow(standings, "A", points: 2.5m, buchholz: 3.5m, buchholzCutOne: 3.5m, buchholzCutTwo: 2.0m, medianBuchholz: 1.5m, sonnebornBerger: 2.5m);
        AssertRow(standings, "B", points: 1.5m, buchholz: 4.5m, buchholzCutOne: 4.5m, buchholzCutTwo: 2.5m, medianBuchholz: 2.0m, sonnebornBerger: 1.0m);
        AssertRow(standings, "C", points: 2.0m, buchholz: 4.0m, buchholzCutOne: 4.0m, buchholzCutTwo: 2.5m, medianBuchholz: 1.5m, sonnebornBerger: 2.0m);
        AssertRow(standings, "D", points: 0.0m, buchholz: 6.0m, buchholzCutOne: 4.5m, buchholzCutTwo: 2.5m, medianBuchholz: 2.0m, sonnebornBerger: 0.0m);
    }

    [Fact]
    public void Calculate_FivePlayerSwissWithByes_MatchesHandComputedTiebreaks()
    {
        var players = FivePlayers();
        var tournament = new TournamentState
        {
            Name = "Golden 5-Spieler Schweizer System mit Freilosen",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);
        var (e, f, g, h, i) = (players[0], players[1], players[2], players[3], players[4]);

        // Runde 1: E schlaegt F, G - H Remis, I spielfrei.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, e.Id, f.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, g.Id, h.Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Bye(3, i.Id)
            }
        });

        // Runde 2: E - G Remis, F schlaegt I, H spielfrei.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 2,
            Pairings = new[]
            {
                Pairing.Game(1, e.Id, g.Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Game(2, f.Id, i.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Bye(3, h.Id)
            }
        });

        // Runde 3: E schlaegt I, F - H Remis, G spielfrei.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 3,
            Pairings = new[]
            {
                Pairing.Game(1, e.Id, i.Id) with { Result = new GameResult(GameResultKind.WhiteWin) },
                Pairing.Game(2, f.Id, h.Id) with { Result = new GameResult(GameResultKind.Draw) },
                Pairing.Bye(3, g.Id)
            }
        });

        var standings = new StandingsCalculator().Calculate(tournament);

        // Endstand: E 2.5 / G 2.0 / H 2.0 / F 1.5 / I 1.0.
        // Freilose zaehlen im Default-Modus (IgnoreUnplayedRounds) nicht als Buchholz-Gegner.
        AssertRow(standings, "E", points: 2.5m, buchholz: 4.5m, buchholzCutOne: 3.5m, buchholzCutTwo: 2.0m, medianBuchholz: 1.5m, sonnebornBerger: 3.5m);
        AssertRow(standings, "F", points: 1.5m, buchholz: 5.5m, buchholzCutOne: 4.5m, buchholzCutTwo: 2.5m, medianBuchholz: 2.0m, sonnebornBerger: 2.0m);
        AssertRow(standings, "G", points: 2.0m, buchholz: 4.5m, buchholzCutOne: 2.5m, buchholzCutTwo: 4.5m, medianBuchholz: 4.5m, sonnebornBerger: 2.25m);
        AssertRow(standings, "H", points: 2.0m, buchholz: 3.5m, buchholzCutOne: 2.0m, buchholzCutTwo: 3.5m, medianBuchholz: 3.5m, sonnebornBerger: 1.75m);
        AssertRow(standings, "I", points: 1.0m, buchholz: 4.0m, buchholzCutOne: 2.5m, buchholzCutTwo: 4.0m, medianBuchholz: 4.0m, sonnebornBerger: 0.0m);
    }

    private static void AssertRow(
        IReadOnlyList<StandingRow> standings,
        string name,
        decimal points,
        decimal buchholz,
        decimal buchholzCutOne,
        decimal buchholzCutTwo,
        decimal medianBuchholz,
        decimal sonnebornBerger)
    {
        var row = Assert.Single(standings, r => r.Name == name);
        Assert.Equal(points, row.Points);
        Assert.Equal(buchholz, row.Buchholz);
        Assert.Equal(buchholzCutOne, row.BuchholzCutOne);
        Assert.Equal(buchholzCutTwo, row.BuchholzCutTwo);
        Assert.Equal(medianBuchholz, row.MedianBuchholz);
        Assert.Equal(sonnebornBerger, row.SonnebornBerger);
    }

    private static List<Player> FourPlayers() => new()
    {
        Player("A", 1, 2000),
        Player("B", 2, 1900),
        Player("C", 3, 1800),
        Player("D", 4, 1700)
    };

    private static List<Player> FivePlayers() => new()
    {
        Player("E", 1, 2100),
        Player("F", 2, 2000),
        Player("G", 3, 1900),
        Player("H", 4, 1800),
        Player("I", 5, 1700)
    };

    private static Player Player(string name, int startingRank, int twz) => new()
    {
        Id = Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}"),
        Name = name,
        StartingRank = startingRank,
        Rating = new RatingProfile { ManualTwz = twz }
    };
}
