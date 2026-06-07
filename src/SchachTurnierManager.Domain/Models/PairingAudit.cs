namespace SchachTurnierManager.Domain.Models;

public sealed record PairingAudit
{
    public string Algorithm { get; init; } = string.Empty;
    public string RulesetVersion { get; init; } = "STM-0.1-basic";
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
    public IReadOnlyList<string> Messages { get; init; } = Array.Empty<string>();
}
