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

        return IsIdQuery(normalized)
            ? LookupByIdAsync(source, normalized, cancellationToken)
            : SearchByNameAsync(source, normalized, cancellationToken);
    }

    /// <summary>
    /// Durchsucht automatisch alle registrierten Quellen und führt gleiche Personen zusammen.
    /// Nicht aktive Adapter werden ehrlich als "vorbereitet, aktuell nicht aktiv" gemeldet,
    /// ohne dass instabile externe Abfragen erzwungen werden.
    /// </summary>
    public async Task<ExternalPlayerAggregateResult> SearchAllAsync(string query, CancellationToken cancellationToken = default)
    {
        var normalized = (query ?? string.Empty).Trim();
        var isId = IsIdQuery(normalized);
        var mode = isId ? "id" : "name";

        if (normalized.Length == 0)
        {
            return new ExternalPlayerAggregateResult
            {
                Query = normalized,
                Mode = mode,
                Message = "Suchbegriff darf nicht leer sein.",
                Sources = Array.Empty<ExternalPlayerAggregateSourceResult>()
            };
        }

        var orderedProviders = _providers.Values.OrderBy(provider => provider.Source).ToArray();

        var perSource = await Task.WhenAll(orderedProviders.Select(async provider =>
        {
            var info = provider.Info;
            var active = isId ? info.SupportsIdLookup : info.SupportsNameSearch;
            if (!active)
            {
                return new SourceOutcome(
                    new ExternalPlayerAggregateSourceResult(
                        provider.Source,
                        info.Name,
                        ExternalPlayerLookupStatus.Unsupported,
                        IsActive: false,
                        isId
                            ? $"Quelle vorbereitet, aktuell nicht aktiv (keine ID-Abfrage): {info.Description}"
                            : $"Quelle vorbereitet, aktuell nicht aktiv (keine Namenssuche): {info.Description}",
                        Count: 0),
                    Array.Empty<ExternalPlayerProfile>());
            }

            ExternalPlayerLookupResult result;
            try
            {
                result = isId
                    ? await provider.LookupByIdAsync(normalized, cancellationToken).ConfigureAwait(false)
                    : await provider.SearchByNameAsync(normalized, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                result = ExternalPlayerLookupResult.Unavailable(provider.Source, normalized, $"Abfrage fehlgeschlagen: {ex.Message}");
            }

            return new SourceOutcome(
                new ExternalPlayerAggregateSourceResult(
                    provider.Source,
                    info.Name,
                    result.Status,
                    IsActive: true,
                    result.Message,
                    result.Players.Count),
                result.Players);
        })).ConfigureAwait(false);

        var merged = MergeProfiles(perSource.SelectMany(outcome => outcome.Players));
        var sources = perSource.Select(outcome => outcome.Summary).ToArray();
        var activeSources = sources.Where(source => source.IsActive).Select(source => source.SourceName).ToArray();
        var preparedSources = sources.Where(source => !source.IsActive).Select(source => source.SourceName).ToArray();

        var message = BuildAggregateMessage(merged.Count, isId, activeSources, preparedSources);

        return new ExternalPlayerAggregateResult
        {
            Query = normalized,
            Mode = mode,
            Message = message,
            Players = merged,
            Sources = sources
        };
    }

    private static string BuildAggregateMessage(int hitCount, bool isId, IReadOnlyList<string> activeSources, IReadOnlyList<string> preparedSources)
    {
        var parts = new List<string>();
        if (activeSources.Count > 0)
        {
            parts.Add(hitCount > 0
                ? $"{hitCount} Treffer aus: {string.Join(", ", activeSources)}."
                : $"Durchsucht: {string.Join(", ", activeSources)} – keine Treffer.");
        }
        else
        {
            parts.Add(isId
                ? "Keine aktive Quelle für ID-Abfrage verfügbar."
                : "Namenssuche ist in diesem Stand bei keiner Quelle aktiv. Bitte eine FIDE-ID eingeben (z. B. 4610563).");
        }

        if (preparedSources.Count > 0)
        {
            parts.Add($"Vorbereitet, aktuell nicht aktiv: {string.Join(", ", preparedSources)}.");
        }

        return string.Join(" ", parts);
    }

    private static bool IsIdQuery(string normalized) => normalized.Length > 0 && normalized.All(char.IsDigit);

    private static IReadOnlyList<ExternalPlayerProfile> MergeProfiles(IEnumerable<ExternalPlayerProfile> profiles)
    {
        var merged = new List<ExternalPlayerProfile>();
        foreach (var profile in profiles)
        {
            var existing = merged.FindIndex(candidate => IsSamePerson(candidate, profile));
            if (existing < 0)
            {
                merged.Add(profile);
            }
            else
            {
                merged[existing] = Combine(merged[existing], profile);
            }
        }

        return merged;
    }

    private static bool IsSamePerson(ExternalPlayerProfile left, ExternalPlayerProfile right)
    {
        if (!string.IsNullOrWhiteSpace(left.FideId) && string.Equals(left.FideId, right.FideId, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(left.NationalId) && string.Equals(left.NationalId, right.NationalId, StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Konservativ: nur zusammenführen, wenn Name UND Geburtsjahr übereinstimmen.
        return left.BirthYear is not null
            && left.BirthYear == right.BirthYear
            && NameKey(left.Name) == NameKey(right.Name)
            && NameKey(left.Name).Length > 0;
    }

    private static ExternalPlayerProfile Combine(ExternalPlayerProfile primary, ExternalPlayerProfile secondary)
    {
        // FIDE-Profile haben in der Regel die höhere Vertrauenswürdigkeit; ansonsten das stärkere behalten.
        var basis = secondary.Confidence > primary.Confidence ? secondary : primary;
        var other = ReferenceEquals(basis, primary) ? secondary : primary;

        return basis with
        {
            Club = basis.Club ?? other.Club,
            Federation = basis.Federation ?? other.Federation,
            Country = basis.Country ?? other.Country,
            BirthYear = basis.BirthYear ?? other.BirthYear,
            FideId = basis.FideId ?? other.FideId,
            NationalId = basis.NationalId ?? other.NationalId,
            Title = basis.Title ?? other.Title,
            Elo = basis.Elo ?? other.Elo,
            RapidElo = basis.RapidElo ?? other.RapidElo,
            BlitzElo = basis.BlitzElo ?? other.BlitzElo,
            Dwz = basis.Dwz ?? other.Dwz,
            DwzIndex = basis.DwzIndex ?? other.DwzIndex,
            Gender = basis.Gender == GenderCategory.Unknown ? other.Gender : basis.Gender,
            Warnings = basis.Warnings.Concat(other.Warnings).Distinct().ToArray(),
            Notes = string.Join(" ", new[] { basis.Notes, other.Notes }
                .Where(note => !string.IsNullOrWhiteSpace(note))
                .Distinct())
        };
    }

    private static string NameKey(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return string.Empty;
        }

        var normalized = name.Trim().ToLowerInvariant().Replace(",", " ");
        var decomposed = normalized.Normalize(System.Text.NormalizationForm.FormD);
        var builder = new System.Text.StringBuilder(decomposed.Length);
        foreach (var ch in decomposed)
        {
            var category = System.Globalization.CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == System.Globalization.UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (ch is 'ß')
            {
                builder.Append("ss");
            }
            else if (char.IsLetterOrDigit(ch) || char.IsWhiteSpace(ch))
            {
                builder.Append(ch);
            }
        }

        var tokens = builder.ToString()
            .Replace("ae", "a").Replace("oe", "o").Replace("ue", "u")
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .OrderBy(token => token, StringComparer.Ordinal);

        return string.Join(' ', tokens);
    }

    private readonly record struct SourceOutcome(ExternalPlayerAggregateSourceResult Summary, IReadOnlyList<ExternalPlayerProfile> Players);
}
