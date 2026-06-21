namespace SchachTurnierManager.Domain.Models;

/// <summary>
/// Forensischer Entscheidungsstand zum Zeitpunkt einer Paarungs-Vorschau oder -Auslosung.
/// Wird unveränderlich pro Runde festgehalten, damit später nachvollziehbar ist, welche
/// Einstellung galt, welche Paarungen vorgeschlagen wurden und welche Warnungen/Blocker
/// griffen – auch nachdem Ergebnisse eingetragen oder Spielerstatus geändert wurden.
/// </summary>
public sealed record PairingForensics
{
    /// <summary>"preview" für eine unverbindliche Vorschau, "generated" für die übernommene Auslosung.</summary>
    public string Trigger { get; init; } = "generated";
    public DateTimeOffset CapturedAt { get; init; } = DateTimeOffset.UtcNow;
    public string Format { get; init; } = string.Empty;
    public string Algorithm { get; init; } = string.Empty;
    public int PlannedRounds { get; init; }
    public int CurrentRound { get; init; }
    public int ActivePlayerCount { get; init; }
    public int InactivePlayerCount { get; init; }
    public int OpenResultsBeforeRound { get; init; }
    public int BoardCount { get; init; }
    public int GameCount { get; init; }
    public int ByeCount { get; init; }
    public int ManualOverrideCount { get; init; }
    public int RematchCount { get; init; }
    public int CrossScoreGroupPairingCount { get; init; }
    public int ThirdSameColorRiskCount { get; init; }
    public int QualityScore { get; init; }
    public string QualitySeverity { get; init; } = string.Empty;
    public IReadOnlyList<string> ByeDecisions { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> RematchWarnings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> ScoreGroupDeviations { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> ColorNotes { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> EngineMessages { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> Findings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<PairingForensicsBoard> ProposedPairings { get; init; } = Array.Empty<PairingForensicsBoard>();

    public string ToSummaryLine()
    {
        return $"Format {Format}, geplante Runden {PlannedRounds}, aktuelle Runde {CurrentRound}, "
            + $"aktiv {ActivePlayerCount}/inaktiv {InactivePlayerCount}, offene Vorrundenergebnisse {OpenResultsBeforeRound}, "
            + $"Bretter {BoardCount} (Byes {ByeCount}, manuelle Paarungen {ManualOverrideCount}), "
            + $"Rematches {RematchCount}, Scoregruppen-Abweichungen {CrossScoreGroupPairingCount}, "
            + $"Farbfolgerisiken {ThirdSameColorRiskCount}, Qualität {QualityScore}/100 ({QualitySeverity}).";
    }
}

public sealed record PairingForensicsBoard
{
    public int BoardNumber { get; init; }
    public string White { get; init; } = string.Empty;
    public string Black { get; init; } = string.Empty;
    public decimal WhiteScoreBeforeRound { get; init; }
    public decimal BlackScoreBeforeRound { get; init; }
    public decimal ScoreDifference { get; init; }
    public bool IsBye { get; init; }
    public bool IsManualOverride { get; init; }
    public bool IsRematch { get; init; }
    public bool IsCrossScoreGroupPairing { get; init; }
}
