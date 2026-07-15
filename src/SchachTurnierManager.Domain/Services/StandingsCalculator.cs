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

        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(tournament, pairing, rows);
            }

            foreach (var row in rows.Values)
            {
                row.ProgressiveScore += row.Points;
            }
        }

        var opponentPoints = rows.ToDictionary(kv => kv.Key, kv => kv.Value.Points);
        foreach (var row in rows.Values)
        {
            var realOpponentScores = row.OpponentIds
                .Where(opponentPoints.ContainsKey)
                .Select(id => opponentPoints[id]);
            var opponentScores = UnplayedRoundTiebreak.BuildBuchholzScoreList(
                tournament.Settings.UnplayedRoundBuchholzMode,
                realOpponentScores,
                row.Points,
                row.UnplayedRoundCount);
            row.Buchholz = opponentScores.Sum();
            row.BuchholzCutOne = SumAfterDropping(opponentScores, lowest: 1, highest: 0);
            row.BuchholzCutTwo = SumAfterDropping(opponentScores, lowest: 2, highest: 0);
            row.MedianBuchholz = SumAfterDropping(opponentScores, lowest: 1, highest: 1);
            row.AverageOpponentRating = row.OpponentRatings.Count == 0 ? 0m : Math.Round(row.OpponentRatings.Average(), 2);
            row.TournamentPerformance = row.PerformanceGames == 0 || row.PerformanceOpponentRatings.Count == 0
                ? null
                : RatingCalculator.ApproximatePerformanceRating((int)Math.Round(row.PerformanceOpponentRatings.Average()), (double)(row.NormalizedPerformancePoints / row.PerformanceGames));
        }

        var koyaThreshold = KoyaThreshold(tournament);
        foreach (var row in rows.Values)
        {
            foreach (var contribution in row.SonnebornContributions)
            {
                if (opponentPoints.TryGetValue(contribution.OpponentId, out var points))
                {
                    row.SonnebornBerger += points * contribution.ScoreAgainstOpponent;
                }
            }

            row.KoyaScore = row.DirectResults
                .Where(result => opponentPoints.TryGetValue(result.OpponentId, out var points) && points >= koyaThreshold)
                .Sum(result => result.ScoreAgainstOpponent);
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
            .ThenBy(r => r, new TiebreakComparer(tournament.Settings.Tiebreaks))
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
            BlackWins = r.BlackWins,
            DirectEncounter = r.DirectEncounter,
            Buchholz = r.Buchholz,
            BuchholzCutOne = r.BuchholzCutOne,
            BuchholzCutTwo = r.BuchholzCutTwo,
            MedianBuchholz = r.MedianBuchholz,
            SonnebornBerger = r.SonnebornBerger,
            KoyaScore = r.KoyaScore,
            ProgressiveScore = r.ProgressiveScore,
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
            if (UnplayedRoundTiebreak.IsUnplayedRound(pairing.Result.Kind))
            {
                white.UnplayedRoundCount++;
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
        if (ScoringRules.IsWinFor(pairing.Result, isWhite: false))
        {
            black.Wins++;
            black.BlackWins++;
        }

        if (UnplayedRoundTiebreak.IsUnplayedRound(pairing.Result.Kind))
        {
            white.UnplayedRoundCount++;
            black.UnplayedRoundCount++;
        }

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

    private static decimal SumAfterDropping(IReadOnlyList<decimal> orderedScores, int lowest, int highest)
    {
        if (orderedScores.Count <= lowest + highest)
        {
            return orderedScores.Sum();
        }

        return orderedScores
            .Skip(lowest)
            .Take(orderedScores.Count - lowest - highest)
            .Sum();
    }

    private static decimal KoyaThreshold(TournamentState tournament)
    {
        if (tournament.Rounds.Count == 0)
        {
            return 0m;
        }

        var winScore = ScoringRules.ScoreFor(new GameResult(GameResultKind.WhiteWin), isWhite: true, tournament.Settings.ScoringSystem);
        return tournament.Rounds.Count * winScore / 2m;
    }

    private sealed class TiebreakComparer(IReadOnlyList<TiebreakType> configuredTiebreaks) : IComparer<MutableStanding>
    {
        private readonly IReadOnlyList<TiebreakType> _configuredTiebreaks = configuredTiebreaks.Count == 0
            ? new[] { TiebreakType.StartingRank }
            : configuredTiebreaks;

        public int Compare(MutableStanding? x, MutableStanding? y)
        {
            if (ReferenceEquals(x, y))
            {
                return 0;
            }

            if (x is null)
            {
                return 1;
            }

            if (y is null)
            {
                return -1;
            }

            foreach (var tiebreak in _configuredTiebreaks)
            {
                var comparison = CompareByTiebreak(x, y, tiebreak);
                if (comparison != 0)
                {
                    return comparison;
                }
            }

            return 0;
        }

        private static int CompareByTiebreak(MutableStanding x, MutableStanding y, TiebreakType tiebreak)
        {
            return tiebreak switch
            {
                TiebreakType.DirectEncounter => Desc(x.DirectEncounter, y.DirectEncounter),
                TiebreakType.NumberOfWins => Desc(x.Wins, y.Wins),
                TiebreakType.Buchholz => Desc(x.Buchholz, y.Buchholz),
                TiebreakType.BuchholzCutOne => Desc(x.BuchholzCutOne, y.BuchholzCutOne),
                TiebreakType.BuchholzCutTwo => Desc(x.BuchholzCutTwo, y.BuchholzCutTwo),
                TiebreakType.MedianBuchholz => Desc(x.MedianBuchholz, y.MedianBuchholz),
                TiebreakType.SonnebornBerger => Desc(x.SonnebornBerger, y.SonnebornBerger),
                TiebreakType.KoyaScore => Desc(x.KoyaScore, y.KoyaScore),
                TiebreakType.ProgressiveScore => Desc(x.ProgressiveScore, y.ProgressiveScore),
                TiebreakType.NumberOfBlackWins => Desc(x.BlackWins, y.BlackWins),
                TiebreakType.AverageOpponentRating => Desc(x.AverageOpponentRating, y.AverageOpponentRating),
                TiebreakType.TournamentPerformance => Desc(x.TournamentPerformance ?? int.MinValue, y.TournamentPerformance ?? int.MinValue),
                TiebreakType.StartingRank => Asc(StartingRankOrMax(x), StartingRankOrMax(y)),
                _ => 0
            };
        }

        private static int Desc<T>(T x, T y) where T : IComparable<T> => y.CompareTo(x);

        private static int Asc<T>(T x, T y) where T : IComparable<T> => x.CompareTo(y);

        private static int StartingRankOrMax(MutableStanding row) => row.Player.StartingRank <= 0 ? int.MaxValue : row.Player.StartingRank;
    }

    private sealed class MutableStanding(Player player, int twz)
    {
        public Player Player { get; } = player;
        public int Twz { get; } = twz;
        public decimal Points { get; set; }
        public int Wins { get; set; }
        public int BlackWins { get; set; }
        public decimal DirectEncounter { get; set; }
        public decimal Buchholz { get; set; }
        public decimal BuchholzCutOne { get; set; }
        public decimal BuchholzCutTwo { get; set; }
        public decimal MedianBuchholz { get; set; }
        public decimal SonnebornBerger { get; set; }
        public decimal KoyaScore { get; set; }
        public decimal ProgressiveScore { get; set; }
        public decimal AverageOpponentRating { get; set; }
        public int? TournamentPerformance { get; set; }
        public decimal HeroScore { get; set; }
        public int UnplayedRoundCount { get; set; }
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
