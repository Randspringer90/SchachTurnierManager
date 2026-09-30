namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Erzeugt die Paarungskandidaten eines Brackets in der von C.04.3 vorgeschriebenen REIHENFOLGE
/// (Art. 3.3, 3.6, 3.7 und 4.1–4.5). Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
/// <remarks>
/// Warum die Reihenfolge zählt und nicht nur die Menge der Kandidaten: Art. 3.8 sagt, dass bei
/// gleicher Erfüllung ALLER Kriterien der <b>zuerst erzeugte</b> Kandidat gewinnt. Das ist der
/// Determinismus-Anker des ganzen Systems (C.04.2 Art. 1.4 verlangt, dass verschiedene zugelassene
/// Programme zu identischen Paarungen kommen). Ein Verfahren, das einfach „die beste Paarung" sucht,
/// reproduziert diesen Tiebreak nicht.
///
/// Die Kandidaten werden faul erzeugt und Paare, die [C1] oder [C3] verletzen, sofort verworfen.
/// Das hält die Zahl der Möglichkeiten klein: Ohne diese Beschneidung müsste ein Bracket mit zehn
/// Residents alle Permutationen durchlaufen.
/// </remarks>
public sealed class FideDutchCandidateGenerator(
    FideDutchAbsoluteCriteria criteria,
    Action? checkBudget = null)
{
    private readonly Dictionary<(Guid Left, Guid Right), bool> _pairingCache = new();
    private readonly Action _checkBudget = checkBudget ?? (() => { });
    /// <summary>
    /// Alle Kandidaten des Brackets, in Erzeugungsreihenfolge. Der <c>GenerationIndex</c> zählt dabei
    /// hoch — Art. 3.8 vergleicht ihn bei Gleichstand.
    /// </summary>
    public IEnumerable<FideDutchCandidate> Generate(FideDutchBracket bracket)
    {
        var index = 0;

        // Verschiedene Erzeugungswege - andere Transposition, anderer Exchange - fuehren haeufig zur
        // GLEICHEN Paarung. Fuer die Auslosung ist nur die Paarung selbst relevant, und Art. 3.8
        // vergleicht bei Gleichstand den ZUERST erzeugten Kandidaten. Deshalb wird jede Paarung nur
        // einmal ausgegeben, und zwar bei ihrem ersten Auftreten: Das ist regelkonform und schneidet
        // die Kandidatenzahl drastisch. Ohne das laufen die Property-Tests ueber zehn Minuten.
        var seen = new HashSet<string>();

        // [C6] (Art. 2.4.1) will moeglichst viele Paare. Deshalb absteigend: Kandidaten mit mehr
        // Paaren entstehen zuerst. Weniger Paare sind trotzdem noetig, wenn [C4] (Art. 2.2.1) sie
        // erzwingt - das entscheidet aber erst das Backtracking, nicht diese Erzeugung.
        for (var pairCount = bracket.MaxPairsUpperBound; pairCount >= 0; pairCount--)
        {
            CheckBudget();
            foreach (var candidate in GenerateWithPairCount(bracket, pairCount))
            {
                CheckBudget();
                if (seen.Add(KeyOf(candidate)))
                {
                    yield return candidate with { GenerationIndex = index++ };
                }
            }
        }
    }

    /// <summary>Kanonischer Schlüssel einer Paarung — unabhängig davon, über welchen Weg sie entstand.</summary>
    private static string KeyOf(FideDutchCandidate candidate)
    {
        var pairs = candidate.Pairs
            .Select(pair => pair.A.Tpn < pair.B.Tpn ? $"{pair.A.Tpn}-{pair.B.Tpn}" : $"{pair.B.Tpn}-{pair.A.Tpn}")
            .OrderBy(text => text, StringComparer.Ordinal);

        var floats = candidate.Downfloaters.Select(profile => profile.Tpn).OrderBy(tpn => tpn);

        return string.Join(",", pairs) + "|" + string.Join(",", floats);
    }

    private IEnumerable<FideDutchCandidate> GenerateWithPairCount(FideDutchBracket bracket, int pairCount)
    {
        return bracket.IsHomogeneous
            ? GenerateHomogeneous(bracket.Players, pairCount)
            : GenerateHeterogeneous(bracket, pairCount);
    }

    /// <summary>
    /// Homogenes Bracket (oder Remainder): Art. 3.2.2 teilt in obere Hälfte S1 und untere S2,
    /// Art. 3.3.1 paart erster gegen ersten. Die Änderungsreihenfolge steht in Art. 3.6:
    /// zuerst alle Transpositionen von S2 (Art. 4.2), dann ein Exchange zwischen S1 und S2
    /// (Art. 4.3) und wieder alle Transpositionen.
    /// </summary>
    private IEnumerable<FideDutchCandidate> GenerateHomogeneous(
        IReadOnlyList<FideDutchPlayerProfile> players,
        int pairCount)
    {
        if (pairCount == 0)
        {
            yield return new FideDutchCandidate(
                Array.Empty<(FideDutchPlayerProfile, FideDutchPlayerProfile)>(), players, 0);
            yield break;
        }

        if (pairCount * 2 > players.Count)
        {
            yield break;
        }

        var originalS1 = players.Take(pairCount).ToList();
        var originalS2 = players.Skip(pairCount).ToList();

        foreach (var (s1, s2) in EnumerateExchanges(originalS1, originalS2, players))
        {
            foreach (var selection in EnumerateTranspositions(s1, s2, players))
            {
                var pairs = s1.Zip(selection, (a, b) => (a, b)).ToList();
                var used = selection.Select(profile => profile.Player.Id).ToHashSet();
                var downfloaters = s2.Where(profile => !used.Contains(profile.Player.Id)).ToList();
                yield return new FideDutchCandidate(pairs, downfloaters, 0);
            }
        }
    }

    /// <summary>
    /// Heterogenes Bracket: Art. 3.3.2 paart M1 MDPs gegen M1 Residents (das MDP-Pairing); die
    /// übrigen Residents bilden den <b>Remainder</b>, der nach den homogenen Regeln weiterverarbeitet
    /// wird. MDPs, die nicht in S1 aufgenommen werden, sind im <b>Limbo</b> (Art. 3.2.4) und gesetzte
    /// Downfloater.
    ///
    /// Die Verschachtelung folgt Art. 3.7: außen die Menge der paarbaren MDPs (Art. 4.4), darin die
    /// Transpositionen von S2, ganz innen die Änderungen am Remainder.
    /// </summary>
    private IEnumerable<FideDutchCandidate> GenerateHeterogeneous(FideDutchBracket bracket, int pairCount)
    {
        var maxMdps = Math.Min(bracket.M0, pairCount);

        // Art. 3.7.3: zuerst so viele MDPs wie moeglich paaren; erst wenn das scheitert, waechst der
        // Limbo. [C7] bevorzugt ohnehin, die punktstaerkeren MDPs nicht abfloaten zu lassen.
        for (var m1 = maxMdps; m1 >= 0; m1--)
        {
            foreach (var mdpSet in EnumerateMdpSets(bracket.Mdps, m1))
            {
                CheckBudget();
                var limbo = bracket.Mdps.Where(mdp => !mdpSet.Contains(mdp)).ToList();
                var residents = bracket.Residents;

                foreach (var selection in EnumerateTranspositions(mdpSet, residents, bracket.Players))
                {
                    var mdpPairs = mdpSet.Zip(selection, (a, b) => (a, b)).ToList();
                    var used = selection.Select(profile => profile.Player.Id).ToHashSet();
                    var remainder = residents.Where(profile => !used.Contains(profile.Player.Id)).ToList();

                    // Der Remainder wird nach den homogenen Regeln behandelt (Art. 3.7.1).
                    // Er darf weniger Paare bilden, als rechnerisch moeglich waeren - dann floaten
                    // die uebrigen Residents ab.
                    var remainderPairs = pairCount - m1;
                    foreach (var remainderCandidate in GenerateHomogeneous(remainder, remainderPairs))
                    {
                        yield return new FideDutchCandidate(
                            Pairs: mdpPairs.Concat(remainderCandidate.Pairs).ToList(),
                            Downfloaters: limbo.Concat(remainderCandidate.Downfloaters).ToList(),
                            GenerationIndex: 0);
                    }
                }
            }
        }
    }

    /// <summary>
    /// Art. 4.4: Mengen paarbarer MDPs, sortiert nach ihrer kleinsten abweichenden BSN.
    /// Da die MDPs bereits nach Art. 1.2 geordnet sind, entspricht das den Kombinationen in
    /// lexikografischer Reihenfolge der Positionen.
    /// </summary>
    private static IEnumerable<List<FideDutchPlayerProfile>> EnumerateMdpSets(
        IReadOnlyList<FideDutchPlayerProfile> mdps,
        int size)
    {
        if (size == 0)
        {
            yield return new List<FideDutchPlayerProfile>();
            yield break;
        }

        foreach (var combination in Combinations(mdps.Count, size))
        {
            yield return combination.Select(index => mdps[index]).ToList();
        }
    }

    private static IEnumerable<int[]> Combinations(int count, int size)
    {
        if (size > count)
        {
            yield break;
        }

        var indices = Enumerable.Range(0, size).ToArray();
        while (true)
        {
            yield return (int[])indices.Clone();

            var position = size - 1;
            while (position >= 0 && indices[position] == count - size + position)
            {
                position--;
            }

            if (position < 0)
            {
                yield break;
            }

            indices[position]++;
            for (var next = position + 1; next < size; next++)
            {
                indices[next] = indices[next - 1] + 1;
            }
        }
    }

    /// <summary>
    /// Art. 4.2: Transpositionen von S2 — alle geordneten Auswahlen von |S1| Spielern aus S2,
    /// sortiert nach dem lexikografischen Wert ihrer BSNs. Da S2 bereits nach Art. 1.2 sortiert ist,
    /// entspricht die lexikografische BSN-Reihenfolge der Positionsreihenfolge.
    /// </summary>
    /// <remarks>
    /// Hier wird beschnitten: Sobald ein Paar [C1] oder [C3] verletzt, wird der ganze Teilbaum
    /// verworfen. Ohne das wäre die Zahl der Permutationen bei größeren Brackets nicht handhabbar.
    /// </remarks>
    private IEnumerable<List<FideDutchPlayerProfile>> EnumerateTranspositions(
        IReadOnlyList<FideDutchPlayerProfile> s1,
        IReadOnlyList<FideDutchPlayerProfile> s2,
        IReadOnlyList<FideDutchPlayerProfile> bracketOrder)
    {
        if (s1.Count == 0)
        {
            yield return new List<FideDutchPlayerProfile>();
            yield break;
        }

        if (s1.Count > s2.Count)
        {
            yield break;
        }

        var chosen = new List<FideDutchPlayerProfile>();
        var used = new bool[s2.Count];

        foreach (var result in Extend(0))
        {
            yield return result;
        }

        IEnumerable<List<FideDutchPlayerProfile>> Extend(int depth)
        {
            CheckBudget();
            if (depth == s1.Count)
            {
                yield return new List<FideDutchPlayerProfile>(chosen);
                yield break;
            }

            for (var index = 0; index < s2.Count; index++)
            {
                if (used[index] || !MayBePairedCached(s1[depth], s2[index]))
                {
                    continue;
                }

                used[index] = true;
                chosen.Add(s2[index]);

                foreach (var result in Extend(depth + 1))
                {
                    yield return result;
                }

                chosen.RemoveAt(chosen.Count - 1);
                used[index] = false;
            }
        }
    }

    /// <summary>
    /// Art. 4.3: Exchanges zwischen S1 und S2 — Tausch zweier gleich großer BSN-Gruppen.
    /// Sortiert nach: (1) kleinste Zahl getauschter BSNs, (2) kleinste Differenz der BSN-Summen,
    /// (3) größte abweichende BSN von S1 nach S2, (4) kleinste abweichende BSN von S2 nach S1.
    /// Der identische „Tausch" (nichts getauscht) kommt zuerst — Art. 3.6 probiert erst alle
    /// Transpositionen der ursprünglichen Aufteilung.
    /// </summary>
    private IEnumerable<(List<FideDutchPlayerProfile> S1, List<FideDutchPlayerProfile> S2)> EnumerateExchanges(
        IReadOnlyList<FideDutchPlayerProfile> originalS1,
        IReadOnlyList<FideDutchPlayerProfile> originalS2,
        IReadOnlyList<FideDutchPlayerProfile> bracketOrder)
    {
        var bsn = bracketOrder
            .Select((profile, index) => (profile.Player.Id, Bsn: index + 1))
            .ToDictionary(entry => entry.Id, entry => entry.Bsn);

        // STM-FACH-003: Bislang wurde die VOLLSTAENDIGE Exchange-Menge fuer ALLE Groessen
        // materialisiert, bevor der erste Kandidat sichtbar wurde. Bei 100/200 Spielern ist diese
        // Menge kombinatorisch riesig, obwohl Art. 3.6 zuerst den unveraenderten Split prueft und
        // dieser in der Praxis sehr haeufig sofort funktioniert. Wir erzeugen deshalb streng
        // stufenweise: Groesse 0 wird sofort geliefert; Groesse n wird erst materialisiert, wenn
        // alle kleineren Groessen wirklich gescheitert sind. Die Sortierung INNERHALB einer
        // Groesse bleibt bytegleich zur bisherigen Implementierung, also auch Art. 3.8.
        var maxSize = Math.Min(originalS1.Count, originalS2.Count);
        for (var size = 0; size <= maxSize; size++)
        {
            CheckBudget();

            if (size == 0)
            {
                yield return (originalS1.ToList(), originalS2.ToList());
                continue;
            }

            var exchanges = new List<(int SumDifference, int LargestOut, int SmallestIn, int Sequence, List<FideDutchPlayerProfile> S1, List<FideDutchPlayerProfile> S2)>();
            var sequence = 0;

            foreach (var fromS1 in Combinations(originalS1.Count, size))
            {
                CheckBudget();
                foreach (var fromS2 in Combinations(originalS2.Count, size))
                {
                    CheckBudget();

                    var outgoing = fromS1.Select(index => originalS1[index]).ToList();
                    var incoming = fromS2.Select(index => originalS2[index]).ToList();
                    var outgoingIds = outgoing.Select(profile => profile.Player.Id).ToHashSet();
                    var incomingIds = incoming.Select(profile => profile.Player.Id).ToHashSet();

                    var newS1 = originalS1
                        .Where(profile => !outgoingIds.Contains(profile.Player.Id))
                        .Concat(incoming)
                        .OrderBy(profile => bsn[profile.Player.Id])
                        .ToList();
                    var newS2 = originalS2
                        .Where(profile => !incomingIds.Contains(profile.Player.Id))
                        .Concat(outgoing)
                        .OrderBy(profile => bsn[profile.Player.Id])
                        .ToList();

                    var sumOut = outgoing.Sum(profile => bsn[profile.Player.Id]);
                    var sumIn = incoming.Sum(profile => bsn[profile.Player.Id]);

                    exchanges.Add((
                        SumDifference: Math.Abs(sumOut - sumIn),
                        LargestOut: -outgoing.Max(profile => bsn[profile.Player.Id]),
                        SmallestIn: incoming.Min(profile => bsn[profile.Player.Id]),
                        Sequence: sequence++,
                        S1: newS1,
                        S2: newS2));
                }
            }

            foreach (var exchange in exchanges
                         .OrderBy(entry => entry.SumDifference)
                         .ThenBy(entry => entry.LargestOut)
                         .ThenBy(entry => entry.SmallestIn)
                         .ThenBy(entry => entry.Sequence))
            {
                CheckBudget();
                yield return (exchange.S1, exchange.S2);
            }
        }
    }

    private bool MayBePairedCached(FideDutchPlayerProfile a, FideDutchPlayerProfile b)
    {
        var key = a.Player.Id.CompareTo(b.Player.Id) <= 0
            ? (a.Player.Id, b.Player.Id)
            : (b.Player.Id, a.Player.Id);

        if (_pairingCache.TryGetValue(key, out var allowed))
        {
            return allowed;
        }

        allowed = criteria.MayBePaired(a, b);
        _pairingCache[key] = allowed;
        return allowed;
    }

    private void CheckBudget() => _checkBudget();

}
