namespace SchachTurnierManager.Domain.Models;

public sealed record CrossTable
{
    public IReadOnlyList<CrossTablePlayer> Players { get; init; } = Array.Empty<CrossTablePlayer>();
    public IReadOnlyList<CrossTableRow> Rows { get; init; } = Array.Empty<CrossTableRow>();
}

public sealed record CrossTablePlayer
{
    public Guid PlayerId { get; init; }
    public string Name { get; init; } = string.Empty;
    public int Rank { get; init; }
    public int StartingRank { get; init; }
    public decimal Points { get; init; }
}

public sealed record CrossTableRow
{
    public Guid PlayerId { get; init; }
    public string Name { get; init; } = string.Empty;
    public int Rank { get; init; }
    public decimal Points { get; init; }
    public IReadOnlyList<CrossTableCell> Cells { get; init; } = Array.Empty<CrossTableCell>();
}

public sealed record CrossTableCell
{
    public Guid PlayerId { get; init; }
    public Guid OpponentId { get; init; }
    public bool IsSelf { get; init; }
    public int? RoundNumber { get; init; }
    public int? BoardNumber { get; init; }
    public ChessColor Color { get; init; } = ChessColor.None;
    public string ResultLabel { get; init; } = string.Empty;
    public decimal? Points { get; init; }
    public bool IsBye { get; init; }
    public string? Notes { get; init; }
}
