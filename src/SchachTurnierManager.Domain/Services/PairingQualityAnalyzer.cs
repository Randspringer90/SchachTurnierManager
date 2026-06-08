using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class PairingQualityAnalyzer
{
    public PairingQualityReport Analyze(TournamentState tournament, TournamentRound round)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        ArgumentNullException.ThrowIfNull(round);

        var players = tournament.Players.ToDictionary(player => player.Id);
        var priorRounds = tournament.Rounds
            .Where(existingRound => existingRound.RoundNumber < round.RoundNumber)
            .OrderBy(existingRound => existingRound.RoundNumber)
            .ToList();

        var priorTournament = new TournamentState
        {
            Id = tournament.Id,
            Name = tournament.Name,
            CreatedOn = tournament.CreatedOn,
            Settings = tournament.Settings
        };
        priorTournament.Players.AddRange(tournament.Players);
        priorTournament.Rounds.AddRange(priorRounds);

        var pointsBeforeRound = new StandingsCalculator()
            .Calculate(priorTournament)
            .ToDictionary(row => row.PlayerId, row => row.Points);

        var history = BuildHistory(tournament.Players, priorRounds);
        var boardReports = new List<PairingQualityBoard>();

        foreach (var pairing in round.Pairings.OrderBy(pairing => pairing.BoardNumber))
        {
            boardReports.Add(AnalyzeBoard(pairing, players, pointsBeforeRound, history));
        }

        var gameBoards = boardReports.Where(board => !board.IsBye).ToList();
        var findings = BuildFindings(boardReports);
        var averageScoreDifference = gameBoards.Count == 0 ? 0m : gameBoards.Average(board => board.ScoreDifference);
        var maxScoreDifference = gameBoards.Count == 0 ? 0m : gameBoards.Max(board => board.ScoreDifference);
        var rematches = boardReports.Count(board => board.IsRematch);
        var crossScoreGroupPairings = boardReports.Count(board => board.IsCrossScoreGroupPairing);
        var thirdSameColorRisks = boardReports.Count(board => board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor);
        var byeCount = boardReports.Count(board => board.IsBye);
        var qualityScore = CalculateQualityScore(rematches, crossScoreGroupPairings, thirdSameColorRisks, maxScoreDifference);

        return new PairingQualityReport
        {
            RoundNumber = round.RoundNumber,
            BoardCount = boardReports.Count,
            GameCount = gameBoards.Count,
            ByeCount = byeCount,
            RematchCount = rematches,
            CrossScoreGroupPairingCount = crossScoreGroupPairings,
            ThirdSameColorRiskCount = thirdSameColorRisks,
            MaxScoreDifference = maxScoreDifference,
            AverageScoreDifference = decimal.Round(averageScoreDifference, 2),
            QualityScore = qualityScore,
            Severity = DetermineSeverity(rematches, crossScoreGroupPairings, thirdSameColorRisks, byeCount),
            Findings = findings,
            Boards = boardReports
        };
    }

    private static PairingQualityBoard AnalyzeBoard(
        Pairing pairing,
        IReadOnlyDictionary<Guid, Player> players,
        IReadOnlyDictionary<Guid, decimal> pointsBeforeRound,
        IReadOnlyDictionary<Guid, PairingQualityPlayerHistory> history)
    {
        var findings = new List<string>();
        var whiteName = PlayerName(players, pairing.WhitePlayerId);
        var blackName = pairing.IsBye ? "spielfrei" : PlayerName(players, pairing.BlackPlayerId);

        if (pairing.IsBye || pairing.WhitePlayerId is null || pairing.BlackPlayerId is null)
        {
            findings.Add($"Brett {pairing.BoardNumber}: Bye/Spielfrei für {whiteName}.");
            return new PairingQualityBoard
            {
                BoardNumber = pairing.BoardNumber,
                WhitePlayerId = pairing.WhitePlayerId,
                BlackPlayerId = pairing.BlackPlayerId,
                WhiteName = whiteName,
                BlackName = blackName,
                IsBye = true,
                Findings = findings
            };
        }

        var whiteScore = pointsBeforeRound.GetValueOrDefault(pairing.WhitePlayerId.Value);
        var blackScore = pointsBeforeRound.GetValueOrDefault(pairing.BlackPlayerId.Value);
        var scoreDifference = Math.Abs(whiteScore - blackScore);
        var whiteHistory = history[pairing.WhitePlayerId.Value];
        var blackHistory = history[pairing.BlackPlayerId.Value];
        var isRematch = whiteHistory.OpponentIds.Contains(pairing.BlackPlayerId.Value);
        var whiteThirdSameColor = WouldCreateThirdSameColor(whiteHistory.Colors, ChessColor.White);
        var blackThirdSameColor = WouldCreateThirdSameColor(blackHistory.Colors, ChessColor.Black);

        if (isRematch)
        {
            findings.Add($"Brett {pairing.BoardNumber}: Rematch {whiteName} gegen {blackName}.");
        }

        if (scoreDifference > 0)
        {
            findings.Add($"Brett {pairing.BoardNumber}: unterschiedliche Scoregruppen ({whiteScore} : {blackScore}).");
        }

        if (whiteThirdSameColor)
        {
            findings.Add($"Brett {pairing.BoardNumber}: {whiteName} bekäme zum dritten Mal in Folge Weiß.");
        }

        if (blackThirdSameColor)
        {
            findings.Add($"Brett {pairing.BoardNumber}: {blackName} bekäme zum dritten Mal in Folge Schwarz.");
        }

        return new PairingQualityBoard
        {
            BoardNumber = pairing.BoardNumber,
            WhitePlayerId = pairing.WhitePlayerId,
            BlackPlayerId = pairing.BlackPlayerId,
            WhiteName = whiteName,
            BlackName = blackName,
            WhiteScoreBeforeRound = whiteScore,
            BlackScoreBeforeRound = blackScore,
            ScoreDifference = scoreDifference,
            IsRematch = isRematch,
            IsCrossScoreGroupPairing = scoreDifference > 0,
            WouldGiveWhiteThirdSameColor = whiteThirdSameColor,
            WouldGiveBlackThirdSameColor = blackThirdSameColor,
            Findings = findings
        };
    }

    private static IReadOnlyDictionary<Guid, PairingQualityPlayerHistory> BuildHistory(
        IEnumerable<Player> players,
        IEnumerable<TournamentRound> priorRounds)
    {
        var histories = players.ToDictionary(player => player.Id, _ => new PairingQualityPlayerHistory());

        foreach (var round in priorRounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings.OrderBy(pairing => pairing.BoardNumber))
            {
                if (pairing.WhitePlayerId is null)
                {
                    continue;
                }

                if (pairing.IsBye || pairing.BlackPlayerId is null)
                {
                    if (histories.TryGetValue(pairing.WhitePlayerId.Value, out var byeHistory))
                    {
                        byeHistory.HadBye = true;
                    }

                    continue;
                }

                if (histories.TryGetValue(pairing.WhitePlayerId.Value, out var whiteHistory))
                {
                    whiteHistory.Colors.Add(ChessColor.White);
                    whiteHistory.OpponentIds.Add(pairing.BlackPlayerId.Value);
                }

                if (histories.TryGetValue(pairing.BlackPlayerId.Value, out var blackHistory))
                {
                    blackHistory.Colors.Add(ChessColor.Black);
                    blackHistory.OpponentIds.Add(pairing.WhitePlayerId.Value);
                }
            }
        }

        return histories;
    }

    private static IReadOnlyList<string> BuildFindings(IReadOnlyList<PairingQualityBoard> boards)
    {
        var findings = new List<string>();
        var rematches = boards.Where(board => board.IsRematch).ToList();
        var crossScoreGroups = boards.Where(board => board.IsCrossScoreGroupPairing).ToList();
        var colorRisks = boards.Where(board => board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor).ToList();
        var byes = boards.Where(board => board.IsBye).ToList();

        if (rematches.Count == 0)
        {
            findings.Add("Keine Wiederholungspaarung erkannt.");
        }
        else
        {
            findings.Add($"{rematches.Count} Wiederholungspaarung(en) erkannt.");
        }

        if (crossScoreGroups.Count == 0)
        {
            findings.Add("Alle regulären Bretter liegen innerhalb gleicher Scoregruppen.");
        }
        else
        {
            findings.Add($"{crossScoreGroups.Count} Paarung(en) zwischen unterschiedlichen Scoregruppen erkannt.");
        }

        if (colorRisks.Count == 0)
        {
            findings.Add("Keine dritte gleiche Farbe in Folge erkannt.");
        }
        else
        {
            findings.Add($"{colorRisks.Count} Farbfolge-Risiko/Risiken erkannt.");
        }

        if (byes.Count > 0)
        {
            findings.Add($"{byes.Count} Bye/Spielfrei in dieser Runde.");
        }

        return findings;
    }

    private static PairingQualitySeverity DetermineSeverity(int rematches, int crossScoreGroupPairings, int thirdSameColorRisks, int byeCount)
    {
        if (rematches > 0)
        {
            return PairingQualitySeverity.Critical;
        }

        if (thirdSameColorRisks > 0)
        {
            return PairingQualitySeverity.Warning;
        }

        if (crossScoreGroupPairings > 0 || byeCount > 0)
        {
            return PairingQualitySeverity.Notice;
        }

        return PairingQualitySeverity.Good;
    }

    private static int CalculateQualityScore(int rematches, int crossScoreGroupPairings, int thirdSameColorRisks, decimal maxScoreDifference)
    {
        var score = 100
            - rematches * 35
            - crossScoreGroupPairings * 8
            - thirdSameColorRisks * 20
            - (int)Math.Round(maxScoreDifference * 8m, MidpointRounding.AwayFromZero);

        return Math.Max(0, Math.Min(100, score));
    }

    private static bool WouldCreateThirdSameColor(IReadOnlyList<ChessColor> priorColors, ChessColor assignedColor)
    {
        return priorColors.Count >= 2
               && priorColors[^1] == assignedColor
               && priorColors[^2] == assignedColor;
    }

    private static string PlayerName(IReadOnlyDictionary<Guid, Player> players, Guid? playerId)
    {
        if (playerId is null)
        {
            return "—";
        }

        return players.TryGetValue(playerId.Value, out var player) ? player.Name : playerId.Value.ToString("N")[..8];
    }

    private sealed class PairingQualityPlayerHistory
    {
        public HashSet<Guid> OpponentIds { get; } = new();
        public List<ChessColor> Colors { get; } = new();
        public bool HadBye { get; set; }
    }
}