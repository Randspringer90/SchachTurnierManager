namespace SchachTurnierManager.Domain.Models;

public enum PlayerImportPreviewRowStatus
{
    Ready = 0,
    Warning = 1,
    Blocked = 2
}

public sealed record PlayerImportPreview
{
    public bool ReplaceExisting { get; init; }
    public IReadOnlyList<PlayerImportPreviewRow> Rows { get; init; } = Array.Empty<PlayerImportPreviewRow>();
    public IReadOnlyList<string> GlobalWarnings { get; init; } = Array.Empty<string>();
    public int TotalRows => Rows.Count;
    public int ImportableRows => Rows.Count(row => row.Status != PlayerImportPreviewRowStatus.Blocked);
    public int WarningRows => Rows.Count(row => row.Status == PlayerImportPreviewRowStatus.Warning);
    public int BlockingRows => Rows.Count(row => row.Status == PlayerImportPreviewRowStatus.Blocked);
    public int LikelyDuplicateRows => Rows.Count(row => row.DuplicateCheck.HasLikelyDuplicate);
    public bool HasBlockingIssues => BlockingRows > 0 || GlobalWarnings.Count > 0 && ReplaceExisting;
}

public sealed record PlayerImportPreviewRow
{
    public int RowNumber { get; init; }
    public Player Player { get; init; } = new();
    public ExternalPlayerProfile Profile { get; init; } = new();
    public ExternalPlayerDuplicateCheck DuplicateCheck { get; init; } = new();
    public IReadOnlyList<string> Warnings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<string> BlockingIssues { get; init; } = Array.Empty<string>();
    public PlayerImportPreviewRowStatus Status => BlockingIssues.Count > 0
        ? PlayerImportPreviewRowStatus.Blocked
        : Warnings.Count > 0 || DuplicateCheck.HasLikelyDuplicate
            ? PlayerImportPreviewRowStatus.Warning
            : PlayerImportPreviewRowStatus.Ready;
}
