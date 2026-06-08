using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application.External;

public interface IExternalPlayerLookupProvider
{
    ExternalPlayerSource Source { get; }
    ExternalPlayerProviderInfo Info { get; }

    Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default);

    Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default);
}
