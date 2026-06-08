namespace SchachTurnierManager.Domain.Models;

public enum ExternalPlayerDuplicateKind
{
    FideId = 0,
    NationalId = 1,
    NameAndBirthYear = 2,
    NameOnly = 3
}

public sealed record ExternalPlayerDuplicateMatch
{
    public Guid PlayerId { get; init; }
    public string PlayerName { get; init; } = string.Empty;
    public ExternalPlayerDuplicateKind Kind { get; init; }
    public int Score { get; init; }
    public string Reason { get; init; } = string.Empty;
}

public sealed record ExternalPlayerDuplicateCheck
{
    public ExternalPlayerProfile Profile { get; init; } = new();
    public IReadOnlyList<ExternalPlayerDuplicateMatch> Matches { get; init; } = Array.Empty<ExternalPlayerDuplicateMatch>();
    public bool HasLikelyDuplicate => Matches.Any(match => match.Score >= 80);
}

public sealed record ExternalPlayerApplyResult
{
    public Player Player { get; init; } = new();
    public bool Created { get; init; }
    public bool Updated { get; init; }
    public ExternalPlayerDuplicateCheck DuplicateCheck { get; init; } = new();
    public IReadOnlyList<string> ChangedFields { get; init; } = Array.Empty<string>();
    public string Message { get; init; } = string.Empty;
}
