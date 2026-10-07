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
public sealed class FideDutchCandidateGenerator
{
    private readonly FideDutchAbsoluteCriteria _criteria;
    private readonly Dictionary<(Guid Left, Guid Right), bool> _pairingCache = new();
    private readonly Action _externalCheck;
    private readonly FideDutchSearchBudget _budget;

    public FideDutchCandidateGenerator(
        FideDutchAbsoluteCriteria criteria,
        Action? checkBudget = null,
        FideDutchSearchOptions? resourceOptions = null)
    {
        _criteria = criteria;
        _externalCheck = checkBudget ?? (() => { });
        _budget = new FideDutchSearchBudget(resourceOptions ?? FideDutchSearchOptions.Exhaustive, 0);
    }

    internal FideDutchCandidateGenerator(FideDutchAbsoluteCriteria criteria, FideDutchSearchBudget budget)
    {
        _criteria = criteria;
        _externalCheck = () => { };
        _budget = budget;
    }

    /// <summary>
    /// Alle Kandidaten des Brackets, in Erzeugungsreihenfolge. Der <c>GenerationIndex</c> zählt dabei
    /// hoch — Art. 3.8 vergleicht ihn bei Gleichstand.
    /// </summary>
    public IEnumerable<FideDutchCandidate> Generate(FideDutchBracket bracket) => GenerateCore(bracket, null);

    internal IEnumerable<FideDutchCandidate> Generate(
        FideDutchBracket bracket,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool> canImprove) =>
        GenerateCore(bracket, canImprove);

    private IEnumerable<FideDutchCandidate> GenerateCore(
        FideDutchBracket bracket,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool>? canImprove)
    {
        _budget.CheckPlayerCount(bracket.Players.Count);
        // Identität auf dichte, lokale Indizes abbilden: kein Hashverlust und keine TPN-Kollision.
        var identityById = bracket.Players.Select((profile, ordinal) => (profile.Player.Id, ordinal))
            .ToDictionary(entry => entry.Id, entry => entry.ordinal);
        var width = Math.Max(0, bracket.Players.Count - 1).ToString(System.Globalization.CultureInfo.InvariantCulture).Length;
        var index = 0;
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var retainedCharacters = 0;
        try
        {
            var maximumPairs = bracket.IsHomogeneous
                ? bracket.MaxPairsUpperBound : Math.Min(bracket.MaxPairsUpperBound, bracket.Residents.Count);
            for (var pairCount = maximumPairs; pairCount >= 0; pairCount--)
            {
                CheckBudget();
                // Verschiedene Paarzahlen können keine identische Paarung darstellen.
                seen.Clear();
                _budget.ReleaseKeyCharacters(retainedCharacters);
                retainedCharacters = 0;
                foreach (var candidate in GenerateWithPairCount(bracket, pairCount, canImprove))
                {
                    CheckBudget();
                    var maximumCharacters = checked(candidate.Pairs.Count * (2 * width + 2) +
                        candidate.Downfloaters.Count * (width + 1) + 1);
                    _budget.RetainKeyCharacters(maximumCharacters);
                    var key = KeyOf(candidate, identityById);
                    if (!seen.Add(key))
                    {
                        _budget.ReleaseKeyCharacters(maximumCharacters);
                        continue;
                    }

                    retainedCharacters += maximumCharacters;
                    _budget.Candidate();
                    yield return candidate with { GenerationIndex = index++ };
                }
            }
        }
        finally
        {
            _budget.ReleaseKeyCharacters(retainedCharacters);
        }
    }

    /// <summary>Kanonischer Schlüssel einer Paarung — unabhängig davon, über welchen Weg sie entstand.</summary>
    private static string KeyOf(FideDutchCandidate candidate, IReadOnlyDictionary<Guid, int> identityById)
    {
        static string Token(int ordinal) => ordinal.ToString(System.Globalization.CultureInfo.InvariantCulture);
        var pairs = candidate.Pairs.Select(pair =>
        {
            var left = identityById[pair.A.Player.Id];
            var right = identityById[pair.B.Player.Id];
            return left < right ? Token(left) + "-" + Token(right) : Token(right) + "-" + Token(left);
        }).OrderBy(text => text, StringComparer.Ordinal);
        var floats = candidate.Downfloaters.Select(profile => identityById[profile.Player.Id]).OrderBy(ordinal => ordinal);
        return string.Join(",", pairs) + "|" + string.Join(",", floats.Select(Token));
    }

    private IEnumerable<FideDutchCandidate> GenerateWithPairCount(
        FideDutchBracket bracket,
        int pairCount,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool>? canImprove)
    {
        return bracket.IsHomogeneous
            ? GenerateHomogeneous(bracket.Players, pairCount, canImprove, pairCount,
                Array.Empty<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>())
            : GenerateHeterogeneous(bracket, pairCount, canImprove);
    }

    /// <summary>
    /// Homogenes Bracket (oder Remainder): Art. 3.2.2 teilt in obere Hälfte S1 und untere S2,
    /// Art. 3.3.1 paart erster gegen ersten. Die Änderungsreihenfolge steht in Art. 3.6:
    /// zuerst alle Transpositionen von S2 (Art. 4.2), dann ein Exchange zwischen S1 und S2
    /// (Art. 4.3) und wieder alle Transpositionen.
    /// </summary>
    private IEnumerable<FideDutchCandidate> GenerateHomogeneous(
        IReadOnlyList<FideDutchPlayerProfile> players,
        int pairCount,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool>? canImprove,
        int totalPairCount,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> establishedPairs)
    {
        // Dieser Bound gilt für ALLE Aufteilungen und Exchanges des Remainders.
        // Eine verbesserte vollständige Lösung kann einen zuvor offenen MDP-Präfix ausschließen.
        if (canImprove is not null && !canImprove(establishedPairs, totalPairCount))
        {
            yield break;
        }

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
            foreach (var selection in EnumerateTranspositions(s1, s2, players, canImprove, totalPairCount, establishedPairs))
            {
                var pairs = s1.Zip(selection, (a, b) => (a, b)).ToList();
                var used = selection.Select(profile => profile.Player.Id).ToHashSet();
                var downfloaters = s2.Where(profile => !used.Contains(profile.Player.Id)).ToList();
                yield return new FideDutchCandidate(pairs, downfloaters, 0);
                // Nach yield hat die Strategie möglicherweise einen neuen vollständigen best.
                // Vor weiteren Transpositionen oder eager Exchange-Listen den festen Präfix
                // erneut prüfen; dessen Ausschluss gilt für den gesamten restlichen Remainder.
                if (canImprove is not null && !canImprove(establishedPairs, totalPairCount))
                {
                    yield break;
                }
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
    private IEnumerable<FideDutchCandidate> GenerateHeterogeneous(
        FideDutchBracket bracket,
        int pairCount,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool>? canImprove)
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

                foreach (var selection in EnumerateTranspositions(mdpSet, residents, bracket.Players, canImprove, pairCount,
                    Array.Empty<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>()))
                {
                    var mdpPairs = mdpSet.Zip(selection, (a, b) => (a, b)).ToList();
                    var used = selection.Select(profile => profile.Player.Id).ToHashSet();
                    var remainder = residents.Where(profile => !used.Contains(profile.Player.Id)).ToList();

                    // Der Remainder wird nach den homogenen Regeln behandelt (Art. 3.7.1).
                    // Er darf weniger Paare bilden, als rechnerisch moeglich waeren - dann floaten
                    // die uebrigen Residents ab.
                    var remainderPairs = pairCount - m1;
                    foreach (var remainderCandidate in GenerateHomogeneous(remainder, remainderPairs, canImprove, pairCount, mdpPairs))
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
    private IEnumerable<List<FideDutchPlayerProfile>> EnumerateMdpSets(
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

    private IEnumerable<int[]> Combinations(int count, int size)
    {
        if (size < 0 || size > count)
        {
            yield break;
        }

        if (size == 0)
        {
            yield return Array.Empty<int>();
            yield break;
        }

        var indices = Enumerable.Range(0, size).ToArray();
        while (true)
        {
            CheckBudget();
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
        IReadOnlyList<FideDutchPlayerProfile> bracketOrder,
        Func<IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>, int, bool>? canImprove,
        int totalPairCount,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> establishedPairs)
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
            using var recursion = _budget.EnterRecursion();
            CheckBudget();
            if (canImprove is not null)
            {
                var prefix = establishedPairs.Concat(s1.Take(depth).Zip(chosen, (a, b) => (A: a, B: b))).ToArray();
                if (!canImprove(prefix, totalPairCount))
                {
                    yield break;
                }
            }

            if (depth == s1.Count)
            {
                yield return new List<FideDutchPlayerProfile>(chosen);
                yield break;
            }

            for (var index = 0; index < s2.Count; index++)
            {
                CheckBudget();
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
        var bsn = bracketOrder.Select((profile, index) => (profile.Player.Id, Bsn: index + 1))
            .ToDictionary(entry => entry.Id, entry => entry.Bsn);

        // Die unveränderte Aufteilung muss vor jedem materialisierten Exchange erreichbar sein.
        yield return (originalS1.ToList(), originalS2.ToList());

        for (var size = 1; size <= Math.Min(originalS1.Count, originalS2.Count); size++)
        {
            var exchanges = new List<ExchangeDescriptor>();
            var retainedIndices = 0;
            try
            {
                var sequence = 0;
                foreach (var fromS1 in Combinations(originalS1.Count, size))
                {
                    foreach (var fromS2 in Combinations(originalS2.Count, size))
                    {
                        CheckBudget();
                        _budget.RetainExchange(checked(size * 2));
                        retainedIndices += size * 2;
                        // Nur kompakte Indizes behalten, keine S1/S2-Kopien pro Exchange.
                        var outgoing = fromS1.Select(index => bsn[originalS1[index].Player.Id]).ToArray();
                        var incoming = fromS2.Select(index => bsn[originalS2[index].Player.Id]).ToArray();
                        exchanges.Add(new ExchangeDescriptor(
                            outgoing, incoming,
                            Math.Abs(outgoing.Sum(value => (long)value) - incoming.Sum(value => (long)value)),
                            sequence++));
                    }
                }

                CheckBudget();
                // Der Sortiervorgang ist durch die vorher reservierte Deskriptorzahl begrenzt.
                // Keine Budgetexception im .NET-Vergleicher, die List.Sort einhüllen würde.
                exchanges.Sort(CompareExchanges);
                CheckBudget();
                foreach (var exchange in exchanges)
                {
                    CheckBudget();
                    var outgoing = exchange.Outgoing.ToHashSet();
                    var incoming = exchange.Incoming.ToHashSet();
                    var s1 = originalS1.Where(profile => !outgoing.Contains(bsn[profile.Player.Id]))
                        .Concat(originalS2.Where(profile => incoming.Contains(bsn[profile.Player.Id])))
                        .OrderBy(profile => bsn[profile.Player.Id]).ToList();
                    var s2 = originalS2.Where(profile => !incoming.Contains(bsn[profile.Player.Id]))
                        .Concat(originalS1.Where(profile => outgoing.Contains(bsn[profile.Player.Id])))
                        .OrderBy(profile => bsn[profile.Player.Id]).ToList();
                    yield return (s1, s2);
                }
            }
            finally
            {
                _budget.ReleaseExchanges(exchanges.Count, retainedIndices);
            }
        }
    }

    private sealed record ExchangeDescriptor(int[] Outgoing, int[] Incoming, long SumDifference, int Sequence);

    private static int CompareExchanges(ExchangeDescriptor left, ExchangeDescriptor right)
    {
        var comparison = left.SumDifference.CompareTo(right.SumDifference);
        if (comparison != 0)
        {
            return comparison;
        }

        // Größte ABWEICHENDE Ausgangs-BSN: vollständige Mengen absteigend vergleichen.
        for (var index = left.Outgoing.Length - 1; index >= 0; index--)
        {
            comparison = right.Outgoing[index].CompareTo(left.Outgoing[index]);
            if (comparison != 0)
            {
                return comparison;
            }
        }

        // Kleinste ABWEICHENDE Eingangs-BSN: vollständige Mengen aufsteigend vergleichen.
        for (var index = 0; index < left.Incoming.Length; index++)
        {
            comparison = left.Incoming[index].CompareTo(right.Incoming[index]);
            if (comparison != 0)
            {
                return comparison;
            }
        }

        return left.Sequence.CompareTo(right.Sequence);
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

        _budget.CachedPair();
        allowed = _criteria.MayBePaired(a, b);
        _pairingCache[key] = allowed;
        return allowed;
    }

    private void CheckBudget()
    {
        _externalCheck();
        _budget.ThrowIfExceeded();
    }

}
