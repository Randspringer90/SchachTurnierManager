namespace SchachTurnierManager.Domain.Models;

public sealed record ExportDocument
{
    public string FileName { get; init; } = string.Empty;
    public string ContentType { get; init; } = "text/plain; charset=utf-8";
    public string Content { get; init; } = string.Empty;
}
