using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class StandingsCalculator
{
    public IReadOnlyList<StandingRow> Calculate(TournamentState tournament)
    {
        var referenceYear = DateTime.Today.Year;
        // Historische Resultate werden fuer ALLE Turnierteilnehmer berechnet (auch
        // pausierte/zurueckgezogene): bereits gespielte Partien bleiben vollstaendig
        // erhalten, die sichtbare Rangliste wird erst am Ende nach Status gefiltert.
        var rows = tournament.Players
            .ToDictionary(p => p.Id, p => new MutableStanding(p, p.Twz(tournament.Settings.TwzSource)));

        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            // Offene Runden duerfen ungespielte Partien nicht vorzeitig als
            // ungespielte Runden (virtuelle Gegner) werten.
            var roundFinalized = round.ResultStatus != RoundResultStatus.Open;

            foreach (var pairing in round.Pairings)
            {
                ApplyPairing(tournament, round.RoundNumber, pairing, rows, roundFinalized);
            }

            if (roundFinalized)
            {
                var pairedPlayerIds = round.Pairings
                    .SelectMany(p => new[] { p.WhitePlayerId, p.BlackPlayerId })
                    .Where(id => id.HasValue)
                    .Select(id => id!.Value)
                    .ToHashSet();

                foreach (var row in rows.Values)
                {
                    if (!pairedPlayerIds.Contains(row.Player.Id))
                    {
                        // Ohne Pairing in einer abgeschlossenen Runde ist im heutigen
                        // Modell nur eine angeforderte/sonstige ungespielte Runde sicher
                        // ableitbar. Ob sie nach Art. 16.2.3 oder 16.2.5 behandelt wird,
                        // entscheidet sich anhand einer späteren Nicht-VUR-Runde.
                        row.UnplayedRounds.Add(new UnplayedRoundEntry(
                            round.RoundNumber,
                            OpponentId: null,
                            AwardedScore: 0m,
                            UsesScheduledOpponentCap: false,
                            IsVoluntaryUnplayedRound: true,
                            AdjustAsDrawWithoutLaterNonVur: true,
                            IncludeVirtualBuchholz: true));
                    }
                }
            }

            foreach (var row in rows.Values)
            {
                row.ProgressiveScore += row.Points;
            }
        }

        var opponentPoints = rows.ToDictionary(kv => kv.Key, kv => kv.Value.Points);
        var buchholzMode = tournament.Settings.Format == TournamentFormat.Swiss
            ? tournament.Settings.UnplayedRoundBuchholzMode
            : UnplayedRoundBuchholzMode.IgnoreUnplayedRounds;
        // FIDE C.07 (03/2026) Art. 16.4.2: Obergrenze fuer Bye-artige ungespielte
        // Runden = Remispunkte × Rundenzahl des Turniers.
        var drawScore = ScoringRules.ScoreFor(GameResult.Draw, isWhite: true, tournament.Settings.ScoringSystem);
        var totalRounds = Math.Max(tournament.Rounds.Count, tournament.Settings.PlannedRounds);
        var byeDummyCap = drawScore * totalRounds;
        var adjustedOpponentPoints = buchholzMode == UnplayedRoundBuchholzMode.FideVirtualOpponent
            ? rows.ToDictionary(kv => kv.Key, kv => AdjustedScoreForOpponents(kv.Value, drawScore))
            : opponentPoints;

        foreach (var row in rows.Values)
        {
            var realOpponentScores = row.BuchholzOpponents
                .Where(entry => adjustedOpponentPoints.ContainsKey(entry.OpponentId))
                .Select(entry => new BuchholzScoreEntry(
                    adjustedOpponentPoints[entry.OpponentId],
                    entry.IsVoluntaryUnplayedRound));
            var virtualOpponentScores = buchholzMode == UnplayedRoundBuchholzMode.FideVirtualOpponent
                ? row.UnplayedRounds.Where(entry => entry.IncludeVirtualBuchholz).Select(entry =>
                {
                    // Art. 16.4.1: bei kampflosen Ergebnissen deckelt die Punktzahl
                    // der nach Art. 16.3 angepasste Stand des vorgesehenen Gegners;
                    // sonst gilt die Remispunkte-mal-Rundenzahl-Grenze (16.4.2).
                    var cap = entry.UsesScheduledOpponentCap
                        && entry.OpponentId is { } opponentId
                        && adjustedOpponentPoints.TryGetValue(opponentId, out var opponentScore)
                        ? opponentScore
                        : byeDummyCap;
                    return new BuchholzScoreEntry(
                        UnplayedRoundTiebreak.DummyOpponentScore(row.Points, cap),
                        entry.IsVoluntaryUnplayedRound);
                })
                : Enumerable.Empty<BuchholzScoreEntry>();
            var opponentScores = UnplayedRoundTiebreak.BuildCanonicalScoreList(
                buchholzMode,
                realOpponentScores,
                virtualOpponentScores);
            row.Buchholz = opponentScores.Sum(entry => entry.Score);
            row.BuchholzCutOne = UnplayedRoundTiebreak.SumAfterDropping(buchholzMode, opponentScores, lowest: 1, highest: 0);
            row.BuchholzCutTwo = UnplayedRoundTiebreak.SumAfterDropping(buchholzMode, opponentScores, lowest: 2, highest: 0);
            row.MedianBuchholz = UnplayedRoundTiebreak.SumAfterDropping(buchholzMode, opponentScores, lowest: 1, highest: 1);
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

        // Sichtbar bleibt wie bisher nur der aktive Teilnehmerkreis; zurueckgezogene
        // oder pausierte Spieler erscheinen nicht (erneut) in der Rangliste, ihre
        // gespielten Partien sind aber oben vollstaendig eingerechnet.
        var visibleRows = rows.Values.Where(r => r.Player.IsActive).ToList();

        foreach (var group in visibleRows.GroupBy(r => r.Points))
        {
            var playerIds = group.Select(g => g.Player.Id).ToHashSet();
            foreach (var row in group)
            {
                row.DirectEncounter = row.DirectResults.Where(r => playerIds.Contains(r.OpponentId)).Sum(r => r.ScoreAgainstOpponent);
            }
        }

        var ordered = visibleRows
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

    private static void ApplyPairing(
        TournamentState tournament,
        int roundNumber,
        Pairing pairing,
        Dictionary<Guid, MutableStanding> rows,
        bool roundFinalized)
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
            var byeScore = ScoringRules.ScoreFor(pairing.Result, isWhite: true, tournament.Settings.ScoringSystem);
            white.Points += byeScore;
            if (ScoringRules.IsWinFor(pairing.Result, isWhite: true, countForfeitWins: true, countByeAsWin: tournament.Settings.CountByeAsWin))
            {
                white.Wins++;
            }
            if (IsOwnUnplayedRound(pairing.Result.Kind, roundFinalized))
            {
                // Bye/kampfloses Einzelergebnis ohne realen Gegner: eigene
                // ungespielte Runde mit Bye-Obergrenze (Art. 16.4.2).
                white.UnplayedRounds.Add(new UnplayedRoundEntry(
                    roundNumber,
                    OpponentId: null,
                    AwardedScore: byeScore,
                    UsesScheduledOpponentCap: false,
                    IsVoluntaryUnplayedRound: false,
                    AdjustAsDrawWithoutLaterNonVur: false,
                    IncludeVirtualBuchholz: true));
                white.NonVoluntaryRoundNumbers.Add(roundNumber);
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

        var whiteNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: true);
        var blackNormalized = ScoringRules.NormalizedClassicalScore(pairing.Result.Kind, isWhite: false);

        var countsAsRealBuchholzOpponent = ResultPolicy.CountsAsOpponentForBuchholz(pairing.Result.Kind, tournament.Settings);
        var whiteUnplayed = CreateUnplayedRoundEntry(
            roundNumber,
            pairing.Result.Kind,
            isWhite: true,
            black.Player.Id,
            whiteScore,
            roundFinalized,
            includeVirtualBuchholz: !countsAsRealBuchholzOpponent);
        var blackUnplayed = CreateUnplayedRoundEntry(
            roundNumber,
            pairing.Result.Kind,
            isWhite: false,
            white.Player.Id,
            blackScore,
            roundFinalized,
            includeVirtualBuchholz: !countsAsRealBuchholzOpponent);

        if (whiteUnplayed is not null)
        {
            white.UnplayedRounds.Add(whiteUnplayed);
        }
        else if (ScoringRules.IsOverTheBoard(pairing.Result.Kind))
        {
            white.NonVoluntaryRoundNumbers.Add(roundNumber);
        }

        if (blackUnplayed is not null)
        {
            black.UnplayedRounds.Add(blackUnplayed);
        }
        else if (ScoringRules.IsOverTheBoard(pairing.Result.Kind))
        {
            black.NonVoluntaryRoundNumbers.Add(roundNumber);
        }

        if (whiteUnplayed is { IsVoluntaryUnplayedRound: false })
        {
            white.NonVoluntaryRoundNumbers.Add(roundNumber);
        }

        if (blackUnplayed is { IsVoluntaryUnplayedRound: false })
        {
            black.NonVoluntaryRoundNumbers.Add(roundNumber);
        }

        if (countsAsRealBuchholzOpponent)
        {
            white.BuchholzOpponents.Add(new BuchholzOpponentEntry(
                black.Player.Id,
                whiteUnplayed?.IsVoluntaryUnplayedRound ?? false));
            black.BuchholzOpponents.Add(new BuchholzOpponentEntry(
                white.Player.Id,
                blackUnplayed?.IsVoluntaryUnplayedRound ?? false));
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

    /// <summary>
    /// Eigene ungespielte Runde aus Sicht eines Spielers: eingetragene Byes und
    /// kampflose Ergebnisse sofort; ein offenes <see cref="GameResultKind.NotPlayed"/>
    /// erst, wenn die Runde abgeschlossen ist (offene/zukuenftige Partien werden nie
    /// vorzeitig als virtuelle Gegner gewertet).
    /// </summary>
    private static bool IsOwnUnplayedRound(GameResultKind kind, bool roundFinalized)
    {
        if (kind == GameResultKind.NotPlayed)
        {
            return roundFinalized;
        }

        return UnplayedRoundTiebreak.IsUnplayedRound(kind);
    }

    private static UnplayedRoundEntry? CreateUnplayedRoundEntry(
        int roundNumber,
        GameResultKind kind,
        bool isWhite,
        Guid opponentId,
        decimal awardedScore,
        bool roundFinalized,
        bool includeVirtualBuchholz)
    {
        if (!IsOwnUnplayedRound(kind, roundFinalized))
        {
            return null;
        }

        var isForfeitWin = kind switch
        {
            GameResultKind.WhiteForfeitWin => isWhite,
            GameResultKind.BlackForfeitWin => !isWhite,
            _ => false
        };
        var isForfeitLoss = kind == GameResultKind.DoubleForfeit
            || kind == GameResultKind.WhiteForfeitWin && !isWhite
            || kind == GameResultKind.BlackForfeitWin && isWhite;

        return new UnplayedRoundEntry(
            roundNumber,
            OpponentId: kind == GameResultKind.NotPlayed ? null : opponentId,
            AwardedScore: awardedScore,
            UsesScheduledOpponentCap: isForfeitWin || isForfeitLoss,
            IsVoluntaryUnplayedRound: isForfeitLoss || kind == GameResultKind.NotPlayed,
            AdjustAsDrawWithoutLaterNonVur: kind == GameResultKind.NotPlayed,
            IncludeVirtualBuchholz: includeVirtualBuchholz);
    }

    private static decimal AdjustedScoreForOpponents(MutableStanding row, decimal drawScore)
    {
        var adjustedScore = row.Points;
        foreach (var entry in row.UnplayedRounds.Where(entry => entry.AdjustAsDrawWithoutLaterNonVur))
        {
            var hasLaterNonVur = row.NonVoluntaryRoundNumbers.Any(roundNumber => roundNumber > entry.RoundNumber);
            if (!hasLaterNonVur)
            {
                // Art. 16.2.5/16.3.2: am Ende liegende angeforderte/sonstige
                // ungespielte Runden werden für die Gegnerwertung als Remis bewertet.
                adjustedScore += drawScore - entry.AwardedScore;
            }
        }

        return adjustedScore;
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
        public List<BuchholzOpponentEntry> BuchholzOpponents { get; } = new();
        public List<UnplayedRoundEntry> UnplayedRounds { get; } = new();
        public HashSet<int> NonVoluntaryRoundNumbers { get; } = new();
        public List<decimal> OpponentRatings { get; } = new();
        public List<decimal> PerformanceOpponentRatings { get; } = new();
        public List<DirectResult> DirectResults { get; } = new();
        public List<DirectResult> SonnebornContributions { get; } = new();
        public decimal NormalizedPerformancePoints { get; set; }
        public int PerformanceGames { get; set; }
    }

    private sealed record DirectResult(Guid OpponentId, decimal ScoreAgainstOpponent);

    private sealed record BuchholzOpponentEntry(Guid OpponentId, bool IsVoluntaryUnplayedRound);

    /// <summary>
    /// Eigene ungespielte Runde eines Spielers. Die Felder erhalten sowohl die
    /// Information für Art. 16.3/16.4 als auch die VUR-Markierung für Art. 16.5.
    /// </summary>
    private sealed record UnplayedRoundEntry(
        int RoundNumber,
        Guid? OpponentId,
        decimal AwardedScore,
        bool UsesScheduledOpponentCap,
        bool IsVoluntaryUnplayedRound,
        bool AdjustAsDrawWithoutLaterNonVur,
        bool IncludeVirtualBuchholz);
}
