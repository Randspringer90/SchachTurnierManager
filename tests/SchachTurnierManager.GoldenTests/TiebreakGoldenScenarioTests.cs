using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.GoldenTests;

/// <summary>
/// STM-TB-001: Handgerechnete, synthetische Golden-Szenarien fuer die kanonische
/// Standings-Berechnung. Die Tests sind rein additiv und verwenden weder Tagesdatum
/// noch Zufallswerte oder zwischen Tests geteilten Zustand.
/// </summary>
public sealed class TiebreakGoldenScenarioTests
{
    private static readonly IReadOnlyList<TiebreakType> GoldenTiebreakOrder =
    [
        TiebreakType.Buchholz,
        TiebreakType.BuchholzCutOne,
        TiebreakType.BuchholzCutTwo,
        TiebreakType.MedianBuchholz,
        TiebreakType.SonnebornBerger,
        TiebreakType.StartingRank
    ];

    [Fact]
    public void Calculate_FourPlayerRoundRobin_MatchesHandComputedTableAndRanks()
    {
        var players = CreatePlayers(("A", 1, 2000), ("B", 2, 1900), ("C", 3, 1800), ("D", 4, 1700));
        var tournament = CreateTournament("Golden Round Robin", TournamentFormat.RoundRobin, players);

        tournament.Rounds.Add(Round(1,
            Game(1, players[0], players[1], GameResultKind.WhiteWin),
            Game(2, players[2], players[3], GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(2,
            Game(1, players[0], players[2], GameResultKind.Draw),
            Game(2, players[1], players[3], GameResultKind.WhiteWin)));
        tournament.Rounds.Add(Round(3,
            Game(1, players[0], players[3], GameResultKind.WhiteWin),
            Game(2, players[1], players[2], GameResultKind.Draw)));

        // Endpunkte A/B/C/D = 2.5/1.5/2.0/0.0. Beispiel A:
        // Gegnerwerte [0.0, 1.5, 2.0] => BH 3.5, Cut-1 3.5,
        // Cut-2 2.0, Median 1.5; SB = 1*1.5 + 0.5*2.0 + 1*0.0 = 2.5.
        AssertStandings(new StandingsCalculator().Calculate(tournament),
            Expected(1, "A", 2.5m, 3.5m, 3.5m, 2.0m, 1.5m, 2.5m),
            Expected(2, "C", 2.0m, 4.0m, 4.0m, 2.5m, 1.5m, 2.0m),
            Expected(3, "B", 1.5m, 4.5m, 4.5m, 2.5m, 2.0m, 1.0m),
            Expected(4, "D", 0.0m, 6.0m, 4.5m, 2.5m, 2.0m, 0.0m));
    }

    [Fact]
    public void Calculate_FivePlayerSwissWithByes_MatchesHandComputedTableAndRanks()
    {
        var players = CreatePlayers(("E", 1, 2100), ("F", 2, 2000), ("G", 3, 1900), ("H", 4, 1800), ("I", 5, 1700));
        var tournament = CreateTournament("Golden Swiss", TournamentFormat.Swiss, players);
        var (e, f, g, h, i) = (players[0], players[1], players[2], players[3], players[4]);

        tournament.Rounds.Add(Round(1,
            Game(1, e, f, GameResultKind.WhiteWin),
            Game(2, g, h, GameResultKind.Draw),
            Pairing.Bye(3, i.Id)));
        tournament.Rounds.Add(Round(2,
            Game(1, e, g, GameResultKind.Draw),
            Game(2, f, i, GameResultKind.WhiteWin),
            Pairing.Bye(3, h.Id)));
        tournament.Rounds.Add(Round(3,
            Game(1, e, i, GameResultKind.WhiteWin),
            Game(2, f, h, GameResultKind.Draw),
            Pairing.Bye(3, g.Id)));

        // Defaultmodus: ein Freilos gibt einen Punkt, erzeugt aber keinen realen
        // Gegnerwert. G hat deshalb nur [2.0, 2.5]: BH 4.5, Cut-1 2.5.
        // Fuer Cut-2/Median behaelt die kanonische Berechnung bei nur zwei Werten
        // die vollstaendige Liste, statt eine leere Summe zu erzeugen.
        AssertStandings(new StandingsCalculator().Calculate(tournament),
            Expected(1, "E", 2.5m, 4.5m, 3.5m, 2.0m, 1.5m, 3.5m),
            Expected(2, "G", 2.0m, 4.5m, 2.5m, 4.5m, 4.5m, 2.25m),
            Expected(3, "H", 2.0m, 3.5m, 2.0m, 3.5m, 3.5m, 1.75m),
            Expected(4, "F", 1.5m, 5.5m, 4.5m, 2.5m, 2.0m, 2.0m),
            Expected(5, "I", 1.0m, 4.0m, 2.5m, 4.0m, 4.0m, 0.0m));
    }

    private static TournamentState CreateTournament(string name, TournamentFormat format, IEnumerable<Player> players)
    {
        var tournament = new TournamentState
        {
            Name = name,
            Settings = new TournamentSettings
            {
                Format = format,
                Tiebreaks = GoldenTiebreakOrder
            }
        };
        tournament.Players.AddRange(players);
        return tournament;
    }

    private static TournamentRound Round(int number, params Pairing[] pairings) => new()
    {
        RoundNumber = number,
        Pairings = pairings
    };

    private static Pairing Game(int board, Player white, Player black, GameResultKind result) =>
        Pairing.Game(board, white.Id, black.Id) with { Result = new GameResult(result) };

    private static List<Player> CreatePlayers(params (string Name, int StartingRank, int Twz)[] definitions) =>
        definitions.Select(definition => new Player
        {
            Id = Guid.Parse($"00000000-0000-0000-0000-{definition.StartingRank:000000000000}"),
            Name = definition.Name,
            StartingRank = definition.StartingRank,
            Rating = new RatingProfile { ManualTwz = definition.Twz }
        }).ToList();

    private static ExpectedStanding Expected(
        int rank,
        string name,
        decimal points,
        decimal buchholz,
        decimal buchholzCutOne,
        decimal buchholzCutTwo,
        decimal medianBuchholz,
        decimal sonnebornBerger) =>
        new(rank, name, points, buchholz, buchholzCutOne, buchholzCutTwo, medianBuchholz, sonnebornBerger);

    private static void AssertStandings(IReadOnlyList<StandingRow> actual, params ExpectedStanding[] expected)
    {
        Assert.Equal(expected.Length, actual.Count);
        for (var index = 0; index < expected.Length; index++)
        {
            var row = actual[index];
            var golden = expected[index];
            Assert.Equal(golden.Rank, row.Rank);
            Assert.Equal(golden.Name, row.Name);
            Assert.Equal(golden.Points, row.Points);
            Assert.Equal(golden.Buchholz, row.Buchholz);
            Assert.Equal(golden.BuchholzCutOne, row.BuchholzCutOne);
            Assert.Equal(golden.BuchholzCutTwo, row.BuchholzCutTwo);
            Assert.Equal(golden.MedianBuchholz, row.MedianBuchholz);
            Assert.Equal(golden.SonnebornBerger, row.SonnebornBerger);
        }
    }

    private sealed record ExpectedStanding(
        int Rank,
        string Name,
        decimal Points,
        decimal Buchholz,
        decimal BuchholzCutOne,
        decimal BuchholzCutTwo,
        decimal MedianBuchholz,
        decimal SonnebornBerger);
}
