namespace SchachTurnierManager.Domain.Models;

/// <summary>Immutable pairing inputs saved with the tournament at round one.</summary>
public sealed record RoundRobinPlan
{
    public string AlgorithmVersion { get; init; } = string.Empty;
    public IReadOnlyList<Guid> ParticipantOrder { get; init; } = Array.Empty<Guid>();
}
