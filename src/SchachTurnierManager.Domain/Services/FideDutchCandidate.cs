using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Ein Kandidat für die Paarung eines Brackets (C.04.3 Art. 3.3): die gebildeten Paare plus die
/// Spieler, die ungepaart bleiben und ins nächste Bracket abfloaten.
/// </summary>
/// <param name="Pairs">Die Paare. Die Farbzuteilung erfolgt erst später (Art. 5).</param>
/// <param name="Downfloaters">Ungepaarte Spieler — sie werden MDPs des nächsten Brackets (Art. 1.4.1).</param>
/// <param name="GenerationIndex">
/// Position in der Erzeugungsreihenfolge nach Art. 3.6/3.7 und 4.2–4.5. Bei Gleichstand aller
/// Kriterien gewinnt der KLEINERE Index — das ist der Determinismus-Anker aus Art. 3.8.
/// </param>
public sealed record FideDutchCandidate(
    IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> Pairs,
    IReadOnlyList<FideDutchPlayerProfile> Downfloaters,
    int GenerationIndex);

/// <summary>
/// Bewertet Kandidaten nach den Qualitätskriterien [C6]–[C21] (C.04.3 Art. 2.4).
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Die Kriterien bilden eine strenge Rangfolge: Ein Kandidat ist besser, wenn er ein
/// höherpriorisiertes Kriterium besser erfüllt — egal wie viel schlechter er bei allen folgenden
/// ist. Deshalb wird hier ein Vektor gebaut und LEXIKOGRAFISCH verglichen, nicht aufsummiert.
/// Eine Summe mit Gewichten wäre genau der Fehler, den die V2-Engine bewusst macht (dort ist es
/// richtig, hier wäre es regelwidrig).
///
/// Kleinere Werte sind besser — jedes Kriterium ist ein "minimise".
/// </remarks>
public sealed class FideDutchCandidateEvaluator(FideDutchAbsoluteCriteria criteria, FideDutchColourAllocator colours, ChessColor initialColour)
{
    /// <summary>
    /// Baut den Bewertungsvektor eines Kandidaten. Verglichen wird lexikografisch; der erste
    /// Unterschied entscheidet.
    /// </summary>
    /// <param name="byeAssignee">
    /// Der Spieler, der in diesem Kandidaten das Freilos bekäme, oder <c>null</c>. Nur im letzten
    /// Bracket besetzt — dort entscheiden [C5] und [C9] mit.
    /// </param>
    /// <param name="roundsPlayed">Bisher gespielte Runden; nötig für [C9].</param>
    public IReadOnlyList<decimal> Evaluate(
        FideDutchCandidate candidate,
        FideDutchBracket bracket,
        FideDutchPlayerProfile? byeAssignee = null,
        int roundsPlayed = 0)
    {
        var vector = new List<decimal>();

        // [C5] Art. 2.3.1 - Punktzahl des Freilos-Empfaengers minimieren. Steht VOR allen
        // Qualitaetskriterien (Art. 2.3 kommt vor Art. 2.4). Ohne Freilos traegt es nichts bei.
        vector.Add(byeAssignee?.Points ?? decimal.MinValue);

        // [C6] Art. 2.4.1 - Zahl der Downfloater minimieren (= Paare maximieren).
        vector.Add(candidate.Downfloaters.Count);

        // [C7] Art. 2.4.2 - Punktzahlen der Downfloater, absteigend betrachtet, minimieren.
        // Auf feste Laenge auffuellen, damit der lexikografische Vergleich nicht an
        // unterschiedlich langen Listen scheitert. (Bei gleichem [C6] sind sie ohnehin gleich lang.)
        foreach (var points in candidate.Downfloaters.Select(profile => profile.Points).OrderByDescending(points => points))
        {
            vector.Add(points);
        }

        for (var i = candidate.Downfloaters.Count; i < bracket.Players.Count; i++)
        {
            vector.Add(decimal.MinValue);   // "kein weiterer Downfloater" ist besser als jeder
        }

        // [C8] Art. 2.4.3 wird NICHT hier bewertet: "Waehle die Downfloater so, dass im folgenden
        // Bracket [C1]-[C7] erfuellbar bleiben" ist eine Aussage ueber den REST der Runde. Das
        // erledigt das Backtracking in FideDutchPairingStrategy - ein Kandidat, der die Runde
        // unvollendbar macht, wird dort verworfen (zusammen mit [C4], Art. 2.2.1).

        // [C9] Art. 2.4.4 - Zahl der ungespielten Partien des Freilos-Empfaengers minimieren.
        // Ungespielt = Runden ohne Partie am Brett (fruehere Freilose, kampflose Ergebnisse).
        vector.Add(byeAssignee is null ? decimal.MinValue : roundsPlayed - byeAssignee.PlayedColours.Count);

        var allocations = candidate.Pairs
            .Select(pair => colours.Allocate(pair.A, pair.B, initialColour))
            .ToList();

        // [C10] Art. 2.4.5 - Topscorer/deren Gegner mit Farbdifferenz ueber +-2 minimieren.
        vector.Add(allocations.Sum(CountTopscorerColourDifferenceViolations));

        // [C11] Art. 2.4.6 - Topscorer/deren Gegner mit dreimal gleicher Farbe minimieren.
        vector.Add(allocations.Sum(CountTopscorerTripleColour));

        // [C12] Art. 2.4.7 - Spieler ohne erfuellte Farbpraeferenz minimieren.
        vector.Add(allocations.Sum(allocation => CountDeniedPreferences(allocation, minimumStrength: FideColourPreferenceStrength.Mild)));

        // [C13] Art. 2.4.8 - Spieler ohne erfuellte STARKE Farbpraeferenz minimieren.
        // NICHT redundant zu [C12]: [C12] zaehlt jede unerfuellte Praeferenz gleich, [C13] nur die
        // starken (und absoluten). Zwei Kandidaten mit gleichem [C12] koennen sich hier
        // unterscheiden - und dann entscheidet es. Siehe Golden-Turnier B R4 und C R4.
        vector.Add(allocations.Sum(allocation => CountDeniedPreferences(allocation, minimumStrength: FideColourPreferenceStrength.Strong)));

        // [C14] Art. 2.4.9  - Resident-Downfloater mit Downfloat in der Vorrunde minimieren.
        vector.Add(candidate.Downfloaters.Count(profile =>
            IsResident(profile, bracket) && profile.FloatLastRound == FideFloat.Down));

        // [C15] Art. 2.4.10 - MDP-Gegner mit Upfloat in der Vorrunde minimieren.
        vector.Add(CountMdpOpponents(candidate, bracket, FideFloat.Up, twoRoundsBack: false));

        // [C16] Art. 2.4.11 - Resident-Downfloater mit Downfloat vor zwei Runden minimieren.
        vector.Add(candidate.Downfloaters.Count(profile =>
            IsResident(profile, bracket) && profile.FloatTwoRoundsBack == FideFloat.Down));

        // [C17] Art. 2.4.12 - MDP-Gegner mit Upfloat vor zwei Runden minimieren.
        vector.Add(CountMdpOpponents(candidate, bracket, FideFloat.Up, twoRoundsBack: true));

        // [C18]-[C21] Art. 2.4.13-2.4.16 - Punktdifferenzen der wiederholt Floatenden minimieren.
        //
        // ACHTUNG: Das sind die "kein doppelter Absteiger"-Regeln und KEINE Feinjustierung. Sie
        // entscheiden ganze Runden, wenn alles bis [C17] gleichsteht (Golden-Turnier A R5). Die
        // aeltere Fassung formuliert denselben Gedanken klarer: "minimize the score differences of
        // players who receive the SAME downfloat as two rounds before".
        AddRepeatedFloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: false);
        AddRepeatedFloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: true);

        return vector;
    }

    /// <summary>
    /// Lexikografischer Vergleich zweier Bewertungsvektoren. Negativ = <paramref name="a"/> ist besser.
    /// </summary>
    public static int Compare(IReadOnlyList<decimal> a, IReadOnlyList<decimal> b)
    {
        for (var i = 0; i < Math.Min(a.Count, b.Count); i++)
        {
            var comparison = a[i].CompareTo(b[i]);
            if (comparison != 0)
            {
                return comparison;
            }
        }

        return a.Count.CompareTo(b.Count);
    }

    private static bool IsResident(FideDutchPlayerProfile profile, FideDutchBracket bracket) =>
        bracket.Residents.Any(resident => resident.Player.Id == profile.Player.Id);

    private static bool IsMdp(FideDutchPlayerProfile profile, FideDutchBracket bracket) =>
        bracket.Mdps.Any(mdp => mdp.Player.Id == profile.Player.Id);

    /// <summary>Gegner der MDPs, die den gesuchten Float hatten ([C15]/[C17]).</summary>
    private static int CountMdpOpponents(
        FideDutchCandidate candidate,
        FideDutchBracket bracket,
        FideFloat wanted,
        bool twoRoundsBack)
    {
        var count = 0;
        foreach (var (a, b) in candidate.Pairs)
        {
            var opponent = IsMdp(a, bracket) ? b : IsMdp(b, bracket) ? a : null;
            if (opponent is null)
            {
                continue;
            }

            var actual = twoRoundsBack ? opponent.FloatTwoRoundsBack : opponent.FloatLastRound;
            if (actual == wanted)
            {
                count++;
            }
        }

        return count;
    }

    /// <summary>
    /// [C18]/[C20]: Punktdifferenzen der MDPs, die schon zuvor abgefloatet sind — absteigend
    /// betrachtet und minimiert. Wer erneut abfloatet, statt gepaart zu werden, zählt mit der
    /// vollen Differenz zum Bracket; wer gepaart wird, mit der Differenz zu seinem Gegner.
    /// </summary>
    private static void AddRepeatedFloatScoreDifferences(
        List<decimal> vector,
        FideDutchCandidate candidate,
        FideDutchBracket bracket,
        bool twoRoundsBack)
    {
        var differences = new List<decimal>();

        foreach (var mdp in bracket.Mdps)
        {
            var previous = twoRoundsBack ? mdp.FloatTwoRoundsBack : mdp.FloatLastRound;
            if (previous != FideFloat.Down)
            {
                continue;   // Nur wer schon abgefloatet ist, zaehlt hier.
            }

            var pair = candidate.Pairs.FirstOrDefault(pair =>
                pair.A.Player.Id == mdp.Player.Id || pair.B.Player.Id == mdp.Player.Id);

            if (pair.A is not null)
            {
                var opponent = pair.A.Player.Id == mdp.Player.Id ? pair.B : pair.A;
                differences.Add(Math.Abs(mdp.Points - opponent.Points));
            }
            else
            {
                // Nicht gepaart -> floatet erneut ab. Als Bezug dient die Punktzahl der Residents:
                // je weiter er faellt, desto schlechter.
                differences.Add(Math.Abs(mdp.Points - bracket.ResidentPoints) + 1m);
            }
        }

        foreach (var difference in differences.OrderByDescending(value => value))
        {
            vector.Add(difference);
        }

        for (var i = differences.Count; i < bracket.Mdps.Count; i++)
        {
            vector.Add(decimal.MinValue);
        }
    }

    /// <summary>[C12]/[C13]: Wie viele Spieler dieses Paares bekommen ihre Präferenz nicht?</summary>
    private static int CountDeniedPreferences(FideColourAllocation allocation, FideColourPreferenceStrength minimumStrength)
    {
        var count = 0;
        if (IsDenied(allocation.White, ChessColor.White, minimumStrength))
        {
            count++;
        }

        if (IsDenied(allocation.Black, ChessColor.Black, minimumStrength))
        {
            count++;
        }

        return count;
    }

    private static bool IsDenied(FideDutchPlayerProfile profile, ChessColor assigned, FideColourPreferenceStrength minimumStrength) =>
        profile.Preference.Strength >= minimumStrength && profile.Preference.Colour != assigned;

    /// <summary>[C10] Art. 2.4.5 — nur in der Schlussrunde relevant, weil es sonst keine Topscorer gibt.</summary>
    private int CountTopscorerColourDifferenceViolations(FideColourAllocation allocation)
    {
        var count = 0;
        if (Involves(allocation) && Math.Abs(allocation.White.ColourDifference + 1) > 2)
        {
            count++;
        }

        if (Involves(allocation) && Math.Abs(allocation.Black.ColourDifference - 1) > 2)
        {
            count++;
        }

        return count;
    }

    /// <summary>[C11] Art. 2.4.6 — dreimal dieselbe Farbe für Topscorer oder deren Gegner.</summary>
    private int CountTopscorerTripleColour(FideColourAllocation allocation)
    {
        var count = 0;
        if (Involves(allocation) && allocation.White.WouldBeThirdSameColour(ChessColor.White))
        {
            count++;
        }

        if (Involves(allocation) && allocation.Black.WouldBeThirdSameColour(ChessColor.Black))
        {
            count++;
        }

        return count;
    }

    /// <summary>Betrifft dieses Paar einen Topscorer (und damit auch dessen Gegner)?</summary>
    private bool Involves(FideColourAllocation allocation) =>
        criteria.IsTopscorer(allocation.White) || criteria.IsTopscorer(allocation.Black);
}
