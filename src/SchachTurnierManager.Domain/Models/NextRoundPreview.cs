namespace SchachTurnierManager.Domain.Models;

public sealed record NextRoundPreview
{
    public int RoundNumber { get; init; }
    public int BoardCount { get; init; }
    public bool IsSavable { get; init; } = true;
    public string Summary { get; init; } = string.Empty;
    public TournamentRound Round { get; init; } = new();
    public PairingQualityReport PairingQuality { get; init; } = new();
    public IReadOnlyList<string> Messages { get; init; } = Array.Empty<string>();
}
