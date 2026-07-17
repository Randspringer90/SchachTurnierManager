using System.Globalization;
using System.Text;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// STM-IE-002: Spieler-Stammdaten im Swiss-Manager-Importlayout (Anhang C "Using spreadsheets"
/// des offiziellen Swiss-Manager User's Guide). Swiss-Manager erkennt Felder an exakten
/// Spaltenueberschriften, nicht an der Position - "Arrange the columns in any order [...], but
/// make sure their labels are written exactly like this". Als Textdatei ist Komma das
/// dokumentierte Trennzeichen (nicht Semikolon wie unser internes Format).
///
/// Bewusste Scope-Entscheidungen:
/// - Export nutzt die kombinierte "Name"-Spalte ("Nachname Vorname in einer Zelle"), die
///   Swiss-Manager laut Handbuch selbst trennt - passend zu unserem Domainmodell, das Vor-/
///   Nachname nicht getrennt speichert (gleiche Entscheidung wie beim TRF16-Export, STM-IE-001).
/// - Import akzeptiert zusaetzlich die getrennten Spalten "surname"/"first name", falls eine
///   echte Swiss-Manager-Exportdatei eingelesen wird (grosszuegig beim Lesen, konsistent beim
///   Schreiben).
/// - "Birth" enthaelt nur das Geburtsjahr (PII-Minimierung, gleiche Entscheidung wie TRF16);
///   volle Datumswerte im Import (JJJJ/MM/TT oder TT.MM.JJJJ) werden auf das Jahr reduziert.
/// - "Type"/"Gr"/"Clubno"/Team-Felder (Captain/Board) sind Mannschafts-/Verwaltungsfelder ohne
///   Entsprechung in unserem Einzelspieler-Stammdatenmodell und werden nicht bedient.
/// </summary>
public static class SwissManagerCsvCodec
{
    private const char Separator = ',';

    private static readonly string[] ExportHeader =
    {
        "No", "Name", "Title", "FIDE-No", "ID no", "Rating nat", "Rating int", "Birth", "Fed", "Sex", "Club"
    };

    public static string ExportPlayers(IEnumerable<Player> players)
    {
        var builder = new StringBuilder();
        builder.Append(string.Join(Separator, ExportHeader)).Append('\n');
        foreach (var player in players.OrderBy(p => p.StartingRank).ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase))
        {
            var values = new[]
            {
                player.StartingRank > 0 ? player.StartingRank.ToString(CultureInfo.InvariantCulture) : string.Empty,
                player.Name,
                player.Title,
                player.FideId,
                player.NationalId,
                player.Rating.Dwz?.ToString(CultureInfo.InvariantCulture),
                player.Rating.Elo?.ToString(CultureInfo.InvariantCulture),
                player.BirthYear?.ToString(CultureInfo.InvariantCulture),
                player.Federation,
                SexLabel(player.Gender),
                player.Club
            };
            builder.Append(string.Join(Separator, values.Select(Escape))).Append('\n');
        }

        return builder.ToString();
    }

    public static SwissManagerImportResult ImportPlayers(string csv)
    {
        if (string.IsNullOrWhiteSpace(csv))
        {
            return new SwissManagerImportResult(Array.Empty<Player>(), Array.Empty<string>());
        }

        var lines = csv.Replace("\r\n", "\n").Replace('\r', '\n')
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (lines.Length == 0)
        {
            return new SwissManagerImportResult(Array.Empty<Player>(), Array.Empty<string>());
        }

        var header = ParseLine(lines[0]);
        var columns = BuildColumnMap(header);
        var errors = new List<string>();
        if (!columns.ContainsKey("name") && !columns.ContainsKey("surname"))
        {
            errors.Add("Kopfzeile: weder 'Name' noch 'surname' gefunden - Datei kann nicht als Swiss-Manager-Spielerliste gelesen werden.");
            return new SwissManagerImportResult(Array.Empty<Player>(), errors);
        }

        var players = new List<Player>();
        for (var lineIndex = 1; lineIndex < lines.Length; lineIndex++)
        {
            var oneBasedLineNumber = lineIndex + 1;
            var values = ParseLine(lines[lineIndex]);

            var name = ResolveName(values, columns);
            if (string.IsNullOrWhiteSpace(name))
            {
                errors.Add($"Zeile {oneBasedLineNumber}: kein Name gefunden, Zeile uebersprungen.");
                continue;
            }

            var startingRank = 0;
            var noText = Field(values, columns, "no");
            if (!string.IsNullOrWhiteSpace(noText) && !int.TryParse(noText, NumberStyles.Integer, CultureInfo.InvariantCulture, out startingRank))
            {
                errors.Add($"Zeile {oneBasedLineNumber}: Startrang '{noText}' ist keine Zahl, wird ignoriert.");
                startingRank = 0;
            }

            players.Add(new Player
            {
                StartingRank = startingRank,
                Name = name.Trim(),
                Title = NullIfWhiteSpace(Field(values, columns, "title")),
                FideId = NullIfWhiteSpace(Field(values, columns, "fide-no")),
                NationalId = NullIfWhiteSpace(Field(values, columns, "id no")),
                Federation = NullIfWhiteSpace(Field(values, columns, "fed")),
                Club = NullIfWhiteSpace(Field(values, columns, "club")),
                Gender = ParseSex(Field(values, columns, "sex")),
                BirthYear = ParseBirthYear(Field(values, columns, "birth")),
                Rating = new RatingProfile
                {
                    Dwz = ParseNullableInt(Field(values, columns, "rating nat"), oneBasedLineNumber, "Rating nat", errors),
                    Elo = ParseNullableInt(Field(values, columns, "rating int"), oneBasedLineNumber, "Rating int", errors)
                }
            });
        }

        return new SwissManagerImportResult(players, errors);
    }

    private static string ResolveName(IReadOnlyList<string> values, IReadOnlyDictionary<string, int> columns)
    {
        var combined = Field(values, columns, "name");
        if (!string.IsNullOrWhiteSpace(combined))
        {
            return combined;
        }

        var surname = Field(values, columns, "surname");
        var firstName = Field(values, columns, "first name");
        return string.Join(' ', new[] { surname, firstName }.Where(part => !string.IsNullOrWhiteSpace(part))).Trim();
    }

    private static Dictionary<string, int> BuildColumnMap(IReadOnlyList<string> header)
    {
        var map = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        for (var i = 0; i < header.Count; i++)
        {
            var key = header[i].Trim().ToLowerInvariant();
            if (!string.IsNullOrEmpty(key) && !map.ContainsKey(key))
            {
                map[key] = i;
            }
        }

        return map;
    }

    private static string Field(IReadOnlyList<string> values, IReadOnlyDictionary<string, int> columns, string columnKey)
    {
        return columns.TryGetValue(columnKey, out var index) && index < values.Count ? values[index].Trim() : string.Empty;
    }

    private static int? ParseNullableInt(string value, int lineNumber, string fieldLabel, List<string> errors)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var parsed))
        {
            return parsed;
        }

        errors.Add($"Zeile {lineNumber}: '{fieldLabel}' Wert '{value}' ist keine Zahl, wird ignoriert.");
        return null;
    }

    /// <summary>
    /// Akzeptiert reines Jahr (JJJJ), TRF-Datum (JJJJ/MM/TT) und deutsches Datum (TT.MM.JJJJ);
    /// reduziert in jedem Fall auf das Jahr (PII-Minimierung, siehe Klassenkommentar).
    /// </summary>
    private static int? ParseBirthYear(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        if (value.Length == 4 && int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var bareYear))
        {
            return IsPlausibleYear(bareYear) ? bareYear : null;
        }

        if (value.Contains('/'))
        {
            var part = value.Split('/')[0];
            if (int.TryParse(part, NumberStyles.Integer, CultureInfo.InvariantCulture, out var trfYear) && IsPlausibleYear(trfYear))
            {
                return trfYear;
            }
        }

        if (value.Contains('.'))
        {
            var segments = value.Split('.');
            var part = segments[^1];
            if (int.TryParse(part, NumberStyles.Integer, CultureInfo.InvariantCulture, out var germanYear) && IsPlausibleYear(germanYear))
            {
                return germanYear;
            }
        }

        return null;
    }

    private static bool IsPlausibleYear(int year) => year is >= 1900 and <= 2100;

    private static string SexLabel(GenderCategory gender) => gender switch
    {
        GenderCategory.Male => "m",
        GenderCategory.Female => "w",
        _ => string.Empty
    };

    private static GenderCategory ParseSex(string value)
    {
        return value.Trim().ToLowerInvariant() switch
        {
            "w" or "weiblich" or "female" or "f" => GenderCategory.Female,
            "m" or "männlich" or "maennlich" or "male" => GenderCategory.Male,
            "d" or "divers" or "diverse" => GenderCategory.Diverse,
            _ => GenderCategory.Unknown
        };
    }

    private static string? NullIfWhiteSpace(string value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string Escape(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var mustQuote = value.Contains(Separator) || value.Contains('"') || value.Contains('\n') || value.Contains('\r');
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
            else if (ch == Separator && !inQuotes)
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

public sealed record SwissManagerImportResult(IReadOnlyList<Player> Players, IReadOnlyList<string> Errors);
