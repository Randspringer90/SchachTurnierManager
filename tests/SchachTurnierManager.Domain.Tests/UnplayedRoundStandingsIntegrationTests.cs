using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-FACH-001: End-to-End-Nachweis, dass <see cref="TournamentSettings.UnplayedRoundBuchholzMode"/>
/// tatsaechlich in <see cref="StandingsCalculator"/> greift. Default (IgnoreUnplayedRounds) bleibt
/// exakt das bisherige Verhalten (Regressionsschutz); FideVirtualOpponent ist rein additiv/opt-in.
/// Beide Tests nutzen dasselbe 5-Spieler-Schweizer-System mit drei Freilosen, damit der Unterschied
/// direkt sichtbar wird.
/// </summary>
public sealed class UnplayedRoundStandingsIntegrationTests
{
    [Fact]
    public void Calculate_DefaultMode_IgnoresOwnByesInBuchholz()
    {
        var standings = CalculateFivePlayerByeScenario(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds);

        // Unveraendertes bisheriges Verhalten: Freilose tragen nichts zum eigenen Buchholz bei.
        AssertBuchholz(standings, "G", points: 2.0m, buchholz: 4.5m, buchholzCutOne: 2.5m);
        AssertBuchholz(standings, "H", points: 2.0m, buchholz: 3.5m, buchholzCutOne: 2.0m);
        AssertBuchholz(standings, "I", points: 1.0m, buchholz: 4.0m, buchholzCutOne: 2.5m);
    }

    [Fact]
    public void Calculate_FideVirtualOpponentMode_AddsOwnByeAsVirtualOpponent()
    {
        var standings = CalculateFivePlayerByeScenario(UnplayedRoundBuchholzMode.FideVirtualOpponent);

        // FIDE Art. 16.4: die eigene Freilos-Runde zaehlt wie eine Partie gegen einen virtuellen
        // Gegner mit der eigenen Endpunktzahl -> Buchholz steigt um genau diesen Wert.
        AssertBuchholz(standings, "G", points: 2.0m, buchholz: 6.5m, buchholzCutOne: 4.5m);
        AssertBuchholz(standings, "H", points: 2.0m, buchholz: 5.5m, buchholzCutOne: 4.0m);
        AssertBuchholz(standings, "I", points: 1.0m, buchholz: 5.0m, buchholzCutOne: 4.0m);

        // Spieler ohne eigenes Freilos sind vom Moduswechsel unberuehrt.
        AssertBuchholz(standings, "E", points: 2.5m, buchholz: 4.5m, buchholzCutOne: 3.5m);
        AssertBuchholz(standings, "F", points: 1.5m, buchholz: 5.5m, buchholzCutOne: 4.5m);
    }

    private static IReadOnlyList<StandingRow> CalculateFivePlayerByeScenario(UnplayedRoundBuchholzMode mode)
    {
        var players = FivePlayers();
        var tournament = new TournamentState
        {
            Name = "Freilos-Wertung 5-Spieler Schweizer System",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss, UnplayedRoundBuchholzMode = mode }
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

        return new StandingsCalculator().Calculate(tournament);
    }

    private static void AssertBuchholz(IReadOnlyList<StandingRow> standings, string name, decimal points, decimal buchholz, decimal buchholzCutOne)
    {
        var row = Assert.Single(standings, r => r.Name == name);
        Assert.Equal(points, row.Points);
        Assert.Equal(buchholz, row.Buchholz);
        Assert.Equal(buchholzCutOne, row.BuchholzCutOne);
    }

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
