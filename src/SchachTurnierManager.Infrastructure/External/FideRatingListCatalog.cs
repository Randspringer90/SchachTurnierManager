using System.Globalization;
using System.Runtime.CompilerServices;
using System.Text;
using System.Text.RegularExpressions;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Infrastructure.External;

/// <summary>Bounded, transactional local standard-rating TXT cache. No HTTP client or network fallback.</summary>
public sealed class FideRatingListCatalog(string directory) : IFideRatingListCatalog
{
    public const long MaximumBytes = 256L * 1024 * 1024;
    private const int MaximumRows = 2_000_000;
    private readonly string _directory = Path.GetFullPath(directory);
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly Dictionary<string, (DateTimeOffset At, ExternalPlayerLookupResult Result)> _queries = new(StringComparer.Ordinal);
    private DateTime _cachedVersion;
    private string CatalogPath => Path.Combine(_directory, "standard-rating-list.txt");
    public FideRatingListInfo Info
    {
        get
        {
            CheckPath();
            var file = new FileInfo(CatalogPath);
            if (!file.Exists) return new(false, null, 0, false);
            var imported = new DateTimeOffset(file.LastWriteTimeUtc, TimeSpan.Zero);
            return new(true, imported, file.Length, DateTimeOffset.UtcNow - imported > TimeSpan.FromHours(24));
        }
    }

    public async Task<FideRatingListImport> ImportAsync(Stream input, CancellationToken cancellationToken = default)
    {
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(TimeSpan.FromSeconds(90));
        cancellationToken = deadline.Token;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        string? temporary = null;
        try
        {
            CheckPath();
            Directory.CreateDirectory(_directory);
            temporary = Path.Combine(_directory, "import-" + Guid.NewGuid().ToString("N") + ".tmp");
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 65536, FileOptions.Asynchronous))
            {
                var buffer = new byte[65536]; long total = 0;
                int count;
                while ((count = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
                {
                    total += count;
                    if (total > MaximumBytes) throw new InvalidDataException("FIDE-Liste ueberschreitet 256 MiB.");
                    await output.WriteAsync(buffer.AsMemory(0, count), cancellationToken).ConfigureAwait(false);
                }
            }
            Header? header = null; var ids = new HashSet<string>(StringComparer.Ordinal); var rows = 0;
            await foreach (var line in ReadLines(temporary, cancellationToken).ConfigureAwait(false))
            {
                if (header is null) { header = ParseHeader(line); continue; }
                if (string.IsNullOrWhiteSpace(line)) continue;
                if (++rows > MaximumRows) throw new InvalidDataException("Zu viele FIDE-Zeilen.");
                var profile = ParsePlayer(line, header, DateTimeOffset.UtcNow, false);
                if (!ids.Add(profile.ExternalId)) throw new InvalidDataException("Doppelte FIDE-ID in der Liste.");
            }
            if (rows == 0) throw new InvalidDataException("Die Standard-Ratingliste ist leer.");
            cancellationToken.ThrowIfCancellationRequested();
            CheckPath();
            File.Move(temporary, CatalogPath, overwrite: true);
            temporary = null;
            var imported = DateTimeOffset.UtcNow;
            File.SetLastWriteTimeUtc(CatalogPath, imported.UtcDateTime);
            _queries.Clear();
            return new(rows, imported);
        }
        finally
        {
            if (temporary is not null && File.Exists(temporary)) File.Delete(temporary);
            _gate.Release();
        }
    }

    public async Task<ExternalPlayerLookupResult> SearchAsync(string query, string? federation = null, CancellationToken cancellationToken = default)
    {
        query = (query ?? string.Empty).Trim(); federation = (federation ?? string.Empty).Trim().ToUpperInvariant();
        var tokens = PlayerNameNormalizer.Tokenize(query);
        if (query.Length is < 2 or > 100 || tokens.Count is < 1 or > 8 ||
            (federation.Length != 0 && !Regex.IsMatch(federation, "^[A-Z]{3}$", RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(50))))
            return ExternalPlayerLookupResult.Invalid(ExternalPlayerSource.Fide, query, "Name/ID oder Foederation ist ungueltig.");
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(TimeSpan.FromSeconds(10));
        var entered = false;
        try
        {
            await _gate.WaitAsync(deadline.Token).ConfigureAwait(false); entered = true;
            var info = Info;
            if (!info.Available) return ExternalPlayerLookupResult.Unavailable(ExternalPlayerSource.Fide, query, "Offline: zuerst eine offizielle entpackte FIDE-Standard-TXT-Liste lokal laden.");
            if (info.Bytes > MaximumBytes) throw new InvalidDataException("FIDE-Cache ist zu gross.");
            var version = File.GetLastWriteTimeUtc(CatalogPath);
            if (version != _cachedVersion) { _queries.Clear(); _cachedVersion = version; }
            var key = query + "\n" + federation + "\n" + info.Stale;
            if (_queries.TryGetValue(key, out var cached) && DateTimeOffset.UtcNow - cached.At < TimeSpan.FromHours(24)) return cached.Result;
            var idQuery = query.All(char.IsAsciiDigit);
            var hits = new List<ExternalPlayerProfile>(); Header? header = null; var rows = 0;
            await foreach (var line in ReadLines(CatalogPath, deadline.Token).ConfigureAwait(false))
            {
                if (header is null) { header = ParseHeader(line); continue; }
                if (string.IsNullOrWhiteSpace(line)) continue;
                if (++rows > MaximumRows) throw new InvalidDataException("Zu viele FIDE-Zeilen.");
                var profile = ParsePlayer(line, header, info.ImportedAt!.Value, info.Stale);
                if (federation.Length != 0 && profile.Federation != federation) continue;
                var nameTokens = idQuery ? [] : PlayerNameNormalizer.Tokenize(profile.Name);
                if (idQuery ? profile.FideId == query : tokens.All(nameTokens.Contains)) hits.Add(profile);
                if (hits.Count == 50) break;
            }
            var result = ExternalPlayerLookupResult.Found(ExternalPlayerSource.Fide, query, hits.ToArray()) with
            {
                Status = hits.Count == 0 ? ExternalPlayerLookupStatus.NotFound : ExternalPlayerLookupStatus.Found,
                Message = $"{hits.Count} lokale FIDE-Treffer (maximal 50). Listenimport: {info.ImportedAt:yyyy-MM-dd HH:mm} UTC. " +
                    (info.Stale ? "Liste aelter als 24 Stunden; vor Uebernahme Aktualitaet pruefen." : "Keine Onlineabfrage; Werte vor Uebernahme pruefen.")
            };
            if (_queries.Count >= 100) _queries.Clear();
            _queries[key] = (DateTimeOffset.UtcNow, result);
            return result;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return ExternalPlayerLookupResult.Unavailable(ExternalPlayerSource.Fide, query, "Lokale FIDE-Suche nach 10 Sekunden abgebrochen.");
        }
        catch (Exception error) when (error is IOException or InvalidDataException or UnauthorizedAccessException or DecoderFallbackException)
        {
            return ExternalPlayerLookupResult.Unavailable(ExternalPlayerSource.Fide, query, "Lokale FIDE-Liste konnte nicht sicher gelesen werden. Liste erneut importieren.");
        }
        finally { if (entered) _gate.Release(); }
    }

    private void CheckPath()
    {
        var cursor = CatalogPath;
        while (!string.IsNullOrEmpty(cursor))
        {
            if ((File.Exists(cursor) || Directory.Exists(cursor)) && (File.GetAttributes(cursor) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("FIDE-Cache darf keine Reparse-Pfadkomponente haben.");
            cursor = Path.GetDirectoryName(cursor);
        }
    }

    private static async IAsyncEnumerable<string> ReadLines(string file, [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.Read, 65536, FileOptions.Asynchronous);
        if (stream.Length > MaximumBytes) throw new InvalidDataException("FIDE-Liste ist zu gross.");
        using var reader = new StreamReader(stream, new UTF8Encoding(false, true), detectEncodingFromByteOrderMarks: false);
        var buffer = new char[4096]; var line = new StringBuilder(1024); var first = true;
        int read;
        while ((read = await reader.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
        {
            for (var i = 0; i < read; i++)
            {
                cancellationToken.ThrowIfCancellationRequested(); var character = buffer[i];
                if (first) { first = false; if (character == '\uFEFF') continue; }
                if (character == '\n') { yield return line.ToString().TrimEnd('\r'); line.Clear(); }
                else { if (line.Length >= 1024) throw new InvalidDataException("FIDE-Zeile ist zu lang."); line.Append(character); }
            }
        }
        if (line.Length > 0) yield return line.ToString().TrimEnd('\r');
    }

    private sealed record Header(Dictionary<string, (int Start, int End)> Columns, string Rating);
    private static Header ParseHeader(string line)
    {
        var matches = Regex.Matches(line, "ID Number|[A-Za-z][A-Za-z0-9-]*", RegexOptions.CultureInvariant, TimeSpan.FromMilliseconds(50));
        if (matches.Count == 0 || matches[0].Index != 0 || matches[0].Value != "ID Number") throw new InvalidDataException("Keine unterstuetzte FIDE-Standard-TXT-Kopfzeile.");
        var columns = new Dictionary<string, (int, int)>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < matches.Count; i++)
        {
            var end = i + 1 < matches.Count ? matches[i + 1].Index : line.Length;
            if (line.AsSpan(matches[i].Index + matches[i].Length, end - matches[i].Index - matches[i].Length).IndexOfAnyExcept(' ') >= 0 ||
                !columns.TryAdd(matches[i].Value, (matches[i].Index, end))) throw new InvalidDataException("Mehrdeutige FIDE-Kopfzeile.");
        }
        var rating = columns.ContainsKey("SRtng") ? "SRtng" : "STD";
        if (columns.ContainsKey("SRtng") && columns.ContainsKey("STD")) throw new InvalidDataException("Mehrdeutige Ratingquelle.");
        foreach (var key in new[] { "ID Number", "Name", "Fed", rating })
            if (!columns.TryGetValue(key, out var range) || range.Item2 == line.Length) throw new InvalidDataException("Standard-Rating-Spalte fehlt.");
        return new(columns, rating);
    }

    private static ExternalPlayerProfile ParsePlayer(string line, Header header, DateTimeOffset imported, bool stale)
    {
        if (line.Any(char.IsControl)) throw new InvalidDataException("Steuerzeichen in FIDE-Zeile.");
        var characters = line.EnumerateRunes().ToArray();
        string Field(string key)
        {
            if (!header.Columns.TryGetValue(key, out var range)) return string.Empty;
            if (characters.Length < range.End && key is "ID Number" or "Name" or "Fed" || characters.Length < range.End && key == header.Rating)
                throw new InvalidDataException("Unvollstaendige FIDE-Zeile.");
            return string.Concat(characters.Skip(range.Start).Take(Math.Min(range.End, characters.Length) - range.Start).Select(r => r.ToString())).Trim();
        }
        var id = Field("ID Number"); var name = Field("Name"); var federation = Field("Fed"); var ratingText = Field(header.Rating);
        if (id.Length is < 1 or > 12 || id[0] == '0' || !id.All(char.IsAsciiDigit) || name.Length is < 1 or > 150 ||
            federation.Length != 3 || !federation.All(c => c is >= 'A' and <= 'Z') || ratingText.Length is < 1 or > 4 ||
            !ratingText.All(char.IsAsciiDigit) || !int.TryParse(ratingText, NumberStyles.None, CultureInfo.InvariantCulture, out var rating) || rating > 4000)
            throw new InvalidDataException("Ungueltige FIDE-Datenzeile.");
        var title = Field("Tit").ToLowerInvariant();
        var mappedTitle = title switch { "g" => "GM", "m" => "IM", "f" => "FM", "c" => "CM", "wg" => "WGM", "wm" => "WIM", "wf" => "WFM", "wc" => "WCM", _ => title.ToUpperInvariant() };
        if (mappedTitle is not ("GM" or "IM" or "FM" or "CM" or "WGM" or "WIM" or "WFM" or "WCM")) mappedTitle = string.Empty;
        return new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide, ExternalId = id, FideId = id, Name = name, Federation = federation,
            Elo = rating == 0 ? null : rating, Title = mappedTitle.Length == 0 ? null : mappedTitle,
            ProfileUrl = "https://ratings.fide.com/profile/" + id, RetrievedAt = imported, Confidence = 0.9,
            Notes = "Vom Nutzer lokal importierte offizielle FIDE-Standard-TXT-Liste; Quelle und Listenstand pruefen.",
            Warnings = stale ? ["Listenimport aelter als 24 Stunden; offline weiter nutzbar."] : []
        };
    }
}
