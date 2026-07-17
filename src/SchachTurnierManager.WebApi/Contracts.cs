using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.WebApi;

public sealed record CreateTournamentRequest(string Name, TournamentSettings? Settings);

public sealed record UpdateTournamentSettingsRequest(TournamentSettings Settings);

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

public sealed record RecordBoardResultRequest(int RoundNumber, int BoardNumber, GameResultKind Result);

public sealed record OverridePairingRequest(Guid? WhitePlayerId, Guid? BlackPlayerId, string? Notes);

public sealed record UpdateRoundLockRequest(bool IsLocked);

public sealed record UpdateRoundVerifiedRequest(bool IsVerified);

public sealed record RollChess960StartPositionsRequest(bool OverwriteExisting = false, int? Seed = null);

public sealed record RollChess960StartPositionForBoardRequest(bool OverwriteExisting = false, int? Seed = null, int? PositionNumber = null);

public sealed record UpdatePlayerStatusRequest(PlayerStatus Status);

public sealed record ImportPlayersCsvRequest(string Content, bool ReplaceExisting = false);

public sealed record PreviewPlayersCsvRequest(string Content, bool ReplaceExisting = false);

/// <summary>
/// STM-IE-002: FileBytes statt eines bereits dekodierten Strings, damit der Server echte
/// UTF-8-/Windows-1252-Erkennung durchfuehren kann (Issue-Anforderung). System.Text.Json
/// (de)serialisiert byte[] automatisch als Base64-String, das WebApp-Frontend liest die
/// Datei entsprechend als Bytes statt als Text.
/// </summary>
public sealed record ImportPlayersFileRequest(byte[] FileBytes, bool ReplaceExisting = false);

public sealed record ImportTournamentRequest(TournamentState Tournament, bool OverwriteExisting = true);

public sealed record ExternalPlayerDuplicateRequest(ExternalPlayerProfile Profile);

public sealed record ApplyExternalPlayerRequest(
    ExternalPlayerProfile Profile,
    Guid? TargetPlayerId,
    bool CreateIfNoTarget = true,
    bool OverwriteExistingValues = false);

