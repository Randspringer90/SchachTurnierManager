namespace SchachTurnierManager.Domain.Models;

public sealed record Chess960StartPosition
{
    public string WhiteBackRank { get; init; } = string.Empty;
    public string BlackBackRank { get; init; } = string.Empty;
    public int PositionNumber { get; init; }
    public int? Seed { get; init; }
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;

    public string Notation => WhiteBackRank;
    public string DisplayName => $"SP {PositionNumber}: {WhiteBackRank}";
}
