namespace SchachTurnierManager.Domain.Models;

public sealed record Player
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Name { get; init; } = string.Empty;
    public string? Club { get; init; }
    public string? Federation { get; init; }
    public string? Country { get; init; }
    public int? BirthYear { get; init; }
    public GenderCategory Gender { get; init; } = GenderCategory.Unknown;
    public string? FideId { get; init; }
    public string? NationalId { get; init; }
    public string? Title { get; init; }
    public int StartingRank { get; init; }
    public RatingProfile Rating { get; init; } = new();
    public PlayerStatus Status { get; init; } = PlayerStatus.Active;
    public string? Notes { get; init; }

    public bool IsActive => Status == PlayerStatus.Active;

    public int Twz(TwzSource source) => Rating.TwzFor(source);
}
