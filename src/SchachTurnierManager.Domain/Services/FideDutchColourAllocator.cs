using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>Ergebnis einer Farbzuteilung samt Begründung für den Audit-Trail.</summary>
/// <param name="White">Spieler mit Weiß.</param>
/// <param name="Black">Spieler mit Schwarz.</param>
/// <param name="AppliedRule">Die Fundstelle, die entschieden hat (z. B. "C.04.3 Art. 5.2.1").</param>
/// <param name="Reason">Klartextbegründung für den Turnierleiter (C.04.1 Art. 9: Erklärbarkeit).</param>
public sealed record FideColourAllocation(
    FideDutchPlayerProfile White,
    FideDutchPlayerProfile Black,
    string AppliedRule,
    string Reason);

/// <summary>
/// Farbzuteilung nach FIDE C.04.3 Art. 5 (STM-FACH-002).
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Die fünf Stufen aus Art. 5.2 werden strikt in Reihenfolge geprüft; die erste, die greift,
/// entscheidet. Stufe 5.2.5 kann nie danebengehen — sie ist immer eindeutig. Damit ist die
/// Farbzuteilung total und deterministisch, ohne Zufall (C.04.2 Art. 1.4).
/// </remarks>
public sealed class FideDutchColourAllocator
{
    /// <summary>
    /// Teilt die Farben für ein Paar zu.
    /// </summary>
    /// <param name="first">Ein Spieler des Paares (Reihenfolge egal — das Ergebnis hängt nicht davon ab).</param>
    /// <param name="second">Der andere Spieler.</param>
    /// <param name="initialColour">
    /// Die vor Runde 1 AUSGELOSTE Anfangsfarbe (Art. 5.1). Sie ist Eingabe, kein Zufall: Die Engine
    /// würfelt nie selbst, sonst wäre die Auslosung nicht reproduzierbar.
    /// </param>
    public FideColourAllocation Allocate(
        FideDutchPlayerProfile first,
        FideDutchPlayerProfile second,
        ChessColor initialColour)
    {
        // Reihenfolge normalisieren, damit das Ergebnis nicht von der Aufrufreihenfolge abhaengt:
        // "hoeher gesetzt" heisst nach Art. 1.2 kleinere TPN.
        var (higher, lower) = first.Tpn <= second.Tpn ? (first, second) : (second, first);

        var higherPreference = higher.Preference;
        var lowerPreference = lower.Preference;

        // Art. 5.2.1 - beide Praeferenzen erfuellen. Greift auch, wenn nur einer eine Praeferenz hat.
        if (AreCompatible(higherPreference, lowerPreference))
        {
            var whiteWanted = higherPreference.Colour == ChessColor.White || lowerPreference.Colour == ChessColor.Black;
            return whiteWanted
                ? Result(higher, lower, "C.04.3 Art. 5.2.1",
                    $"Beide Farbwünsche erfüllt: {Describe(higher)}, {Describe(lower)}.")
                : Result(lower, higher, "C.04.3 Art. 5.2.1",
                    $"Beide Farbwünsche erfüllt: {Describe(lower)}, {Describe(higher)}.");
        }

        // Art. 5.2.2 - die STAERKERE Praeferenz erfuellen; sind beide absolut, gewinnt die
        // groessere Farbdifferenz.
        if (higherPreference.Strength != lowerPreference.Strength)
        {
            var stronger = higherPreference.Strength > lowerPreference.Strength ? higher : lower;
            var weaker = ReferenceEquals(stronger, higher) ? lower : higher;
            return Grant(stronger, weaker, "C.04.3 Art. 5.2.2",
                $"Stärkere Präferenz erfüllt: {Describe(stronger)} vor {Describe(weaker)}.");
        }

        if (higherPreference.IsAbsolute && lowerPreference.IsAbsolute)
        {
            var higherDistance = Math.Abs(higher.ColourDifference);
            var lowerDistance = Math.Abs(lower.ColourDifference);
            if (higherDistance != lowerDistance)
            {
                var wider = higherDistance > lowerDistance ? higher : lower;
                var narrower = ReferenceEquals(wider, higher) ? lower : higher;
                return Grant(wider, narrower, "C.04.3 Art. 5.2.2",
                    $"Beide absolut; größere Farbdifferenz erfüllt: {Describe(wider)} ({higherDistance} vs. {lowerDistance}).");
            }
        }

        // Art. 5.2.3 - zur juengsten Runde alternieren, in der einer Weiss und der andere Schwarz hatte.
        var lastDiffering = MostRecentRoundWithDifferentColours(higher, lower);
        if (lastDiffering is { } round)
        {
            // Farben gegenueber jener Runde tauschen.
            var higherThen = higher.ColourByRound[round];
            return higherThen == ChessColor.White
                ? Result(lower, higher, "C.04.3 Art. 5.2.3",
                    $"Farbtausch gegenüber Runde {round}: {Name(higher)} hatte dort Weiß.")
                : Result(higher, lower, "C.04.3 Art. 5.2.3",
                    $"Farbtausch gegenüber Runde {round}: {Name(higher)} hatte dort Schwarz.");
        }

        // Art. 5.2.4 - Praeferenz des hoeher gesetzten Spielers erfuellen.
        if (higherPreference.Strength != FideColourPreferenceStrength.None)
        {
            return Grant(higher, lower, "C.04.3 Art. 5.2.4",
                $"Präferenz des höher gesetzten Spielers erfüllt: {Describe(higher)}.");
        }

        // Art. 5.2.5 - ungerade TPN des hoeher Gesetzten -> Anfangsfarbe, sonst Gegenfarbe.
        // Diese Stufe greift immer und macht die Zuteilung total.
        var isOdd = higher.Tpn % 2 == 1;
        var higherColour = isOdd ? initialColour : Opposite(initialColour);
        return higherColour == ChessColor.White
            ? Result(higher, lower, "C.04.3 Art. 5.2.5",
                $"Keine Präferenzen; Startnummer {higher.Tpn} ist {(isOdd ? "ungerade" : "gerade")} → {Name(higher)} erhält {(isOdd ? "die Anfangsfarbe" : "die Gegenfarbe")} Weiß.")
            : Result(lower, higher, "C.04.3 Art. 5.2.5",
                $"Keine Präferenzen; Startnummer {higher.Tpn} ist {(isOdd ? "ungerade" : "gerade")} → {Name(higher)} erhält {(isOdd ? "die Anfangsfarbe" : "die Gegenfarbe")} Schwarz.");
    }

    /// <summary>
    /// Lassen sich beide Wünsche gleichzeitig erfüllen? Ja, wenn sie auf verschiedene Farben zielen —
    /// oder wenn mindestens einer gar keine Präferenz hat (dann ist "beide erfüllt" trivial wahr).
    /// </summary>
    private static bool AreCompatible(FideColourPreference a, FideColourPreference b)
    {
        if (a.Strength == FideColourPreferenceStrength.None && b.Strength == FideColourPreferenceStrength.None)
        {
            return false;   // Niemand hat einen Wunsch -> 5.2.1 entscheidet nichts, weiter zu 5.2.5.
        }

        if (a.Strength == FideColourPreferenceStrength.None || b.Strength == FideColourPreferenceStrength.None)
        {
            return true;    // Nur einer hat einen Wunsch -> er bekommt ihn, der andere die Gegenfarbe.
        }

        return a.Colour != b.Colour;
    }

    /// <summary>
    /// Jüngste Runde, in der beide gespielt haben und unterschiedliche Farben hatten (Art. 5.2.3).
    /// Verglichen wird über die Rundennummer, nicht über die Position in der Farbfolge — sonst
    /// verschieben Freilose die Zuordnung.
    /// </summary>
    private static int? MostRecentRoundWithDifferentColours(FideDutchPlayerProfile a, FideDutchPlayerProfile b)
    {
        return a.ColourByRound.Keys
            .Where(round => b.ColourByRound.ContainsKey(round) && a.ColourByRound[round] != b.ColourByRound[round])
            .Select(round => (int?)round)
            .OrderByDescending(round => round)
            .FirstOrDefault();
    }

    private static FideColourAllocation Grant(
        FideDutchPlayerProfile granted,
        FideDutchPlayerProfile denied,
        string rule,
        string reason)
    {
        return granted.Preference.Colour == ChessColor.White
            ? Result(granted, denied, rule, reason)
            : Result(denied, granted, rule, reason);
    }

    private static FideColourAllocation Result(
        FideDutchPlayerProfile white,
        FideDutchPlayerProfile black,
        string rule,
        string reason)
    {
        return new FideColourAllocation(white, black, rule,
            $"{reason} Weiß: {Name(white)}, Schwarz: {Name(black)}.");
    }

    private static string Describe(FideDutchPlayerProfile profile) =>
        $"{Name(profile)} {profile.Preference.ToAuditToken()}";

    private static string Name(FideDutchPlayerProfile profile) =>
        $"#{profile.Tpn} {profile.Player.Name}";

    private static ChessColor Opposite(ChessColor colour) =>
        colour == ChessColor.White ? ChessColor.Black : ChessColor.White;
}
