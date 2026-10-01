using System.Globalization;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Encodes one CSV cell, not a document. Protects formula-like text on initial
/// spreadsheet import; it is not a guarantee after a spreadsheet saves the file.
/// Plain invariant numbers stay numeric. Never use this encoder for TRF or JSON.
/// </summary>
public static class CsvFieldEncoder
{
    public static string Encode(string? value, char separator = ';')
    {
        if (separator is not (';' or ','))
        {
            throw new ArgumentOutOfRangeException(nameof(separator));
        }

        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var protect = NeedsTextPrefix(value);
        var escaped = (protect ? "'" + value : value).Replace("\"", "\"\"");
        var quote = protect || value.Contains(separator) || value.Contains('"')
            || value.Contains('\r') || value.Contains('\n');
        return quote ? $"\"{escaped}\"" : escaped;
    }

    private static bool NeedsTextPrefix(string value)
    {
        // Do not convert legitimate negative rating/score literals to text.
        if (IsPlainInvariantNumber(value))
        {
            return false;
        }

        foreach (var ch in value)
        {
            if (char.IsControl(ch))
            {
                return true;
            }

            if (char.IsWhiteSpace(ch) || char.GetUnicodeCategory(ch) == UnicodeCategory.Format)
            {
                continue;
            }

            return ch is '=' or '+' or '-' or '@' or '\uFF1D' or '\uFF0B' or '\uFF0D' or '\uFF20';
        }

        return false;
    }

    private static bool IsPlainInvariantNumber(string value)
    {
        var start = value[0] == '-' ? 1 : 0;
        var seenDot = false;
        if (start == value.Length)
        {
            return false;
        }

        for (var i = start; i < value.Length; i++)
        {
            if (value[i] is >= '0' and <= '9')
            {
                continue;
            }

            if (value[i] == '.' && !seenDot && i > start && i < value.Length - 1)
            {
                seenDot = true;
                continue;
            }

            return false;
        }

        return true;
    }
}
