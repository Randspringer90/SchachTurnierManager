using System.Net;
using System.Text.RegularExpressions;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.External;

public sealed class FidePlayerLookupProvider : IExternalPlayerLookupProvider
{
    private static readonly Uri BaseUri = new("https://ratings.fide.com/");
    private static readonly HttpClient HttpClient = new()
    {
        BaseAddress = BaseUri,
        Timeout = TimeSpan.FromSeconds(12)
    };

    static FidePlayerLookupProvider()
    {
        HttpClient.DefaultRequestHeaders.UserAgent.ParseAdd("SchachTurnierManager/0.10 (+https://github.com/Randspringer90/SchachTurnierManager)");
    }

    public ExternalPlayerSource Source => ExternalPlayerSource.Fide;

    public ExternalPlayerProviderInfo Info { get; } = new(
        ExternalPlayerSource.Fide,
        "FIDE Ratings",
        SupportsIdLookup: true,
        SupportsNameSearch: false,
        "FIDE-Profilabruf per FIDE-ID. Namenssuche ist im ersten Schritt bewusst noch nicht automatisiert, weil dafür eine stabile offizielle Suchschnittstelle geprüft werden muss.",
        "https://ratings.fide.com/");

    public async Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
    {
        var fideId = NormalizeId(externalId);
        if (fideId.Length == 0)
        {
            return ExternalPlayerLookupResult.Invalid(Source, externalId, "FIDE-ID darf nicht leer sein.");
        }

        if (!fideId.All(char.IsDigit))
        {
            return ExternalPlayerLookupResult.Invalid(Source, externalId, "FIDE-ID darf nur Ziffern enthalten.");
        }

        var profilePath = $"profile/{fideId}";
        var profileUrl = new Uri(BaseUri, profilePath).ToString();
        string html;
        try
        {
            html = await HttpClient.GetStringAsync(profilePath, cancellationToken).ConfigureAwait(false);
        }
        catch (HttpRequestException ex)
        {
            return ExternalPlayerLookupResult.Unavailable(Source, fideId, $"FIDE-Profil konnte nicht geladen werden: {ex.Message}");
        }
        catch (TaskCanceledException)
        {
            return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Profil konnte nicht geladen werden: Zeitüberschreitung.");
        }

        var lines = HtmlToLines(html);
        var player = ParseProfile(lines, fideId, profileUrl);
        return player is null
            ? ExternalPlayerLookupResult.Empty(Source, fideId, $"Kein FIDE-Profil für ID {fideId} gefunden oder Profilformat nicht erkannt.")
            : ExternalPlayerLookupResult.Found(Source, fideId, player);
    }

    public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
    {
        return Task.FromResult(ExternalPlayerLookupResult.Unsupported(Source, name,
            "FIDE-Namenssuche ist vorbereitet, aber in diesem Stand noch nicht aktiviert. Bitte zunächst eine FIDE-ID eingeben, z. B. 4610563."));
    }

    private static string NormalizeId(string value) => new(value.Where(char.IsDigit).ToArray());

    private static ExternalPlayerProfile? ParseProfile(IReadOnlyList<string> lines, string fideId, string profileUrl)
    {
        var fideIdIndex = FindLabelIndex(lines, "FIDE ID");
        if (fideIdIndex < 0)
        {
            return null;
        }

        var pageId = NextValue(lines, fideIdIndex);
        if (!string.Equals(NormalizeId(pageId ?? string.Empty), fideId, StringComparison.Ordinal))
        {
            return null;
        }

        var name = FindName(lines, fideIdIndex);
        if (string.IsNullOrWhiteSpace(name))
        {
            return null;
        }

        var federation = ValueAfterLabel(lines, "Federation");
        var title = NormalizeNone(ValueAfterLabel(lines, "FIDE title"));
        var gender = ParseGender(ValueAfterLabel(lines, "Gender"));

        return new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = fideId,
            Name = name,
            Federation = federation,
            Country = federation,
            BirthYear = ParseInt(ValueAfterLabel(lines, "B-Year")),
            Gender = gender,
            FideId = fideId,
            Title = title,
            Elo = RatingBeforeLabel(lines, "STANDARD"),
            RapidElo = RatingBeforeLabel(lines, "RAPID"),
            BlitzElo = RatingBeforeLabel(lines, "BLITZ"),
            ProfileUrl = profileUrl,
            RetrievedAt = DateTimeOffset.UtcNow,
            Confidence = 0.95,
            Notes = "Aus FIDE-Ratings-Profil importiert. Bitte vor Turnierstart gegen offizielle Turnierunterlagen prüfen."
        };
    }

    private static IReadOnlyList<string> HtmlToLines(string html)
    {
        var withoutScripts = Regex.Replace(html, "<script[^>]*>.*?</script>", "\n", RegexOptions.IgnoreCase | RegexOptions.Singleline);
        withoutScripts = Regex.Replace(withoutScripts, "<style[^>]*>.*?</style>", "\n", RegexOptions.IgnoreCase | RegexOptions.Singleline);
        var text = Regex.Replace(withoutScripts, "<[^>]+>", "\n", RegexOptions.Singleline);
        text = WebUtility.HtmlDecode(text);
        return text.Split('\n')
            .Select(line => Regex.Replace(line, "\\s+", " ").Trim())
            .Where(line => line.Length > 0)
            .ToArray();
    }

    private static int FindLabelIndex(IReadOnlyList<string> lines, string label)
    {
        for (var index = 0; index < lines.Count; index++)
        {
            if (string.Equals(lines[index], label, StringComparison.OrdinalIgnoreCase))
            {
                return index;
            }
        }

        return -1;
    }

    private static string? ValueAfterLabel(IReadOnlyList<string> lines, string label)
    {
        var index = FindLabelIndex(lines, label);
        return index < 0 ? null : NextValue(lines, index);
    }

    private static string? NextValue(IReadOnlyList<string> lines, int labelIndex)
    {
        for (var index = labelIndex + 1; index < lines.Count; index++)
        {
            var value = lines[index].Trim();
            if (value.Length == 0 || value.Equals("Image", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return value;
        }

        return null;
    }

    private static string? FindName(IReadOnlyList<string> lines, int fideIdIndex)
    {
        for (var index = fideIdIndex - 1; index >= 0; index--)
        {
            var candidate = NormalizeNone(lines[index]);
            if (candidate is null || candidate.Length > 120)
            {
                continue;
            }

            if (candidate.Contains(',') || candidate.Any(char.IsLetter) && !KnownNonName(candidate))
            {
                return candidate;
            }
        }

        return null;
    }

    private static bool KnownNonName(string candidate)
    {
        var normalized = candidate.ToUpperInvariant();
        return normalized is "STANDARD" or "RAPID" or "BLITZ" or "NOT RATED" or "FIDE ID" or "FEDERATION" or "B-YEAR" or "GENDER" or "FIDE TITLE";
    }

    private static int? RatingBeforeLabel(IReadOnlyList<string> lines, string label)
    {
        var index = FindLabelIndex(lines, label);
        if (index <= 0)
        {
            return null;
        }

        for (var cursor = index - 1; cursor >= 0; cursor--)
        {
            var value = NormalizeNone(lines[cursor]);
            if (value is null)
            {
                return null;
            }

            if (int.TryParse(value, out var rating) && rating > 0)
            {
                return rating;
            }

            if (!value.Equals("Image", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }
        }

        return null;
    }

    private static int? ParseInt(string? value)
    {
        return int.TryParse(value, out var parsed) ? parsed : null;
    }

    private static GenderCategory ParseGender(string? value)
    {
        return value?.Trim().ToLowerInvariant() switch
        {
            "male" or "m" or "männlich" => GenderCategory.Male,
            "female" or "f" or "weiblich" => GenderCategory.Female,
            _ => GenderCategory.Unknown
        };
    }

    private static string? NormalizeNone(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        return trimmed.Equals("None", StringComparison.OrdinalIgnoreCase) || trimmed.Equals("Not rated", StringComparison.OrdinalIgnoreCase)
            ? null
            : trimmed;
    }
}
