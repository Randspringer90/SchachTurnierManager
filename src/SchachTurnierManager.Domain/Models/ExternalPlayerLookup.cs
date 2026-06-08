namespace SchachTurnierManager.Domain.Models;

public enum ExternalPlayerSource
{
    Fide = 0,
    Dsb = 1,
    Thsb = 2
}

public enum ExternalPlayerLookupStatus
{
    Found = 0,
    NotFound = 1,
    Unsupported = 2,
    Unavailable = 3,
    InvalidRequest = 4
}

public sealed record ExternalPlayerProviderInfo(
    ExternalPlayerSource Source,
    string Name,
    bool SupportsIdLookup,
    bool SupportsNameSearch,
    string Description,
    string? Url);

public sealed record ExternalPlayerLookupResult
{
    public ExternalPlayerSource Source { get; init; }
    public string Query { get; init; } = string.Empty;
    public ExternalPlayerLookupStatus Status { get; init; } = ExternalPlayerLookupStatus.NotFound;
    public string Message { get; init; } = string.Empty;
    public IReadOnlyList<ExternalPlayerProfile> Players { get; init; } = Array.Empty<ExternalPlayerProfile>();

    public static ExternalPlayerLookupResult Found(ExternalPlayerSource source, string query, params ExternalPlayerProfile[] players) => new()
    {
        Source = source,
        Query = query,
        Status = ExternalPlayerLookupStatus.Found,
        Message = $"{players.Length} Treffer gefunden.",
        Players = players
    };

    public static ExternalPlayerLookupResult Empty(ExternalPlayerSource source, string query, string message) => new()
    {
        Source = source,
        Query = query,
        Status = ExternalPlayerLookupStatus.NotFound,
        Message = message,
        Players = Array.Empty<ExternalPlayerProfile>()
    };

    public static ExternalPlayerLookupResult Unsupported(ExternalPlayerSource source, string query, string message) => new()
    {
        Source = source,
        Query = query,
        Status = ExternalPlayerLookupStatus.Unsupported,
        Message = message,
        Players = Array.Empty<ExternalPlayerProfile>()
    };

    public static ExternalPlayerLookupResult Invalid(ExternalPlayerSource source, string query, string message) => new()
    {
        Source = source,
        Query = query,
        Status = ExternalPlayerLookupStatus.InvalidRequest,
        Message = message,
        Players = Array.Empty<ExternalPlayerProfile>()
    };

    public static ExternalPlayerLookupResult Unavailable(ExternalPlayerSource source, string query, string message) => new()
    {
        Source = source,
        Query = query,
        Status = ExternalPlayerLookupStatus.Unavailable,
        Message = message,
        Players = Array.Empty<ExternalPlayerProfile>()
    };
}

public sealed record ExternalPlayerProfile
{
    public ExternalPlayerSource Source { get; init; }
    public string ExternalId { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string? Club { get; init; }
    public string? Federation { get; init; }
    public string? Country { get; init; }
    public int? BirthYear { get; init; }
    public GenderCategory Gender { get; init; } = GenderCategory.Unknown;
    public string? FideId { get; init; }
    public string? NationalId { get; init; }
    public string? Title { get; init; }
    public int? Elo { get; init; }
    public int? RapidElo { get; init; }
    public int? BlitzElo { get; init; }
    public int? Dwz { get; init; }
    public int? DwzIndex { get; init; }
    public string? ProfileUrl { get; init; }
    public DateTimeOffset RetrievedAt { get; init; } = DateTimeOffset.UtcNow;
    public double Confidence { get; init; } = 1.0;
    public string? Notes { get; init; }
    public IReadOnlyList<string> Warnings { get; init; } = Array.Empty<string>();

    public Player ToPlayer()
    {
        return new Player
        {
            Name = Name,
            Club = Club,
            Federation = Federation,
            Country = Country,
            BirthYear = BirthYear,
            Gender = Gender,
            FideId = FideId,
            NationalId = NationalId,
            Title = Title,
            Rating = new RatingProfile
            {
                Elo = Elo,
                RapidElo = RapidElo,
                BlitzElo = BlitzElo,
                Dwz = Dwz,
                DwzIndex = DwzIndex
            },
            Notes = Notes
        };
    }
}
