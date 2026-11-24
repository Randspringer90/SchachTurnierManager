using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.External;

public sealed class FidePlayerLookupProvider : IExternalPlayerLookupProvider
{
    private static readonly Uri BaseUri = new("https://ratings.fide.com/");
    private readonly HttpClient _httpClient;
    private readonly IFideRatingListCatalog? _catalog;
    private readonly SemaphoreSlim _httpGate = new(1, 1);
    private readonly Dictionary<string, (DateTimeOffset At, ExternalPlayerLookupResult Result)> _profiles = new(StringComparer.Ordinal);
    private DateTimeOffset _nextRequestAt;
    private DateTimeOffset _backoffUntil;

    public FidePlayerLookupProvider()
        : this(CreateDefaultHttpClient())
    {
    }

    public FidePlayerLookupProvider(IFideRatingListCatalog catalog)
        : this(CreateDefaultHttpClient(), catalog)
    {
    }

    public FidePlayerLookupProvider(HttpClient httpClient, IFideRatingListCatalog? catalog = null)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _catalog = catalog;
        _httpClient.BaseAddress ??= BaseUri;
        if (!_httpClient.DefaultRequestHeaders.UserAgent.Any())
        {
            _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("SchachTurnierManager/0.11 (+https://github.com/Randspringer90/SchachTurnierManager)");
        }
    }

    private static HttpClient CreateDefaultHttpClient()
    {
        return new HttpClient(new HttpClientHandler { AllowAutoRedirect = false, UseCookies = false })
        {
            BaseAddress = BaseUri,
            Timeout = TimeSpan.FromSeconds(12)
        };
    }

    public ExternalPlayerSource Source => ExternalPlayerSource.Fide;

    public ExternalPlayerProviderInfo Info => new(
        ExternalPlayerSource.Fide,
        "FIDE Ratings",
        SupportsIdLookup: true,
        SupportsNameSearch: _catalog is not null,
        "FIDE-Profilabruf per FIDE-ID; Namenssuche gegen eine ausdruecklich lokal geladene offizielle Standard-TXT-Liste. Keine Namensanfragen an Dritte.",
        "https://ratings.fide.com/");

    public async Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
    {
        var fideId = NormalizeId(externalId);
        if (fideId.Length == 0)
        {
            return ExternalPlayerLookupResult.Invalid(Source, externalId, "FIDE-ID darf nicht leer sein.");
        }

        if (fideId.Length > 12 || fideId[0] == '0' || !fideId.All(char.IsAsciiDigit))
        {
            return ExternalPlayerLookupResult.Invalid(Source, externalId, "FIDE-ID darf nur Ziffern enthalten.");
        }

        if (_catalog is not null && _catalog.Info.Available)
        {
            var local = await _catalog.SearchAsync(fideId, cancellationToken: cancellationToken).ConfigureAwait(false);
            if (local.Status == ExternalPlayerLookupStatus.Found) return local;
        }
        var profilePath = $"profile/{fideId}";
        var profileUrl = new Uri(BaseUri, profilePath).ToString();
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(TimeSpan.FromSeconds(10));
        var entered = false;
        try
        {
            await _httpGate.WaitAsync(deadline.Token).ConfigureAwait(false); entered = true;
            if (_profiles.TryGetValue(fideId, out var cached) && DateTimeOffset.UtcNow - cached.At < TimeSpan.FromHours(24)) return cached.Result;
            if (DateTimeOffset.UtcNow < _backoffUntil) return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Abfrage pausiert nach Rate-Limit oder Serverfehler. Spaeter erneut versuchen; lokale Liste bleibt nutzbar.");
            var delay = _nextRequestAt - DateTimeOffset.UtcNow;
            if (delay > TimeSpan.Zero) await Task.Delay(delay, deadline.Token).ConfigureAwait(false);
            _nextRequestAt = DateTimeOffset.UtcNow.AddSeconds(1);
            using var response = await _httpClient.GetAsync(profilePath, HttpCompletionOption.ResponseHeadersRead, deadline.Token).ConfigureAwait(false);
            if (response.StatusCode == HttpStatusCode.TooManyRequests || (int)response.StatusCode >= 500)
            {
                var retry = response.Headers.RetryAfter?.Delta ?? (response.Headers.RetryAfter?.Date - DateTimeOffset.UtcNow) ?? TimeSpan.FromSeconds(30);
                _backoffUntil = DateTimeOffset.UtcNow + TimeSpan.FromSeconds(Math.Clamp(retry.TotalSeconds, 5, 300));
                return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE meldet ein Rate-Limit oder einen Serverfehler. Weitere Anfragen sind voruebergehend pausiert.");
            }
            if (response.StatusCode == HttpStatusCode.NotFound) return ExternalPlayerLookupResult.Empty(Source, fideId, "Kein FIDE-Profil gefunden.");
            if (!response.IsSuccessStatusCode) return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Profilabruf wurde abgewiesen. Lokale Liste verwenden oder spaeter erneut versuchen.");
            const int maximumBytes = 512 * 1024;
            if (response.Content.Headers.ContentLength > maximumBytes) throw new InvalidDataException("Profile size limit.");
            using var buffer = new MemoryStream();
            await using (var input = await response.Content.ReadAsStreamAsync(deadline.Token).ConfigureAwait(false))
            {
                var chunk = new byte[8192]; int count;
                while ((count = await input.ReadAsync(chunk, deadline.Token).ConfigureAwait(false)) > 0)
                {
                    if (buffer.Length + count > maximumBytes) throw new InvalidDataException("Profile size limit.");
                    buffer.Write(chunk, 0, count);
                }
            }
            var html = new UTF8Encoding(false, true).GetString(buffer.GetBuffer(), 0, checked((int)buffer.Length));
            var lines = HtmlToLines(html);
            var player = ParseProfile(lines, fideId, profileUrl);
            var result = player is null
                ? ExternalPlayerLookupResult.Empty(Source, fideId, "Kein passendes FIDE-Profil gefunden oder Profilformat nicht erkannt.")
                : ExternalPlayerLookupResult.Found(Source, fideId, player);
            if (_profiles.Count >= 1000) _profiles.Clear();
            _profiles[fideId] = (DateTimeOffset.UtcNow, result);
            return result;
        }
        catch (HttpRequestException)
        {
            return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Profil ist nicht erreichbar. Offline mit einer lokal geladenen Liste weitersuchen.");
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Profil konnte nicht geladen werden: Zeitüberschreitung.");
        }
        catch (Exception error) when (error is IOException or InvalidDataException or DecoderFallbackException or RegexMatchTimeoutException)
        {
            return ExternalPlayerLookupResult.Unavailable(Source, fideId, "FIDE-Profil konnte nicht sicher gelesen werden. Format oder Antwortgroesse ist ungueltig.");
        }
        finally { if (entered) _httpGate.Release(); }
    }

    public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
    {
        if (_catalog is not null) return _catalog.SearchAsync(name, cancellationToken: cancellationToken);
        return Task.FromResult(ExternalPlayerLookupResult.Unsupported(Source, name,
            "FIDE-Namenssuche ist vorbereitet, aber in diesem Stand noch nicht aktiviert. Bitte zunächst eine FIDE-ID eingeben, z. B. 99900123."));
    }

    private static string NormalizeId(string? value) => (value ?? string.Empty).Trim();

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
        var regexDeadline = TimeSpan.FromMilliseconds(200);
        var withoutScripts = Regex.Replace(html, "<script[^>]*>.*?</script>", "\n", RegexOptions.IgnoreCase | RegexOptions.Singleline, regexDeadline);
        withoutScripts = Regex.Replace(withoutScripts, "<style[^>]*>.*?</style>", "\n", RegexOptions.IgnoreCase | RegexOptions.Singleline, regexDeadline);
        var text = Regex.Replace(withoutScripts, "<[^>]+>", "\n", RegexOptions.Singleline, regexDeadline);
        text = WebUtility.HtmlDecode(text);
        var rawLines = text.Split('\n');
        if (rawLines.Length > 50000) throw new InvalidDataException("Too many profile lines.");
        return rawLines
            .Select(line => Regex.Replace(line, "\\s+", " ", RegexOptions.None, regexDeadline).Trim())
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
