namespace SchachTurnierManager.Domain.Models;

public sealed record TournamentRound
{
    public int RoundNumber { get; init; }
    public IReadOnlyList<Pairing> Pairings { get; init; } = Array.Empty<Pairing>();
    public PairingAudit Audit { get; init; } = new();
    public PairingForensics? Forensics { get; init; }
    public bool IsLocked { get; init; }
    public bool IsVerified { get; init; }
    public RoundResultStatus ResultStatus { get; init; } = RoundResultStatus.Open;
    public DateTimeOffset? LockedAt { get; init; }
    public DateTimeOffset? VerifiedAt { get; init; }
    public string? Notes { get; init; }
}
