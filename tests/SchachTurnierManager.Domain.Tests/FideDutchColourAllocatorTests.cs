using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Prüft <see cref="FideDutchColourAllocator"/> (C.04.3 Art. 5) gegen VERIFIZIERTE Sollfarben.
///
/// Die Erwartungswerte stammen aus den 15 Runden der drei Golden-Turniere, die einzeln gegen
/// bbpPairings 6.0.0 gegengeprüft wurden (siehe docs/FIDE_DUTCH_REFERENCE.md). Jeder Fall benennt
/// die Stufe aus Art. 5.2, die ihn entscheidet — zusammen decken sie alle fünf ab.
///
/// Die Farbhistorien werden hier direkt konstruiert: Der Test braucht weder die Paarungsstrategie
/// noch den Profil-Erbauer und nagelt Art. 5 isoliert fest.
/// </summary>
public sealed class FideDutchColourAllocatorTests
{
    /// <summary>
    /// Jeder Fall: Farbfolgen beider Spieler ("W"/"B" je gespielter Runde), Startnummern, und wer
    /// Weiß bekommen muss. Herkunft jeweils im Kommentar.
    /// </summary>
    public static TheoryData<string, int, string, int, string, int, string> Cases()
    {
        return new TheoryData<string, int, string, int, string, int, string>
        {
            // Farben A, TPN A, Farben B, TPN B, erwartete Regel, erwartete Weiß-TPN, Herkunft

            // --- Art. 5.2.5: keine Präferenzen (Runde 1) ---
            // Turnier A R1 Brett 1: 1 gegen 5 -> TPN 1 ist ungerade -> Anfangsfarbe Weiß.
            { "", 1, "", 5, "C.04.3 Art. 5.2.5", 1, "Turnier A R1: 1-5" },
            // Turnier A R1 Brett 2: 2 gegen 6 -> TPN 2 ist gerade -> Gegenfarbe -> 6 bekommt Weiß.
            { "", 2, "", 6, "C.04.3 Art. 5.2.5", 6, "Turnier A R1: 6-2" },
            // Turnier B R1 Brett 3: 3 gegen 6 -> TPN 3 ungerade -> 3 bekommt Weiß.
            { "", 3, "", 6, "C.04.3 Art. 5.2.5", 3, "Turnier B R1: 3-6" },

            // --- Art. 5.2.1: beide Wünsche erfüllbar ---
            // Turnier A R3 Brett 2: 3 (WB -> mild Weiß) gegen 6 (WW -> absolut Schwarz).
            { "WB", 3, "WW", 6, "C.04.3 Art. 5.2.1", 3, "Turnier A R3: 3-6" },
            // Turnier A R3 Brett 4: 5 (BB -> absolut Weiß) gegen 4 (BW -> mild Schwarz).
            { "BB", 5, "BW", 4, "C.04.3 Art. 5.2.1", 5, "Turnier A R3: 5-4" },
            // Turnier B R2: 3 (W -> stark Schwarz) gegen 7 (Freilos, also gar keine Farbe).
            // Nur einer hat einen Wunsch -> er bekommt ihn, der andere die Gegenfarbe.
            { "W", 3, "", 7, "C.04.3 Art. 5.2.1", 7, "Turnier B R2: 7-3" },

            // --- Art. 5.2.2: die stärkere Präferenz gewinnt ---
            // Turnier B R3 Brett 1: 5 (WW -> absolut Schwarz) gegen 7 (W -> stark Schwarz).
            // Beide wollen Schwarz; 5 ist absolut -> 5 bekommt Schwarz, 7 Weiß.
            { "WW", 5, "W", 7, "C.04.3 Art. 5.2.2", 7, "Turnier B R3: 7-5" },
            // Turnier C R5 Brett 1: 3 (WBWW -> absolut Schwarz) gegen 4 (BWBW -> mild Schwarz).
            { "WBWW", 3, "BWBW", 4, "C.04.3 Art. 5.2.2", 4, "Turnier C R5: 4-3" },
            // Turnier A R5 Brett 1: 8 (WWBW -> absolut Schwarz) gegen 2 (BWBW -> mild Schwarz).
            { "WWBW", 8, "BWBW", 2, "C.04.3 Art. 5.2.2", 2, "Turnier A R5: 2-8" },

            // --- Art. 5.2.4: gleich starke Wünsche, nie unterschiedliche Farben gehabt ---
            // Turnier A R2 Brett 1: 1 (W -> stark Schwarz) gegen 6 (W -> stark Schwarz).
            // Beide hatten in R1 Weiß, also nie unterschiedliche Farben -> 5.2.3 greift nicht.
            // Der höher Gesetzte (1) bekommt seinen Wunsch Schwarz -> 6 bekommt Weiß.
            { "W", 1, "W", 6, "C.04.3 Art. 5.2.4", 6, "Turnier A R2: 6-1" },
            // Turnier A R2 Brett 3: 2 (B -> stark Weiß) gegen 5 (B -> stark Weiß).
            { "B", 2, "B", 5, "C.04.3 Art. 5.2.4", 2, "Turnier A R2: 2-5" },
            // Turnier A R4 Brett 1: 1 (WBW) gegen 3 (WBW) - identische Farbfolgen, beide stark Schwarz.
            { "WBW", 1, "WBW", 3, "C.04.3 Art. 5.2.4", 3, "Turnier A R4: 3-1" }
        };
    }

    [Theory]
    [MemberData(nameof(Cases))]
    public void Allocate_MatchesVerifiedGoldenColours(
        string firstColours,
        int firstTpn,
        string secondColours,
        int secondTpn,
        string expectedRule,
        int expectedWhiteTpn,
        string origin)
    {
        var first = Profile(firstTpn, firstColours);
        var second = Profile(secondTpn, secondColours);

        var allocation = new FideDutchColourAllocator().Allocate(first, second, ChessColor.White);

        Assert.Equal(expectedWhiteTpn, allocation.White.Tpn);
        Assert.Equal(expectedRule, allocation.AppliedRule);
        Assert.NotEqual(allocation.White.Tpn, allocation.Black.Tpn);
        Assert.False(string.IsNullOrWhiteSpace(allocation.Reason), $"Audit-Begründung fehlt ({origin}).");
    }

    /// <summary>
    /// Das Ergebnis darf nicht von der Aufrufreihenfolge abhängen — sonst wäre die Auslosung nicht
    /// reproduzierbar (C.04.2 Art. 1.4).
    /// </summary>
    [Theory]
    [MemberData(nameof(Cases))]
    public void Allocate_IsIndependentOfArgumentOrder(
        string firstColours,
        int firstTpn,
        string secondColours,
        int secondTpn,
        string expectedRule,
        int expectedWhiteTpn,
        string origin)
    {
        var allocator = new FideDutchColourAllocator();

        var forward = allocator.Allocate(Profile(firstTpn, firstColours), Profile(secondTpn, secondColours), ChessColor.White);
        var reversed = allocator.Allocate(Profile(secondTpn, secondColours), Profile(firstTpn, firstColours), ChessColor.White);

        Assert.Equal(forward.White.Tpn, reversed.White.Tpn);
        Assert.Equal(forward.AppliedRule, reversed.AppliedRule);
    }

    /// <summary>
    /// Art. 5.1: Die Anfangsfarbe ist ausgelost. Wird andersherum gelost, kippt Runde 1 komplett —
    /// dort entscheidet ausschließlich Art. 5.2.5.
    /// </summary>
    [Fact]
    public void Allocate_InitialColourBlack_FlipsEveryFirstRoundBoard()
    {
        var allocator = new FideDutchColourAllocator();

        var withWhite = allocator.Allocate(Profile(1, ""), Profile(5, ""), ChessColor.White);
        var withBlack = allocator.Allocate(Profile(1, ""), Profile(5, ""), ChessColor.Black);

        Assert.Equal(1, withWhite.White.Tpn);
        Assert.Equal(5, withBlack.White.Tpn);
    }

    /// <summary>
    /// Art. 5.2.3: Haben beide gleich starke, gleichgerichtete Wünsche, aber in einer früheren Runde
    /// unterschiedliche Farben gehabt, wird gegenüber der jüngsten solchen Runde getauscht — noch
    /// vor Art. 5.2.4.
    /// </summary>
    [Fact]
    public void Allocate_WhenBothWantTheSameColour_AlternatesAgainstTheMostRecentDifferingRound()
    {
        // Beide Differenz +1 und letzte zwei Farben verschieden -> beide STARK Schwarz, gleich stark.
        // (Vorsicht: "BWW" wäre hier falsch — zweimal Weiß zuletzt macht die Präferenz nach
        //  Art. 1.7.1 ABSOLUT, dann entschiede schon 5.2.2.)
        //   #1: R1 W, R2 B, R3 W        #2: R1 W, R2 W, R3 B
        // Jüngste Runde mit verschiedenen Farben ist R3; dort hatte #1 Weiß
        // -> getauscht: #1 bekommt Schwarz, #2 Weiß. Und das noch VOR Art. 5.2.4, die dem höher
        //    Gesetzten (#1) sein Schwarz ohnehin gegeben hätte — der Test prüft also die Reihenfolge.
        var first = Profile(1, "WBW");
        var second = Profile(2, "WWB");

        var allocation = new FideDutchColourAllocator().Allocate(first, second, ChessColor.White);

        Assert.Equal("C.04.3 Art. 5.2.3", allocation.AppliedRule);
        Assert.Equal(2, allocation.White.Tpn);
    }

    /// <summary>Baut ein Profil mit der angegebenen Farbfolge; Runde 1..n in Reihenfolge.</summary>
    private static FideDutchPlayerProfile Profile(int tpn, string colours)
    {
        var sequence = colours.Select(c => c == 'W' ? ChessColor.White : ChessColor.Black).ToList();
        var byRound = sequence
            .Select((colour, index) => (Round: index + 1, Colour: colour))
            .ToDictionary(entry => entry.Round, entry => entry.Colour);

        return new FideDutchPlayerProfile(
            Player: new Player { Id = Guid.NewGuid(), Name = $"Spieler {tpn}", StartingRank = tpn },
            Points: 0m,
            Tpn: tpn,
            PlayedColours: sequence,
            ColourByRound: byRound,
            PlayedOpponentIds: new HashSet<Guid>(),
            IsByeIneligible: false,
            FloatLastRound: FideFloat.None,
            FloatTwoRoundsBack: FideFloat.None);
    }
}
