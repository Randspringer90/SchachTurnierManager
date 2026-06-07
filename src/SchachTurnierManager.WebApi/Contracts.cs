using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.WebApi;

public sealed record CreateTournamentRequest(string Name, TournamentSettings? Settings);

public sealed record PlayerRequest(
    string Name,
    string? Club,
    string? Federation,
    string? Country,
    int? BirthYear,
    GenderCategory Gender,
    int? Elo,
    int? RapidElo,
    int? BlitzElo,
    int? Dwz,
    int? DwzIndex,
    int? ManualTwz,
    string? FideId,
    string? NationalId,
    string? Title,
    PlayerStatus Status,
    string? Notes,
    int? StartingRank)
{
    public Player ToPlayer(Guid? id = null)
    {
        return new Player
        {
            Id = id ?? Guid.NewGuid(),
            Name = Name,
            Club = Club,
            Federation = Federation,
            Country = Country,
            BirthYear = BirthYear,
            Gender = Gender,
            FideId = FideId,
            NationalId = NationalId,
            Title = Title,
            StartingRank = StartingRank ?? 0,
            Status = Status,
            Notes = Notes,
            Rating = new RatingProfile
            {
                Elo = Elo,
                RapidElo = RapidElo,
                BlitzElo = BlitzElo,
                Dwz = Dwz,
                DwzIndex = DwzIndex,
                ManualTwz = ManualTwz
            }
        };
    }
}

public sealed record RecordResultRequest(GameResultKind Result);
