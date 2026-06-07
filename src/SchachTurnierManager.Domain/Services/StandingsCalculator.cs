using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class StandingsCalculator
{
    public IReadOnlyList<StandingRow> Calculate(TournamentState tournament)
    {
        var referenceYear = DateTime.Today.Year;
        var rows = tournament.Players
            .Where(p => p.IsActive)
            .ToDictionary(p => p.Id, p => new MutableStanding(p, p.Twz(tournament.Settings.TwzSource)));

        foreach (var round in tournament.Rounds)
        {
            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(tournament, pairing, rows);
            }
        }

        var opponentPoints = rows.ToDictionary(kv => kv.Key, kv => kv.Value.Points);
        foreach (var row in rows.Values)
        {
            var opponentScores = row.OpponentIds.Where(opponentPoints.ContainsKey).Select(id => opponentPoints[id]).OrderBy(x => x).ToList();
            row.Buchholz = opponentScores.Sum();
            row.BuchholzCutOne = opponentScores.Count > 1 ? opponentScores.Skip(1).Sum() : row.Buchholz;
            row.AverageOpponentRating = row.OpponentRatings.Count == 0 ? 0m : Math.Round(row.OpponentRatings.Average(), 2);
            row.TournamentPerformance = row.PerformanceGames == 0 || row.PerformanceOpponentRatings.Count == 0
                ? null
                : RatingCalculator.ApproximatePerformanceRating((int)Math.Round(row.PerformanceOpponentRatings.Average()), (double)(row.NormalizedPerformancePoints / row.PerformanceGames));
        }

        foreach (var row in rows.Values)
        {
            foreach (var contribution in row.SonnebornContributions)
            {
                if (opponentPoints.TryGetValue(contribution.OpponentId, out var points))
                {
                    row.SonnebornBerger += points * contribution.ScoreAgainstOpponent;
                }
            }

            row.HeroScore = row.TournamentPerformance is null ? 0m : row.TournamentPerformance.Value - row.Twz;
        }

        foreach (var group in rows.Values.GroupBy(r => r.Points))
        {
            var playerIds = group.Select(g => g.Player.Id).ToHashSet();
            foreach (var row in group)
            {
                row.DirectEncounter = row.DirectResults.Where(r => playerIds.Contains(r.OpponentId)).Sum(r => r.ScoreAgainstOpponent);
            }
        }

        var ordered = rows.Values
            .OrderByDescending(r => r.Points)
            .ThenByDescending(r => r.DirectEncounter)
            .ThenByDescending(r => r.Wins)
            .ThenByDescending(r => r.Buchholz)
            .ThenByDescending(r => r.SonnebornBerger)
            .ThenByDescending(r => r.TournamentPerformance ?? int.MinValue)
            .ThenBy(r => r.Player.StartingRank == 0 ? int.MaxValue : r.Player.StartingRank)
            .ThenBy(r => r.Player.Name, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return ordered.Select((r, index) => new StandingRow
        {
            Rank = index + 1,
            PlayerId = r.Player.Id,
            Name = r.Player.Name,
            StartingRank = r.Player.StartingRank,
            Twz = r.Twz,
            Points = r.Points,
            Wins = r.Wins,
            DirectEncounter = r.DirectEncounter,
            Buchholz = r.Buchholz,
            BuchholzCutOne = r.BuchholzCutOne,
            SonnebornBerger = r.SonnebornBerger,
            AverageOpponentRating = r.AverageOpponentRating,
            TournamentPerformance = r.TournamentPerformance,
            HeroScore = r.HeroScore,
            Categories = CategoryClassifier.Classify(r.Player, tournament.Settings, referenceYear)
        }).ToList();
    }

    private static void ApplyPairing(TournamentState tournament, Pairing pairing, Dictionary<Guid, MutableStanding> rows)
    {
        if (pairing.WhitePlayerId is null)
        {
            return;
        }

        if (!rows.TryGetValue(pairing.WhitePlayerId.Value, out var white))
        {
            return;
        }

        if (pairing.IsBye || pairing.BlackPlayerId is null)
        {
            white.Points += ScoringRules.ScoreFor(pairing.Result, isWhite: true, tournament.Settings.ScoringSystem);
            if (ScoringRules.IsWinFor(pairing.Result, isWhite: true, countForfeitWins: true, countByeAsWin: tournament.Settings.CountByeAsWin))
            {
                white.Wins++;
            }
            return;
        }

        if (!rows.TryGetValue(pairing.BlackPlayerId.Value, out var black))
        {
            return;
        }

        var whiteScore = ScoringRules.ScoreFor(pairing.Result, isWhite: true, tournament.Settings.ScoringSystem);
        var blackScore = ScoringRules.ScoreFor(pairing.Result, isWhite: false, tournament.Settings.ScoringSystem);
        white.Points += whiteScore;
        black.Points += blackScore;

        if (ScoringRules.IsWinFor(pairing.Result, isWhite: true)) white.Wins++;
        if (ScoringRules.IsWinFor(pairing.Result, isWhite: false)) black.Wins++;

        var whiteNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: true);
        var blackNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: false);

        if (ResultPolicy.CountsAsOpponentForBuchholz(pairing.Result.Kind, tournament.Settings))
        {
            white.OpponentIds.Add(black.Player.Id);
            black.OpponentIds.Add(white.Player.Id);
            if (black.Twz > 0) white.OpponentRatings.Add(black.Twz);
            if (white.Twz > 0) black.OpponentRatings.Add(white.Twz);
        }

        if (ResultPolicy.CountsAsGameForDirectAndSonneborn(pairing.Result.Kind, tournament.Settings))
        {
            white.DirectResults.Add(new DirectResult(black.Player.Id, whiteNormalized));
            black.DirectResults.Add(new DirectResult(white.Player.Id, blackNormalized));
            white.SonnebornContributions.Add(new DirectResult(black.Player.Id, whiteNormalized));
            black.SonnebornContributions.Add(new DirectResult(white.Player.Id, blackNormalized));
        }

        if (ResultPolicy.CountsForPerformance(pairing.Result.Kind))
        {
            white.NormalizedPerformancePoints += whiteNormalized;
            black.NormalizedPerformancePoints += blackNormalized;
            white.PerformanceGames++;
            black.PerformanceGames++;
            if (black.Twz > 0) white.PerformanceOpponentRatings.Add(black.Twz);
            if (white.Twz > 0) black.PerformanceOpponentRatings.Add(white.Twz);
        }
    }

    private sealed class MutableStanding(Player player, int twz)
    {
        public Player Player { get; } = player;
        public int Twz { get; } = twz;
        public decimal Points { get; set; }
        public int Wins { get; set; }
        public decimal DirectEncounter { get; set; }
        public decimal Buchholz { get; set; }
        public decimal BuchholzCutOne { get; set; }
        public decimal SonnebornBerger { get; set; }
        public decimal AverageOpponentRating { get; set; }
        public int? TournamentPerformance { get; set; }
        public decimal HeroScore { get; set; }
        public List<Guid> OpponentIds { get; } = new();
        public List<decimal> OpponentRatings { get; } = new();
        public List<decimal> PerformanceOpponentRatings { get; } = new();
        public List<DirectResult> DirectResults { get; } = new();
        public List<DirectResult> SonnebornContributions { get; } = new();
        public decimal NormalizedPerformancePoints { get; set; }
        public int PerformanceGames { get; set; }
    }

    private sealed record DirectResult(Guid OpponentId, decimal ScoreAgainstOpponent);
}
