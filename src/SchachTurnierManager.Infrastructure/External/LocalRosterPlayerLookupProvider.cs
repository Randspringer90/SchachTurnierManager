using SchachTurnierManager.Application;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Infrastructure.External;

/// <summary>
/// Lokale Datenquelle für die Spielersuche: durchsucht bereits erfasste Turnierteilnehmer
/// und importierte Presetdaten (die als Turniere im lokalen Store liegen). Dadurch lassen sich
/// DWZ/TWZ/DSB-ID ergänzen, auch wenn FIDE diese Werte nicht liefert. Es findet keine externe
/// Online-Abfrage statt – nur die im Projekt vorhandenen lokalen Daten werden genutzt.
/// </summary>
public sealed class LocalRosterPlayerLookupProvider(ITournamentStore store) : IExternalPlayerLookupProvider
{
    // Niedriger als FIDE (0.95), damit beim Zusammenführen FIDE die führende Quelle bleibt,
    // lokale Werte (DWZ/TWZ/DSB-ID) aber ergänzt werden.
    private const double LocalConfidence = 0.6;

    public ExternalPlayerSource Source => ExternalPlayerSource.Local;

    public ExternalPlayerProviderInfo Info { get; } = new(
        ExternalPlayerSource.Local,
        "Lokale Teilnehmer & Importe",
        SupportsIdLookup: true,
        SupportsNameSearch: true,
        "Durchsucht bereits erfasste Turnierteilnehmer und importierte Presetdaten im lokalen Datenbestand. Ergänzt DWZ/TWZ/DSB-ID und markiert bereits vorhandene Personen. Keine externe Online-Abfrage.",
        null);

    public Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
    {
        var normalizedId = NormalizeIdentifier(externalId);
        if (normalizedId is null)
        {
            return Task.FromResult(ExternalPlayerLookupResult.Invalid(Source, externalId, "Lokale ID-Suche benötigt eine FIDE- oder DSB-ID."));
        }

        var matches = LocalPlayers()
            .Where(player => string.Equals(NormalizeIdentifier(player.FideId), normalizedId, StringComparison.Ordinal)
                || string.Equals(NormalizeIdentifier(player.NationalId), normalizedId, StringComparison.Ordinal))
            .ToList();

        return Task.FromResult(BuildResult(externalId, matches,
            $"Keine lokale Person mit ID {externalId} im erfassten Bestand gefunden."));
    }

    public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
    {
        var matches = LocalPlayers()
            .Where(player => PlayerNameNormalizer.Matches(name, player.Name))
            .ToList();

        return Task.FromResult(BuildResult(name, matches,
            $"Keine lokale Person passend zu \"{name}\" im erfassten Bestand gefunden."));
    }

    private ExternalPlayerLookupResult BuildResult(string query, IReadOnlyList<Player> matches, string emptyMessage)
    {
        if (matches.Count == 0)
        {
            return ExternalPlayerLookupResult.Empty(Source, query, emptyMessage);
        }

        var profiles = Deduplicate(matches.Select(ToProfile)).ToArray();
        return ExternalPlayerLookupResult.Found(Source, query, profiles);
    }

    private IReadOnlyList<Player> LocalPlayers()
    {
        return store.List()
            .SelectMany(tournament => tournament.Players)
            .ToList();
    }

    private static IEnumerable<ExternalPlayerProfile> Deduplicate(IEnumerable<ExternalPlayerProfile> profiles)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var profile in profiles)
        {
            var key = NormalizeIdentifier(profile.FideId)
                ?? NormalizeIdentifier(profile.NationalId)
                ?? $"name:{PlayerNameNormalizer.Canonical(profile.Name)}|{profile.BirthYear}";
            if (seen.Add(key))
            {
                yield return profile;
            }
        }
    }

    private static ExternalPlayerProfile ToProfile(Player player)
    {
        var externalId = !string.IsNullOrWhiteSpace(player.FideId)
            ? player.FideId!
            : !string.IsNullOrWhiteSpace(player.NationalId)
                ? player.NationalId!
                : player.Id.ToString();

        return new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Local,
            ExternalId = externalId,
            Name = player.Name,
            Club = player.Club,
            Federation = player.Federation,
            Country = player.Country,
            BirthYear = player.BirthYear,
            Gender = player.Gender,
            FideId = player.FideId,
            NationalId = player.NationalId,
            Title = player.Title,
            Elo = Positive(player.Rating.Elo),
            RapidElo = Positive(player.Rating.RapidElo),
            BlitzElo = Positive(player.Rating.BlitzElo),
            Dwz = Positive(player.Rating.Dwz) ?? Positive(player.Rating.ManualTwz),
            DwzIndex = Positive(player.Rating.DwzIndex),
            RetrievedAt = DateTimeOffset.UtcNow,
            Confidence = LocalConfidence,
            Notes = "Aus lokalem Datenbestand (Turnierteilnehmer/Import) ergänzt."
        };
    }

    private static int? Positive(int? value) => value is > 0 ? value : null;

    private static string? NormalizeIdentifier(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = new string(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());
        return normalized.Length == 0 ? null : normalized;
    }
}
