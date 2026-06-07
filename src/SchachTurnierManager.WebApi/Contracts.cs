using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.WebApi;

public sealed record CreateTournamentRequest(string Name, TournamentSettings? Settings);
public sealed record AddPlayerRequest(
    string Name,
    string? Club,
    int? BirthYear,
    GenderCategory Gender,
    int? Elo,
    int? Dwz,
    int? ManualTwz,
    string? FideId,
    string? Title);
public sealed record RecordResultRequest(GameResultKind Result);
