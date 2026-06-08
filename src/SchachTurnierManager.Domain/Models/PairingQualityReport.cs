using System;
using System.Collections.Generic;
using System.Linq;

namespace SchachTurnierManager.Domain.Models;

public enum PairingQualitySeverity
{
    Good = 0,
    Notice = 1,
    Warning = 2,
    Critical = 3
}

public sealed record PairingQualityReport
{
    public int RoundNumber { get; init; }
    public int BoardCount { get; init; }
    public int GameCount { get; init; }
    public int ByeCount { get; init; }
    public int RematchCount { get; init; }
    public int CrossScoreGroupPairingCount { get; init; }
    public int ThirdSameColorRiskCount { get; init; }
    public decimal MaxScoreDifference { get; init; }
    public decimal AverageScoreDifference { get; init; }
    public int QualityScore { get; init; }
    public PairingQualitySeverity Severity { get; init; } = PairingQualitySeverity.Good;
    public IReadOnlyList<string> Findings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<PairingQualityBoard> Boards { get; init; } = Array.Empty<PairingQualityBoard>();

    public bool HasCriticalIssues => Severity == PairingQualitySeverity.Critical;
    public bool HasWarnings => Severity >= PairingQualitySeverity.Warning;
    public int FindingCount => Findings.Count;
}

public sealed record PairingQualityBoard
{
    public int BoardNumber { get; init; }
    public Guid? WhitePlayerId { get; init; }
    public Guid? BlackPlayerId { get; init; }
    public string WhiteName { get; init; } = string.Empty;
    public string BlackName { get; init; } = string.Empty;
    public decimal WhiteScoreBeforeRound { get; init; }
    public decimal BlackScoreBeforeRound { get; init; }
    public decimal ScoreDifference { get; init; }
    public bool IsBye { get; init; }
    public bool IsRematch { get; init; }
    public bool IsCrossScoreGroupPairing { get; init; }
    public bool WouldGiveWhiteThirdSameColor { get; init; }
    public bool WouldGiveBlackThirdSameColor { get; init; }
    public IReadOnlyList<string> Findings { get; init; } = Array.Empty<string>();
}