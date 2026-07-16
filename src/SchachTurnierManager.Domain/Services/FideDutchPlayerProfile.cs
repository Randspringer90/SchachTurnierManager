using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>Stärke einer Farbpräferenz nach FIDE C.04.3 Art. 1.7.</summary>
public enum FideColourPreferenceStrength
{
    /// <summary>Keine Präferenz — der Spieler hat noch keine Partie am Brett gespielt.</summary>
    None = 0,

    /// <summary>Art. 1.7.3: Farbdifferenz 0; die zuletzt gespielte Farbe soll alternieren.</summary>
    Mild = 1,

    /// <summary>Art. 1.7.2: Farbdifferenz +1 (Schwarz) bzw. −1 (Weiß).</summary>
    Strong = 2,

    /// <summary>Art. 1.7.1: Farbdifferenz über ±1 ODER zweimal dieselbe Farbe zuletzt.</summary>
    Absolute = 3
}

/// <summary>Float-Zustand eines Spielers in einer bestimmten Runde (C.04.3 Art. 1.4).</summary>
public enum FideFloat
{
    None = 0,

    /// <summary>Art. 1.4.2/1.4.3: gegen einen niedriger platzierten gespielt, Freilos erhalten oder
    /// ohne zu spielen mehr als die Niederlagenpunktzahl bekommen.</summary>
    Down = 1,

    /// <summary>Art. 1.4.2: gegen einen höher platzierten Spieler gespielt.</summary>
    Up = 2
}

/// <summary>
/// Farbpräferenz eines Spielers: gewünschte Farbe plus Stärke (C.04.3 Art. 1.7).
/// </summary>
public sealed record FideColourPreference(ChessColor Colour, FideColourPreferenceStrength Strength)
{
    public static FideColourPreference None { get; } = new(ChessColor.None, FideColourPreferenceStrength.None);

    public bool IsAbsolute => Strength == FideColourPreferenceStrength.Absolute;

    public bool IsAtLeastStrong => Strength >= FideColourPreferenceStrength.Strong;

    /// <summary>Kurzform für den Audit-Trail, angelehnt an die übliche Schreibweise:
    /// Großbuchstabe = absolut, Klammern = stark, Kleinbuchstabe = mild.</summary>
    public string ToAuditToken() => (Colour, Strength) switch
    {
        (_, FideColourPreferenceStrength.None) => "-",
        (ChessColor.White, FideColourPreferenceStrength.Absolute) => "W",
        (ChessColor.Black, FideColourPreferenceStrength.Absolute) => "B",
        (ChessColor.White, FideColourPreferenceStrength.Strong) => "(W)",
        (ChessColor.Black, FideColourPreferenceStrength.Strong) => "(B)",
        (ChessColor.White, FideColourPreferenceStrength.Mild) => "w",
        (ChessColor.Black, FideColourPreferenceStrength.Mild) => "b",
        _ => "-"
    };
}

/// <summary>
/// Alles, was das FIDE-Dutch-System über einen Spieler wissen muss, um eine Runde auszulosen.
/// Bewusst getrennt vom Paarungsverfahren: Diese Zahlen sind gegen die Checklisten einer
/// zugelassenen Referenz-Engine geprüft (siehe docs/FIDE_DUTCH_REFERENCE.md).
/// </summary>
/// <param name="Player">Der Spieler.</param>
/// <param name="Points">Punktestand vor dieser Runde.</param>
/// <param name="Tpn">Startnummer (Tournament Pairing Number), C.04.2 Art. 2.2.</param>
/// <param name="PlayedColours">
/// Farbfolge in Rundenreihenfolge — NUR tatsächlich am Brett gespielte Partien. Freilose und
/// kampflose Ergebnisse fehlen hier bewusst: nach C.04.2 Art. 3.4 wird die Historie behandelt,
/// als hätte die Runde nicht stattgefunden.
/// </param>
/// <param name="PlayedOpponentIds">
/// Nur tatsächlich am Brett ausgetragene Begegnungen. Wer kampflos gegeneinander „angesetzt" war,
/// hat nicht gegeneinander gespielt und darf nach C.04.2 Art. 3.5 später noch gepaart werden —
/// [C1] sperrt diese Kombination also nicht.
/// </param>
/// <param name="IsByeIneligible">
/// [C2] (Art. 2.1.2) / C.04.1 Art. 4: Der Spieler hatte bereits ein Freilos ODER hat in einer Runde
/// ohne zu spielen die volle Siegpunktzahl erhalten. Beides sperrt ein weiteres Freilos.
/// </param>
/// <param name="FloatLastRound">Float aus der Vorrunde — Grundlage für [C14]/[C15] und [C18]/[C19].</param>
/// <param name="FloatTwoRoundsBack">Float von vor zwei Runden — Grundlage für [C16]/[C17] und [C20]/[C21].</param>
public sealed record FideDutchPlayerProfile(
    Player Player,
    decimal Points,
    int Tpn,
    IReadOnlyList<ChessColor> PlayedColours,
    IReadOnlySet<Guid> PlayedOpponentIds,
    bool IsByeIneligible,
    FideFloat FloatLastRound,
    FideFloat FloatTwoRoundsBack)
{
    /// <summary>Art. 1.6: Weißpartien minus Schwarzpartien. Ungespielte Runden zählen nicht mit.</summary>
    public int ColourDifference =>
        PlayedColours.Count(colour => colour == ChessColor.White) -
        PlayedColours.Count(colour => colour == ChessColor.Black);

    /// <summary>
    /// Art. 1.7: Farbpräferenz.
    /// </summary>
    /// <remarks>
    /// ACHTUNG — Art. 1.7.1 hat ZWEI Auslöser, verknüpft mit ODER:
    /// Farbdifferenz über ±1 <b>oder</b> dieselbe Farbe in den beiden letzten GESPIELTEN Runden.
    /// Ein Spieler mit Differenz −1 ist also nicht zwingend „nur" stark (Beispiel WBB: Differenz −1,
    /// aber absolut Weiß), und Differenz 0 ist nicht zwingend mild (Beispiel WWBB: Differenz 0,
    /// aber absolut Weiß). Beide Bedingungen prüfen; absolut gewinnt.
    ///
    /// Das ist kein Detail: Die Einstufung entscheidet über [C3] (Art. 2.1.3) und damit darüber,
    /// welche Paarungen überhaupt erlaubt sind. Eine falsche Einstufung erlaubt verbotene Paarungen.
    /// </remarks>
    public FideColourPreference Preference
    {
        get
        {
            if (PlayedColours.Count == 0)
            {
                return FideColourPreference.None;
            }

            var difference = ColourDifference;

            // Art. 1.7.1, erster Ausloeser: Differenz ueber +1 bzw. unter -1.
            if (difference > 1)
            {
                return new FideColourPreference(ChessColor.Black, FideColourPreferenceStrength.Absolute);
            }

            if (difference < -1)
            {
                return new FideColourPreference(ChessColor.White, FideColourPreferenceStrength.Absolute);
            }

            // Art. 1.7.1, zweiter Ausloeser: zweimal dieselbe Farbe in den beiden letzten
            // GESPIELTEN Runden - unabhaengig von der Differenz.
            if (PlayedColours.Count >= 2)
            {
                var last = PlayedColours[^1];
                if (last == PlayedColours[^2])
                {
                    return new FideColourPreference(Opposite(last), FideColourPreferenceStrength.Absolute);
                }
            }

            // Art. 1.7.2: Differenz +-1 -> stark, Praeferenz zum Ausgleich.
            if (difference == 1)
            {
                return new FideColourPreference(ChessColor.Black, FideColourPreferenceStrength.Strong);
            }

            if (difference == -1)
            {
                return new FideColourPreference(ChessColor.White, FideColourPreferenceStrength.Strong);
            }

            // Art. 1.7.3: Differenz 0 -> mild, alternierend zur zuletzt gespielten Farbe.
            return new FideColourPreference(Opposite(PlayedColours[^1]), FideColourPreferenceStrength.Mild);
        }
    }

    /// <summary>
    /// C.04.1 Art. 7: Bekaeme der Spieler mit dieser Farbe dreimal in Folge dieselbe?
    /// Bezieht sich auf die beiden letzten GESPIELTEN Runden (C.04.2 Art. 3.4).
    /// </summary>
    public bool WouldBeThirdSameColour(ChessColor assigned) =>
        PlayedColours.Count >= 2 &&
        PlayedColours[^1] == assigned &&
        PlayedColours[^2] == assigned;

    private static ChessColor Opposite(ChessColor colour) =>
        colour == ChessColor.White ? ChessColor.Black : ChessColor.White;
}
