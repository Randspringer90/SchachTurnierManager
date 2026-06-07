namespace SchachTurnierManager.Domain.Models;

public sealed record Pairing
{
    public int BoardNumber { get; init; }
    public Guid? WhitePlayerId { get; init; }
    public Guid? BlackPlayerId { get; init; }
    public GameResult Result { get; init; } = GameResult.NotPlayed;
    public bool IsManualOverride { get; init; }
    public DateTimeOffset? LastChangedAt { get; init; }
    public string? Notes { get; init; }

    public bool IsBye => BlackPlayerId is null || Result.Kind == GameResultKind.Bye;

    public static Pairing Game(int boardNumber, Guid whitePlayerId, Guid blackPlayerId, string? notes = null)
    {
        return new Pairing
        {
            BoardNumber = boardNumber,
            WhitePlayerId = whitePlayerId,
            BlackPlayerId = blackPlayerId,
            Notes = notes
        };
    }

    public static Pairing Bye(int boardNumber, Guid playerId)
    {
        return new Pairing
        {
            BoardNumber = boardNumber,
            WhitePlayerId = playerId,
            BlackPlayerId = null,
            Result = new GameResult(GameResultKind.Bye),
            Notes = "Spielfrei / Bye"
        };
    }
}
