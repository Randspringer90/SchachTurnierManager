using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class HeroCupCalculator
{
    private readonly StandingsCalculator _standings = new();

    public IReadOnlyList<HeroCupRow> Calculate(TournamentState tournament)
    {
        var players = tournament.Players.Where(p => p.IsActive).ToDictionary(p => p.Id);
        var mutable = players.Values.ToDictionary(player => player.Id, player => new MutableHero(player, player.Twz(tournament.Settings.TwzSource)));

        foreach (var round in tournament.Rounds)
        {
            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(tournament, pairing, players, mutable);
            }
        }

        var performanceByPlayer = _standings.Calculate(tournament).ToDictionary(row => row.PlayerId, row => row.TournamentPerformance);
        var minGames = Math.Max(1, tournament.Settings.HeroCupMinimumRatedGames);

        return mutable.Values
            .Where(row => row.RatedGames >= minGames)
            .OrderByDescending(row => row.ActualScore - row.ExpectedScore)
            .ThenByDescending(row => row.AverageOpponentRating)
            .ThenBy(row => row.Player.StartingRank == 0 ? int.MaxValue : row.Player.StartingRank)
            .Select((row, index) => new HeroCupRow
            {
                Rank = index + 1,
                PlayerId = row.Player.Id,
                Name = row.Player.Name,
                Twz = row.Twz,
                RatedGames = row.RatedGames,
                ActualScore = Math.Round(row.ActualScore, 2),
                ExpectedScore = Math.Round(row.ExpectedScore, 2),
                OverPerformance = Math.Round(row.ActualScore - row.ExpectedScore, 2),
                AverageOpponentRating = Math.Round(row.AverageOpponentRating, 2),
                TournamentPerformance = performanceByPlayer.TryGetValue(row.Player.Id, out var performance) ? performance : null,
                Reason = $"{row.ActualScore:0.##}/{row.RatedGames} statt erwartet {row.ExpectedScore:0.##} gegen Ø {row.AverageOpponentRating:0}"
            })
            .ToList();
    }

    private static void ApplyPairing(
        TournamentState tournament,
        Pairing pairing,
        IReadOnlyDictionary<Guid, Player> players,
        IReadOnlyDictionary<Guid, MutableHero> rows)
    {
        if (pairing.WhitePlayerId is null || pairing.BlackPlayerId is null || pairing.Result.Kind == GameResultKind.NotPlayed || !pairing.Result.CountsForPerformance)
        {
            return;
        }

        if (!players.TryGetValue(pairing.WhitePlayerId.Value, out var white) || !players.TryGetValue(pairing.BlackPlayerId.Value, out var black))
        {
            return;
        }

        if (!rows.TryGetValue(white.Id, out var whiteRow) || !rows.TryGetValue(black.Id, out var blackRow))
        {
            return;
        }

        var whiteTwz = white.Twz(tournament.Settings.TwzSource);
        var blackTwz = black.Twz(tournament.Settings.TwzSource);
        if (whiteTwz <= 0 || blackTwz <= 0)
        {
            return;
        }

        var whiteActual = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: true);
        var blackActual = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: false);
        var whiteExpected = ExpectedScore(whiteTwz, blackTwz);
        var blackExpected = ExpectedScore(blackTwz, whiteTwz);

        whiteRow.AddGame(blackTwz, whiteActual, whiteExpected);
        blackRow.AddGame(whiteTwz, blackActual, blackExpected);
    }

    private static decimal ExpectedScore(int ownRating, int opponentRating)
    {
        var expected = 1d / (1d + Math.Pow(10d, (opponentRating - ownRating) / 400d));
        return (decimal)expected;
    }

    private sealed class MutableHero(Player player, int twz)
    {
        private readonly List<int> _opponentRatings = new();

        public Player Player { get; } = player;
        public int Twz { get; } = twz;
        public int RatedGames { get; private set; }
        public decimal ActualScore { get; private set; }
        public decimal ExpectedScore { get; private set; }
        public decimal AverageOpponentRating => _opponentRatings.Count == 0 ? 0m : (decimal)_opponentRatings.Average();

        public void AddGame(int opponentRating, decimal actualScore, decimal expectedScore)
        {
            RatedGames++;
            ActualScore += actualScore;
            ExpectedScore += expectedScore;
            _opponentRatings.Add(opponentRating);
        }
    }
}
