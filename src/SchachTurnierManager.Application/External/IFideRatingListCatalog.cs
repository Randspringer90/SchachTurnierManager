using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application.External;

public sealed record FideRatingListInfo(bool Available, DateTimeOffset? ImportedAt, long Bytes, bool Stale);
public sealed record FideRatingListImport(int Players, DateTimeOffset ImportedAt);

/// <summary>Explicit local import of an official unpacked standard TXT list; never downloads or transmits queries.</summary>
public interface IFideRatingListCatalog
{
    FideRatingListInfo Info { get; }
    Task<FideRatingListImport> ImportAsync(Stream input, CancellationToken cancellationToken = default);
    Task<ExternalPlayerLookupResult> SearchAsync(string query, string? federation = null, CancellationToken cancellationToken = default);
}
