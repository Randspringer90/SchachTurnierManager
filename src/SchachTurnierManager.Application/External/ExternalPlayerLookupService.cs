using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application.External;

public sealed class ExternalPlayerLookupService(IEnumerable<IExternalPlayerLookupProvider> providers)
{
    private readonly IReadOnlyDictionary<ExternalPlayerSource, IExternalPlayerLookupProvider> _providers = providers
        .GroupBy(provider => provider.Source)
        .ToDictionary(group => group.Key, group => group.First());

    public IReadOnlyList<ExternalPlayerProviderInfo> Providers => _providers.Values
        .Select(provider => provider.Info)
        .OrderBy(info => info.Source)
        .ToArray();

    public Task<ExternalPlayerLookupResult> LookupByIdAsync(ExternalPlayerSource source, string externalId, CancellationToken cancellationToken = default)
    {
        if (!_providers.TryGetValue(source, out var provider))
        {
            return Task.FromResult(ExternalPlayerLookupResult.Unsupported(source, externalId, $"Quelle {source} ist nicht registriert."));
        }

        return provider.LookupByIdAsync(externalId, cancellationToken);
    }

    public Task<ExternalPlayerLookupResult> SearchByNameAsync(ExternalPlayerSource source, string name, CancellationToken cancellationToken = default)
    {
        if (!_providers.TryGetValue(source, out var provider))
        {
            return Task.FromResult(ExternalPlayerLookupResult.Unsupported(source, name, $"Quelle {source} ist nicht registriert."));
        }

        return provider.SearchByNameAsync(name, cancellationToken);
    }

    public Task<ExternalPlayerLookupResult> SearchAsync(ExternalPlayerSource source, string query, CancellationToken cancellationToken = default)
    {
        var normalized = query.Trim();
        if (normalized.Length == 0)
        {
            return Task.FromResult(ExternalPlayerLookupResult.Invalid(source, query, "Suchbegriff darf nicht leer sein."));
        }

        return normalized.All(char.IsDigit)
            ? LookupByIdAsync(source, normalized, cancellationToken)
            : SearchByNameAsync(source, normalized, cancellationToken);
    }
}
