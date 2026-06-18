using System.Globalization;
using System.Text;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Diakritik- und reihenfolgetolerante Namens-Normalisierung für Spielersuche und Dublettenabgleich.
/// "Marco Geißhirt", "Geißhirt, Marco", "Geisshirt Marco" und "Marco Geishirt" ergeben dieselbe Token-Menge.
/// </summary>
public static class PlayerNameNormalizer
{
    /// <summary>
    /// Liefert die sortierten, normalisierten Namens-Tokens. Reihenfolge (Vorname/Nachname),
    /// Komma, Groß-/Kleinschreibung, Umlaute (ä/ae, ö/oe, ü/ue, ß/ss) und Akzente werden vereinheitlicht.
    /// </summary>
    public static IReadOnlyList<string> Tokenize(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            return Array.Empty<string>();
        }

        var lowered = name.Trim().ToLowerInvariant();
        var expanded = new StringBuilder(lowered.Length + 8);
        foreach (var ch in lowered)
        {
            switch (ch)
            {
                case 'ß':
                    expanded.Append("ss");
                    break;
                case 'ä':
                    expanded.Append("ae");
                    break;
                case 'ö':
                    expanded.Append("oe");
                    break;
                case 'ü':
                    expanded.Append("ue");
                    break;
                default:
                    expanded.Append(ch);
                    break;
            }
        }

        var decomposed = expanded.ToString().Normalize(NormalizationForm.FormD);
        var cleaned = new StringBuilder(decomposed.Length);
        foreach (var ch in decomposed)
        {
            var category = CharUnicodeInfo.GetUnicodeCategory(ch);
            if (category == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            cleaned.Append(char.IsLetterOrDigit(ch) ? ch : ' ');
        }

        return cleaned.ToString()
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(CollapseRepeatedLetters)
            .OrderBy(token => token, StringComparer.Ordinal)
            .ToArray();
    }

    // Vereinheitlicht Doppelbuchstaben, damit "Geißhirt" (ss), "Geisshirt" (ss) und "Geishirt" (s)
    // dieselbe Form ergeben. Symmetrisch auf Such- und Kandidatennamen angewendet.
    private static string CollapseRepeatedLetters(string token)
    {
        var builder = new StringBuilder(token.Length);
        foreach (var ch in token)
        {
            if (builder.Length == 0 || builder[^1] != ch)
            {
                builder.Append(ch);
            }
        }

        return builder.ToString();
    }

    /// <summary>Kanonische, reihenfolgeunabhängige Schreibweise eines Namens (Tokens sortiert, durch Leerzeichen verbunden).</summary>
    public static string Canonical(string? name) => string.Join(' ', Tokenize(name));

    /// <summary>True, wenn beide Namen nach Normalisierung exakt dieselbe Token-Menge ergeben.</summary>
    public static bool AreEquivalent(string? left, string? right)
    {
        var leftTokens = new HashSet<string>(Tokenize(left), StringComparer.Ordinal);
        return leftTokens.Count > 0 && leftTokens.SetEquals(Tokenize(right));
    }

    /// <summary>
    /// True, wenn alle Such-Tokens im Kandidatennamen vorkommen (Teilsuche).
    /// "Marco" findet "Marco Geißhirt"; "Geishirt Marco" findet "Geißhirt, Marco".
    /// </summary>
    public static bool Matches(string? query, string? candidate)
    {
        var queryTokens = Tokenize(query);
        if (queryTokens.Count == 0)
        {
            return false;
        }

        var candidateTokens = new HashSet<string>(Tokenize(candidate), StringComparer.Ordinal);
        return queryTokens.All(candidateTokens.Contains);
    }
}
