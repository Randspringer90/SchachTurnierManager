namespace SchachTurnierManager.Domain.Models;

public enum ExternalPlayerDuplicateKind
{
    FideId = 0,
    NationalId = 1,
    NameAndBirthYear = 2,
    NameOnly = 3
}

public enum ExternalPlayerConflictSeverity
{
    Information = 0,
    Warning = 1,
    Critical = 2
}

public sealed record ExternalPlayerDuplicateMatch
{
    public Guid PlayerId { get; init; }
    public string PlayerName { get; init; } = string.Empty;
    public ExternalPlayerDuplicateKind Kind { get; init; }
    public int Score { get; init; }
    public string Reason { get; init; } = string.Empty;
}

public sealed record ExternalPlayerDataConflict
{
    public Guid? PlayerId { get; init; }
    public string? PlayerName { get; init; }
    public string FieldName { get; init; } = string.Empty;
    public string? LocalValue { get; init; }
    public string? ExternalValue { get; init; }
    public ExternalPlayerConflictSeverity Severity { get; init; } = ExternalPlayerConflictSeverity.Warning;
    public bool WillOverwrite { get; init; }
    public string Recommendation { get; init; } = string.Empty;
}

public sealed record ExternalPlayerDuplicateCheck
{
    public ExternalPlayerProfile Profile { get; init; } = new();
    public IReadOnlyList<ExternalPlayerDuplicateMatch> Matches { get; init; } = Array.Empty<ExternalPlayerDuplicateMatch>();
    public IReadOnlyList<ExternalPlayerDataConflict> Conflicts { get; init; } = Array.Empty<ExternalPlayerDataConflict>();
    public bool HasLikelyDuplicate => Matches.Any(match => match.Score >= 80);
    public bool HasCriticalConflict => Conflicts.Any(conflict => conflict.Severity == ExternalPlayerConflictSeverity.Critical);
}

public sealed record ExternalPlayerApplyResult
{
    public Player Player { get; init; } = new();
    public bool Created { get; init; }
    public bool Updated { get; init; }
    public ExternalPlayerDuplicateCheck DuplicateCheck { get; init; } = new();
    public IReadOnlyList<string> ChangedFields { get; init; } = Array.Empty<string>();
    public IReadOnlyList<ExternalPlayerDataConflict> Conflicts { get; init; } = Array.Empty<ExternalPlayerDataConflict>();
    public string Message { get; init; } = string.Empty;
}
