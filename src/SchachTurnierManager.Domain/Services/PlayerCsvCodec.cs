using System.Globalization;
using System.Text;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public static class PlayerCsvCodec
{
    private static readonly string[] Header =
    {
        "Name",
        "Verein",
        "Geburtsjahr",
        "Geschlecht",
        "DWZ",
        "DWZIndex",
        "Elo",
        "TWZ",
        "FIDE-ID",
        "DSB-ID",
        "Titel",
        "Status",
        "Notizen"
    };

    public static string ExportPlayers(IEnumerable<Player> players)
    {
        var builder = new StringBuilder();
        builder.AppendLine(string.Join(';', Header));
        foreach (var player in players.OrderBy(p => p.StartingRank).ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase))
        {
            var values = new[]
            {
                player.Name,
                player.Club,
                player.BirthYear?.ToString(CultureInfo.InvariantCulture),
                player.Gender.ToString(),
                player.Rating.Dwz?.ToString(CultureInfo.InvariantCulture),
                player.Rating.DwzIndex?.ToString(CultureInfo.InvariantCulture),
                player.Rating.Elo?.ToString(CultureInfo.InvariantCulture),
                player.Rating.ManualTwz?.ToString(CultureInfo.InvariantCulture),
                player.FideId,
                player.NationalId,
                player.Title,
                player.Status.ToString(),
                player.Notes
            };
            builder.AppendLine(string.Join(';', values.Select(Escape)));
        }

        return builder.ToString();
    }

    public static IReadOnlyList<Player> ImportPlayers(string csv)
    {
        if (string.IsNullOrWhiteSpace(csv))
        {
            return Array.Empty<Player>();
        }

        var lines = csv.Replace("\r\n", "\n").Replace('\r', '\n')
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (lines.Length == 0)
        {
            return Array.Empty<Player>();
        }

        var startIndex = LooksLikeHeader(ParseLine(lines[0])) ? 1 : 0;
        var players = new List<Player>();
        for (var i = startIndex; i < lines.Length; i++)
        {
            var values = ParseLine(lines[i]);
            if (values.Count == 0 || string.IsNullOrWhiteSpace(Get(values, 0)))
            {
                continue;
            }

            players.Add(new Player
            {
                Name = Get(values, 0).Trim(),
                Club = NullIfWhiteSpace(Get(values, 1)),
                BirthYear = ParseNullableInt(Get(values, 2)),
                Gender = ParseGender(Get(values, 3)),
                Rating = new RatingProfile
                {
                    Dwz = ParseNullableInt(Get(values, 4)),
                    DwzIndex = ParseNullableInt(Get(values, 5)),
                    Elo = ParseNullableInt(Get(values, 6)),
                    ManualTwz = ParseNullableInt(Get(values, 7))
                },
                FideId = NullIfWhiteSpace(Get(values, 8)),
                NationalId = NullIfWhiteSpace(Get(values, 9)),
                Title = NullIfWhiteSpace(Get(values, 10)),
                Status = ParseStatus(Get(values, 11)),
                Notes = NullIfWhiteSpace(Get(values, 12))
            });
        }

        return players;
    }

    private static bool LooksLikeHeader(IReadOnlyList<string> values)
    {
        return values.Count > 0 && string.Equals(values[0], "Name", StringComparison.OrdinalIgnoreCase);
    }

    private static string Get(IReadOnlyList<string> values, int index) => index < values.Count ? values[index] : string.Empty;

    private static string? NullIfWhiteSpace(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static int? ParseNullableInt(string value)
    {
        return int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed) ? parsed : null;
    }

    private static GenderCategory ParseGender(string value)
    {
        if (Enum.TryParse<GenderCategory>(value, ignoreCase: true, out var parsed))
        {
            return parsed;
        }

        return value.Trim().ToLowerInvariant() switch
        {
            "w" or "weiblich" or "frau" or "female" or "f" => GenderCategory.Female,
            "m" or "männlich" or "maennlich" or "male" => GenderCategory.Male,
            "d" or "divers" or "diverse" => GenderCategory.Diverse,
            _ => GenderCategory.Unknown
        };
    }

    private static PlayerStatus ParseStatus(string value)
    {
        return Enum.TryParse<PlayerStatus>(value, ignoreCase: true, out var parsed) ? parsed : PlayerStatus.Active;
    }

    private static string Escape(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var mustQuote = value.Contains(';') || value.Contains('"') || value.Contains('\n') || value.Contains('\r');
        var escaped = value.Replace("\"", "\"\"");
        return mustQuote ? $"\"{escaped}\"" : escaped;
    }

    private static IReadOnlyList<string> ParseLine(string line)
    {
        var values = new List<string>();
        var current = new StringBuilder();
        var inQuotes = false;

        for (var i = 0; i < line.Length; i++)
        {
            var ch = line[i];
            if (ch == '"')
            {
                if (inQuotes && i + 1 < line.Length && line[i + 1] == '"')
                {
                    current.Append('"');
                    i++;
                }
                else
                {
                    inQuotes = !inQuotes;
                }
            }
            else if (ch == ';' && !inQuotes)
            {
                values.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.Append(ch);
            }
        }

        values.Add(current.ToString());
        return values;
    }
}
