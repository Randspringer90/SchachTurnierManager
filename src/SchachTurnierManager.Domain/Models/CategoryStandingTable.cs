namespace SchachTurnierManager.Domain.Models;

public sealed record CategoryStandingTable
{
    public string Category { get; init; } = string.Empty;
    public IReadOnlyList<StandingRow> Rows { get; init; } = Array.Empty<StandingRow>();
}
