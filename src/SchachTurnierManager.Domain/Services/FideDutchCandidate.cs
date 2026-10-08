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
    /// Der tatsächliche Freilos-Empfänger für [C5] oder <c>null</c>. [C9] gilt nur, wenn
    /// dieser Kandidat genau diesen einen Spieler abfloatet (Art. 2.4.4, Anmerkung).
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

        // C8 wird von der Strategie zwischen diesem C5-C7-Präfix und C9 eingefügt:
        // verglichen wird C5-C7 des tatsächlich vollständig gepaarten folgenden Brackets.

        // [C9] Art. 2.4.4 - Zahl der ungespielten Partien des Freilos-Empfaengers minimieren.
        // Ungespielt = Runden ohne Partie am Brett (fruehere Freilose, kampflose Ergebnisse).
        var appliesC9 = byeAssignee is not null && candidate.Downfloaters.Count == 1 &&
            candidate.Downfloaters[0].Player.Id == byeAssignee.Player.Id;
        vector.Add(appliesC9 ? roundsPlayed - byeAssignee!.PlayedColours.Count : decimal.MinValue);

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
        AddRepeatedFloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: false); // C18
        AddRepeatedUpfloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: false); // C19
        AddRepeatedFloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: true); // C20
        AddRepeatedUpfloatScoreDifferences(vector, candidate, bracket, twoRoundsBack: true); // C21

        return vector;
    }

    /// <summary>
    /// Eine konservative Untergrenze für einen festen C6-Wert. Die Strategie ergänzt C8 und
    /// den rundenweiten C5-Wert, bevor eine vollständige Paarung vorzeitig angenommen wird.
    /// </summary>
    public IReadOnlyList<decimal> LowerBound(
        FideDutchBracket bracket,
        int downfloatCount,
        bool hasBye,
        int roundsPlayed = 0,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>? pairedPrefix = null)
    {
        if (downfloatCount < 0 || downfloatCount > bracket.Players.Count ||
            (bracket.Players.Count - downfloatCount) % 2 != 0 ||
            !bracket.IsHomogeneous && downfloatCount < bracket.Mdps.Count - bracket.Residents.Count)
        {
            throw new ArgumentOutOfRangeException(nameof(downfloatCount));
        }

        var prefix = pairedPrefix ?? Array.Empty<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>();
        var allocations = prefix.Select(pair => colours.Allocate(pair.A, pair.B, initialColour)).ToArray();
        var prefixCandidate = new FideDutchCandidate(prefix, Array.Empty<FideDutchPlayerProfile>(), 0);
        var eligible = bracket.Players.Where(FideDutchAbsoluteCriteria.MayReceiveBye).ToArray();
        var lowerBound = new List<decimal>
        {
            hasBye && eligible.Length > 0 ? eligible.Min(profile => profile.Points) : decimal.MinValue,
            downfloatCount
        };
        lowerBound.AddRange(bracket.Players.Select(profile => profile.Points)
            .OrderBy(points => points).Take(downfloatCount).OrderByDescending(points => points));
        Pad(lowerBound, bracket.Players.Count - downfloatCount);

        // C9 ist nur bei genau einem späteren Freilos-Absteiger aktiv. Die unter allen
        // Berechtigten kleinste Zahl ist eine Untergrenze; kein historischer Wert wird erfunden.
        lowerBound.Add(hasBye && downfloatCount == 1 && eligible.Length > 0
            ? eligible.Min(profile => roundsPlayed - profile.PlayedColours.Count)
            : decimal.MinValue);
        lowerBound.Add(allocations.Sum(CountTopscorerColourDifferenceViolations)); // C10
        lowerBound.Add(allocations.Sum(CountTopscorerTripleColour)); // C11
        lowerBound.Add(DeniedPreferenceLowerBound(bracket, downfloatCount, FideColourPreferenceStrength.Mild, allocations));
        lowerBound.Add(DeniedPreferenceLowerBound(bracket, downfloatCount, FideColourPreferenceStrength.Strong, allocations));
        lowerBound.Add(RepeatedResidentDownLowerBound(bracket, downfloatCount, twoRoundsBack: false));
        lowerBound.Add(Math.Max(RepeatedOpponentUpLowerBound(bracket, downfloatCount, twoRoundsBack: false),
            CountMdpOpponents(prefixCandidate, bracket, FideFloat.Up, twoRoundsBack: false)));
        lowerBound.Add(RepeatedResidentDownLowerBound(bracket, downfloatCount, twoRoundsBack: true));
        lowerBound.Add(Math.Max(RepeatedOpponentUpLowerBound(bracket, downfloatCount, twoRoundsBack: true),
            CountMdpOpponents(prefixCandidate, bracket, FideFloat.Up, twoRoundsBack: true)));

        AddRepeatedDownfloatLowerBound(lowerBound, bracket, twoRoundsBack: false, prefix);
        AddRepeatedUpfloatLowerBound(lowerBound, bracket, downfloatCount, twoRoundsBack: false, prefix);
        AddRepeatedDownfloatLowerBound(lowerBound, bracket, twoRoundsBack: true, prefix);
        AddRepeatedUpfloatLowerBound(lowerBound, bracket, downfloatCount, twoRoundsBack: true, prefix);

        return lowerBound;
    }

    public bool IsTheoreticalMinimum(
        IReadOnlyList<decimal> score,
        FideDutchBracket bracket,
        int downfloatCount,
        bool hasBye) =>
        Compare(score, LowerBound(bracket, downfloatCount, hasBye)) == 0;

    private static int DeniedPreferenceLowerBound(
        FideDutchBracket bracket,
        int downfloatCount,
        FideColourPreferenceStrength strength,
        IReadOnlyList<FideColourAllocation> allocations)
    {
        var placed = allocations.SelectMany(allocation => new[] { allocation.White.Player.Id, allocation.Black.Player.Id })
            .ToHashSet();
        var preferences = bracket.Players.Where(profile => !placed.Contains(profile.Player.Id))
            .Select(profile => profile.Preference).Where(preference => preference.Strength >= strength).ToArray();
        var whites = preferences.Count(preference => preference.Colour == ChessColor.White);
        var blacks = preferences.Count(preference => preference.Colour == ChessColor.Black);
        var remainingPairs = (bracket.Players.Count - downfloatCount) / 2 - allocations.Count;
        var deniedSoFar = allocations.Sum(allocation => CountDeniedPreferences(allocation, strength));
        // Bekannte Paare bleiben unverändert. Unter allen übrigen Spielern können höchstens d
        // abfloaten; jede Farbe steht nur noch remainingPairs Mal zur Verfügung.
        return deniedSoFar + Math.Max(0, Math.Max(whites, blacks) - downfloatCount - remainingPairs);
    }

    private static int RepeatedResidentDownLowerBound(
        FideDutchBracket bracket, int downfloatCount, bool twoRoundsBack)
    {
        var repeated = bracket.Residents.Count(profile =>
            (twoRoundsBack ? profile.FloatTwoRoundsBack : profile.FloatLastRound) == FideFloat.Down);
        // Selbst wenn alle anderen Spieler abfloaten, müssen diese restlichen d Plätze belegt sein.
        return Math.Max(0, downfloatCount - (bracket.Players.Count - repeated));
    }

    private static int RepeatedOpponentUpLowerBound(
        FideDutchBracket bracket, int downfloatCount, bool twoRoundsBack)
    {
        if (bracket.IsHomogeneous)
        {
            return 0;
        }

        var minimumPairedMdps = Math.Max(0, bracket.Mdps.Count - downfloatCount);
        var residentsWithoutRepeat = bracket.Residents.Count(profile =>
            (twoRoundsBack ? profile.FloatTwoRoundsBack : profile.FloatLastRound) != FideFloat.Up);
        return Math.Max(0, minimumPairedMdps - residentsWithoutRepeat);
    }

    private static void AddRepeatedUpfloatLowerBound(
        List<decimal> vector, FideDutchBracket bracket, int downfloatCount, bool twoRoundsBack,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> prefix)
    {
        var minimumCount = RepeatedOpponentUpLowerBound(bracket, downfloatCount, twoRoundsBack);
        var differences = new List<decimal>();
        foreach (var (a, b) in prefix)
        {
            var opponent = IsMdp(a, bracket) ? b : IsMdp(b, bracket) ? a : null;
            if (opponent is not null &&
                (twoRoundsBack ? opponent.FloatTwoRoundsBack : opponent.FloatLastRound) == FideFloat.Up)
            {
                differences.Add(Math.Abs(a.Points - b.Points));
            }
        }

        var additionalMinimum = Math.Max(0, minimumCount - differences.Count);
        if (additionalMinimum > 0)
        {
            var minimumDifference = bracket.Mdps.Min(mdp => bracket.Residents
                .Where(profile => (twoRoundsBack ? profile.FloatTwoRoundsBack : profile.FloatLastRound) == FideFloat.Up)
                .Min(resident => Math.Abs(mdp.Points - resident.Points)));
            for (var index = 0; index < additionalMinimum; index++)
            {
                differences.Add(minimumDifference);
            }
        }

        // Bekannte Differenzen plus die mindestens noch erforderlichen Wiederholungen.
        // Weitere optionale Differenzen würden den absteigend sortierten Vektor nur vergrößern.
        vector.AddRange(differences.OrderByDescending(value => value));
        Pad(vector, bracket.Mdps.Count - differences.Count);
    }

    private static void AddRepeatedDownfloatLowerBound(
        List<decimal> vector,
        FideDutchBracket bracket,
        bool twoRoundsBack,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> prefix)
    {
        var differences = bracket.Mdps
            .Where(profile => (twoRoundsBack ? profile.FloatTwoRoundsBack : profile.FloatLastRound) == FideFloat.Down)
            .Select(profile =>
            {
                var pair = prefix.FirstOrDefault(pair => pair.A.Player.Id == profile.Player.Id || pair.B.Player.Id == profile.Player.Id);
                if (pair.A is not null)
                {
                    var opponent = pair.A.Player.Id == profile.Player.Id ? pair.B : pair.A;
                    return Math.Abs(profile.Points - opponent.Points);
                }

                return bracket.IsHomogeneous ? 0m :
                    bracket.Residents.Select(resident => Math.Abs(profile.Points - resident.Points))
                        .Append(Math.Abs(profile.Points - bracket.ResidentPoints) + 1m).Min();
            })
            .OrderByDescending(value => value).ToArray();
        vector.AddRange(differences);
        Pad(vector, bracket.Mdps.Count - differences.Length);
    }

    private static void Pad(List<decimal> vector, int count)
    {
        for (var index = 0; index < count; index++)
        {
            vector.Add(decimal.MinValue);
        }
    }

    private static void AddRepeatedUpfloatScoreDifferences(
        List<decimal> vector,
        FideDutchCandidate candidate,
        FideDutchBracket bracket,
        bool twoRoundsBack)
    {
        var differences = new List<decimal>();
        foreach (var (a, b) in candidate.Pairs)
        {
            var opponent = IsMdp(a, bracket) ? b : IsMdp(b, bracket) ? a : null;
            if (opponent is not null &&
                (twoRoundsBack ? opponent.FloatTwoRoundsBack : opponent.FloatLastRound) == FideFloat.Up)
            {
                differences.Add(Math.Abs(a.Points - b.Points));
            }
        }

        vector.AddRange(differences.OrderByDescending(value => value));
        Pad(vector, bracket.Mdps.Count - differences.Count);
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
