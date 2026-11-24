namespace SchachTurnierManager.Domain.Models;

// Pseudonymous board identifiers only. No player names, notes or credentials.
public sealed record QueuedResultMutation(
    Guid MutationId, Guid Epoch, int RoundNumber, int BoardNumber,
    GameResultKind Result, GameResultKind ExpectedPreviousResult,
    Guid WhitePlayerId, Guid BlackPlayerId, DateTimeOffset? ExpectedLastChangedAt);
