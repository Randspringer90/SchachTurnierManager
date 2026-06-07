namespace SchachTurnierManager.Domain.Models;

public sealed record TournamentRound
{
    public int RoundNumber { get; init; }
    public IReadOnlyList<Pairing> Pairings { get; init; } = Array.Empty<Pairing>();
    public PairingAudit Audit { get; init; } = new();
}
