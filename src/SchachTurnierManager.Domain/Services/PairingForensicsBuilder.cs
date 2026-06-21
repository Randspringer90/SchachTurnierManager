using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Verdichtet den Entscheidungsstand einer Vorschau/Auslosung zu einem unveränderlichen
/// <see cref="PairingForensics"/>-Datensatz. Reine Diagnose – verändert keinerlei Paarungslogik.
/// </summary>
public sealed class PairingForensicsBuilder
{
    private readonly PairingQualityAnalyzer _quality = new();

    public PairingForensics Build(TournamentState tournament, TournamentRound round, string trigger)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        ArgumentNullException.ThrowIfNull(round);

        var quality = _quality.Analyze(tournament, round);
        var pairingByBoard = round.Pairings.ToDictionary(pairing => pairing.BoardNumber);

        var activeCount = tournament.Players.Count(player => player.IsActive);
        var inactiveCount = tournament.Players.Count - activeCount;
        var openResultsBeforeRound = tournament.Rounds
            .Where(existing => existing.RoundNumber < round.RoundNumber)
            .SelectMany(existing => existing.Pairings)
            .Count(pairing => !pairing.IsBye && pairing.Result.Kind == GameResultKind.NotPlayed);

        var byeDecisions = quality.Boards
            .Where(board => board.IsBye)
            .Select(board => $"Brett {board.BoardNumber}: spielfrei für {board.WhiteName}.")
            .ToList();

        var rematchWarnings = quality.Boards
            .Where(board => board.IsRematch)
            .Select(board => $"Brett {board.BoardNumber}: Rematch {board.WhiteName} gegen {board.BlackName}.")
            .ToList();

        var scoreGroupDeviations = quality.Boards
            .Where(board => board.IsCrossScoreGroupPairing)
            .Select(board => $"Brett {board.BoardNumber}: {board.WhiteName} ({board.WhiteScoreBeforeRound}) gegen {board.BlackName} ({board.BlackScoreBeforeRound}), Differenz {board.ScoreDifference}.")
            .ToList();

        var proposedPairings = quality.Boards
            .Select(board => new PairingForensicsBoard
            {
                BoardNumber = board.BoardNumber,
                White = board.WhiteName,
                Black = board.BlackName,
                WhiteScoreBeforeRound = board.WhiteScoreBeforeRound,
                BlackScoreBeforeRound = board.BlackScoreBeforeRound,
                ScoreDifference = board.ScoreDifference,
                IsBye = board.IsBye,
                IsManualOverride = pairingByBoard.TryGetValue(board.BoardNumber, out var pairing) && pairing.IsManualOverride,
                IsRematch = board.IsRematch,
                IsCrossScoreGroupPairing = board.IsCrossScoreGroupPairing
            })
            .ToList();

        return new PairingForensics
        {
            Trigger = string.IsNullOrWhiteSpace(trigger) ? "generated" : trigger.Trim(),
            Format = tournament.Settings.Format.ToString(),
            Algorithm = string.IsNullOrWhiteSpace(round.Audit.Algorithm) ? tournament.Settings.Format.ToString() : round.Audit.Algorithm,
            PlannedRounds = tournament.Settings.PlannedRounds,
            CurrentRound = round.RoundNumber,
            ActivePlayerCount = activeCount,
            InactivePlayerCount = inactiveCount,
            OpenResultsBeforeRound = openResultsBeforeRound,
            BoardCount = quality.BoardCount,
            GameCount = quality.GameCount,
            ByeCount = quality.ByeCount,
            ManualOverrideCount = proposedPairings.Count(board => board.IsManualOverride),
            RematchCount = quality.RematchCount,
            CrossScoreGroupPairingCount = quality.CrossScoreGroupPairingCount,
            ThirdSameColorRiskCount = quality.ThirdSameColorRiskCount,
            QualityScore = quality.QualityScore,
            QualitySeverity = quality.Severity.ToString(),
            ByeDecisions = byeDecisions,
            RematchWarnings = rematchWarnings,
            ScoreGroupDeviations = scoreGroupDeviations,
            ColorNotes = round.Audit.ColorNotes,
            EngineMessages = round.Audit.Messages,
            Findings = quality.Findings,
            ProposedPairings = proposedPairings
        };
    }
}
