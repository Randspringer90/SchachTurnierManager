using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Laufzeitpolicy fuer die FIDE-Dutch-Suche in grossen Feldern (STM-FACH-003).
/// Die Budgets begrenzen nur die Suche; sie lockern keine fachliche Regel.
/// </summary>
public sealed record FideDutchSearchOptions
{
    public bool EnforceTimeout { get; init; } = true;
    public TimeSpan UpTo50Players { get; init; } = TimeSpan.FromSeconds(2);
    public TimeSpan UpTo100Players { get; init; } = TimeSpan.FromSeconds(10);
    public TimeSpan UpTo200Players { get; init; } = TimeSpan.FromSeconds(60);
    public TimeSpan Above200Players { get; init; } = TimeSpan.FromSeconds(120);
    public TimeSpan? TimeoutOverride { get; init; }

    public int MaxPlayers { get; init; } = 512;
    public int MaxSearchSteps { get; init; } = 2_000_000;
    public int MaxGeneratedCandidates { get; init; } = 250_000;
    public int MaxRetainedExchanges { get; init; } = 50_000;
    public int MaxRetainedExchangeIndices { get; init; } = 1_000_000;
    public int MaxRetainedKeyCharacters { get; init; } = 4_000_000;
    public int MaxMemoizedStates { get; init; } = 4_096;
    public int MaxCachedPairDecisions { get; init; } = 250_000;
    public int MaxRecursionDepth { get; init; } = 256;

    // Ausschließlich die Uhr abschalten; Arbeit, Speicher und Rekursion bleiben begrenzt.
    public static FideDutchSearchOptions Exhaustive { get; } = new() { EnforceTimeout = false };

    internal void Validate()
    {
        var values = new (string Name, int Value)[]
        {
            (nameof(MaxPlayers), MaxPlayers), (nameof(MaxSearchSteps), MaxSearchSteps),
            (nameof(MaxGeneratedCandidates), MaxGeneratedCandidates),
            (nameof(MaxRetainedExchanges), MaxRetainedExchanges),
            (nameof(MaxRetainedExchangeIndices), MaxRetainedExchangeIndices),
            (nameof(MaxRetainedKeyCharacters), MaxRetainedKeyCharacters),
            (nameof(MaxMemoizedStates), MaxMemoizedStates),
            (nameof(MaxCachedPairDecisions), MaxCachedPairDecisions),
            (nameof(MaxRecursionDepth), MaxRecursionDepth)
        };
        foreach (var (name, value) in values)
        {
            if (value <= 0)
            {
                throw new ArgumentOutOfRangeException(name, "Das Ressourcenlimit muss positiv sein.");
            }
        }

        if (MaxPlayers > 1_024)
        {
            throw new ArgumentOutOfRangeException(nameof(MaxPlayers), "Die Spielergrenze muss konservativ bleiben.");
        }

        if (MaxRecursionDepth > 512)
        {
            throw new ArgumentOutOfRangeException(nameof(MaxRecursionDepth), "Die Rekursionsgrenze muss konservativ bleiben.");
        }

        foreach (var timeout in new[] { UpTo50Players, UpTo100Players, UpTo200Players, Above200Players })
        {
            if (timeout < TimeSpan.Zero)
            {
                throw new ArgumentOutOfRangeException(nameof(UpTo50Players), "Suchbudgets dürfen nicht negativ sein.");
            }
        }
    }

    internal TimeSpan ResolveTimeout(int playerCount)
    {
        if (TimeoutOverride is { } configured)
        {
            if (configured < TimeSpan.Zero)
            {
                throw new ArgumentOutOfRangeException(nameof(TimeoutOverride), "Das Suchbudget darf nicht negativ sein.");
            }

            return configured;
        }

        return playerCount switch
        {
            <= 50 => UpTo50Players,
            <= 100 => UpTo100Players,
            <= 200 => UpTo200Players,
            _ => Above200Players
        };
    }
}

/// <summary>
/// Wird geworfen, wenn die regelkonforme Suche ihr Zeitbudget verbraucht hat.
/// Es wird bewusst kein Teilresultat zurueckgegeben.
/// </summary>
public sealed class FideDutchPairingTimeoutException : InvalidOperationException
{
    public FideDutchPairingTimeoutException(int playerCount, TimeSpan budget)
        : base(
            $"FIDE-Dutch: Das Suchbudget von {budget.TotalSeconds:0.###} s fuer {playerCount} Spieler wurde ueberschritten. " +
            "Die Auslosung wurde ohne Teilergebnis abgebrochen; es wurden keine Paarungsregeln gelockert. " +
            "Die Zeitpolicy kann explizit deaktiviert werden; Ressourcenlimits bleiben aktiv.")
    {
        PlayerCount = playerCount;
        Budget = budget;
    }

    public int PlayerCount { get; }
    public TimeSpan Budget { get; }
}

/// <summary>
/// FIDE (Dutch) System nach C.04.3, Fassung gültig ab 01.02.2026 (STM-FACH-002).
/// Regelbelege mit Artikelnummern: <c>docs/FIDE_DUTCH_REFERENCE.md</c>.
/// </summary>
/// <remarks>
/// Ablauf (Art. 1.9.2): Die Auslosung startet bei der obersten Punktgruppe und arbeitet sich
/// Bracket für Bracket nach unten. Für jedes Bracket werden Kandidaten in der vorgeschriebenen
/// Reihenfolge erzeugt (Art. 3.3/3.6/3.7, Art. 4), nach [C5]–[C21] bewertet und der beste gewählt
/// (Art. 3.8).
///
/// Der entscheidende Punkt ist das <b>Backtracking</b>: Ein Kandidat, der für sich betrachtet gut
/// aussieht, kann die restliche Runde unpaarbar machen. Das verbietet [C4] (Art. 2.2.1) — für alle
/// noch nicht gepaarten Spieler muss stets eine regelkonforme Paarung existieren. Deshalb wird jeder
/// Kandidat erst dann angenommen, wenn der REST der Runde damit auch aufgeht. Ein Verfahren, das
/// Bracket für Bracket gierig vorgeht, paart in Golden-Turnier A Runde 3 und B Runde 4 zwangsläufig
/// falsch — und merkt es nicht.
/// </remarks>
public sealed class FideDutchPairingStrategy : ISwissPairingStrategy
{
    private readonly FideDutchProfileBuilder _profiles = new();
    private readonly FideDutchSearchOptions _searchOptions;

    public FideDutchPairingStrategy()
        : this(new FideDutchSearchOptions())
    {
    }

    public FideDutchPairingStrategy(FideDutchSearchOptions searchOptions)
    {
        _searchOptions = searchOptions ?? throw new ArgumentNullException(nameof(searchOptions));
    }

    public SwissPairingStrategyKind Kind => SwissPairingStrategyKind.FideDutch;

    public TournamentRound GenerateNextRound(TournamentState tournament)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        _searchOptions.Validate();
        if (tournament.Players.Count(player => player.IsActive) > _searchOptions.MaxPlayers)
        {
            throw new FideDutchPairingResourceLimitException(nameof(_searchOptions.MaxPlayers), _searchOptions.MaxPlayers);
        }

        return GenerateNextRoundCore(tournament, _profiles.Build(tournament));
    }

    // Fachlicher Kern mit unveränderlichen Profilen. Produktionsweg und Regel-Orakel verwenden
    // dieselbe Suche; das private Test-Seam ändert weder öffentliche API noch Turnierzustand.
    private TournamentRound GenerateNextRoundCore(
        TournamentState tournament,
        IReadOnlyList<FideDutchPlayerProfile> profiles)
    {
        var search = new FideDutchSearchBudget(_searchOptions, profiles.Count);
        var criteria = FideDutchAbsoluteCriteria.ForRound(tournament, profiles);
        var colours = new FideDutchColourAllocator();
        var evaluator = new FideDutchCandidateEvaluator(criteria, colours, tournament.Settings.SwissInitialColour);
        var generator = new FideDutchCandidateGenerator(criteria, search);
        var groups = FideDutchScoreGroups.Build(profiles);
        var messages = new List<string>();
        var floaters = new List<string>();
        var colourNotes = new List<string>();
        WarnIfSeedingIsNotFideOrdered(profiles, messages);
        var context = new PairingContext(groups, evaluator, generator, tournament.Rounds.Count, search);
        var choice = groups.Count == 0 ? null :
            PairFrom(context, groupIndex: 0, movedDown: Array.Empty<FideDutchPlayerProfile>());
        if (groups.Count > 0 && choice is null)
        {
            throw new InvalidOperationException(
                "FIDE-Dutch: Für diese Runde existiert keine regelkonforme Paarung (C.04.3 Art. 1.9.3). " +
                "Die Entscheidung liegt beim Schiedsrichter — bitte manuell paaren und im Audit begründen.");
        }

        // Nur die endgültige, vollständig bewiesene Kette trägt zum Audit und Resultat bei.
        var pairs = new List<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>();
        for (var selected = choice; selected is not null; selected = selected.Next)
        {
            pairs.AddRange(selected.Candidate.Pairs);
            foreach (var downfloater in selected.Candidate.Downfloaters)
            {
                floaters.Add(
                    $"{downfloater.Player.Name} (#{downfloater.Tpn}, {downfloater.Points} Punkte) floatet aus dem " +
                    $"{(selected.Bracket.IsHomogeneous ? "homogenen" : "heterogenen")} Bracket der Punktgruppe " +
                    $"{selected.Bracket.ResidentPoints} ab (C.04.3 Art. 1.4.1).");
            }
        }

        search.ThrowIfExceeded();
        var round = BuildRound(tournament, new Solution(pairs, choice?.Bye), colours, messages, floaters, colourNotes, profiles);
        search.ThrowIfExceeded();
        return round;
    }

    private static CompletedChoice? PairFrom(
        PairingContext context,
        int groupIndex,
        IReadOnlyList<FideDutchPlayerProfile> movedDown)
    {
        using var recursion = context.Search.EnterRecursion();
        context.Search.ThrowIfExceeded();
        // Ein Zustand hängt ausschließlich von Punktgruppe und MDP-Menge ab; Profile und
        // Absolutkriterien bleiben für die gesamte Runde unverändert. Auch unmögliche Reste merken.
        var keyCharacters = checked(12 + movedDown.Count * 33);
        context.Search.RetainKeyCharacters(keyCharacters);
        var key = groupIndex + ":" + string.Join(",", movedDown.Select(profile => profile.Player.Id.ToString("N"))
            .OrderBy(id => id, StringComparer.Ordinal));
        if (context.Memo.TryGetValue(key, out var remembered))
        {
            context.Search.ReleaseKeyCharacters(keyCharacters);
            return remembered;
        }

        context.Search.MemoState();
        var bracket = FideDutchScoreGroups.ToBracket(context.Groups[groupIndex], movedDown);
        var isLast = groupIndex == context.Groups.Count - 1;
        var minimumDown = MinimumDownfloaterCount(bracket);
        var remaining = bracket.Players.Concat(context.Groups.Skip(groupIndex + 1).SelectMany(group => group)).ToArray();
        var eligible = remaining.Where(FideDutchAbsoluteCriteria.MayReceiveBye).ToArray();
        var needsBye = remaining.Length % 2 != 0;
        var minimumByePoints = needsBye && eligible.Length > 0
            ? eligible.Min(profile => profile.Points) : decimal.MinValue;
        var lowerBound = CompleteLowerBound(context, groupIndex, bracket, minimumDown, minimumByePoints, isLast);
        CompletedChoice? best = null;

        bool CanImprove(IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> prefix, int pairCount)
        {
            var downCount = bracket.Players.Count - 2 * pairCount;
            // C6-Stufen bleiben bis zum ersten vollständigen Kandidaten sichtbar. Budgetabbrüche
            // werden nicht umgangen; die äußere Suche entscheidet über den Stufenwechsel.
            if (best is null || downCount != best.Candidate.Downfloaters.Count)
            {
                return true;
            }

            var partialLower = CompleteLowerBound(context, groupIndex, bracket, downCount,
                minimumByePoints, isLast, prefix);
            // Ein Präfix kann nur später als der bereits vollständig geprüfte best-Kandidat
            // erzeugt werden. Gleichstand kann daher gemäß Art. 3.8 ebenfalls verworfen werden.
            return FideDutchCandidateEvaluator.Compare(partialLower, best.Score) < 0;
        }

        foreach (var candidate in context.Generator.Generate(bracket, CanImprove))
        {
            context.Search.ThrowIfExceeded();
            // Nach vollständiger Prüfung einer C6-Stufe sind spätere Stufen schlechter,
            // sofern das bessere C5 bereits seine rundenweite sichere Untergrenze erreicht.
            if (best is not null && best.Score[0] == minimumByePoints &&
                candidate.Downfloaters.Count > best.Candidate.Downfloaters.Count)
            {
                break;
            }

            if (isLast && (candidate.Downfloaters.Count > 1 ||
                candidate.Downfloaters.Count == 1 && !FideDutchAbsoluteCriteria.MayReceiveBye(candidate.Downfloaters[0])))
            {
                continue;
            }

            var next = isLast ? null : PairFrom(context, groupIndex + 1, candidate.Downfloaters);
            if (!isLast && next is null)
            {
                continue; // C4: keine vollständige zulässige Rundenpaarung.
            }

            var bye = isLast
                ? candidate.Downfloaters.SingleOrDefault()
                : next!.Bye;
            var local = context.Evaluator.Evaluate(candidate, bracket, bye, context.RoundsPlayed);
            var prefixLength = 2 + bracket.Players.Count;
            var headPrefix = local.Take(prefixLength).ToArray(); // C5-C7
            // C8 steht VOR C9: der C5-C7-Vektor der tatsächlich vollständigen Folgepaarung.
            var score = headPrefix.Concat(next?.HeadPrefix ?? Array.Empty<decimal>())
                .Concat(local.Skip(prefixLength)).ToArray();
            var choice = new CompletedChoice(candidate, bracket, bye, headPrefix, score, next);
            if (best is null || FideDutchCandidateEvaluator.Compare(score, best.Score) < 0 ||
                FideDutchCandidateEvaluator.Compare(score, best.Score) == 0 &&
                candidate.GenerationIndex < best.Candidate.GenerationIndex)
            {
                best = choice;
            }

            // Nur eine bewiesene Untergrenze des GESAMTEN Vergleichsvektors gestattet Abkürzen.
            // C8 wird niemals aufgrund eines rein lokalen Nullvektors übergangen.
            if (FideDutchCandidateEvaluator.Compare(best.Score, lowerBound) == 0)
            {
                break;
            }
        }

        context.Search.ThrowIfExceeded();
        context.Memo.Add(key, best);
        return best;
    }

    private static int MinimumDownfloaterCount(FideDutchBracket bracket) =>
        bracket.IsHomogeneous ? bracket.Players.Count % 2 :
            Math.Max(bracket.Players.Count % 2, bracket.Mdps.Count - bracket.Residents.Count);

    private static IReadOnlyList<decimal> CompleteLowerBound(
        PairingContext context,
        int groupIndex,
        FideDutchBracket bracket,
        int minimumDown,
        decimal minimumByePoints,
        bool isLast,
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)>? pairedPrefix = null)
    {
        var local = context.Evaluator.LowerBound(bracket, minimumDown, isLast && minimumDown == 1,
            context.RoundsPlayed, pairedPrefix).ToArray();
        local[0] = minimumByePoints;
        var prefixLength = 2 + bracket.Players.Count;
        if (isLast)
        {
            return local;
        }

        // Beim Nicht-Endbracket kann der einzelne Downfloater später gepaart werden:
        // C9 darf dort nicht als zwingend aktiv angenommen werden.
        local[prefixLength] = decimal.MinValue;
        var nextResidents = context.Groups[groupIndex + 1];
        var nextCount = nextResidents.Count + minimumDown;
        var nextDown = Math.Max(nextCount % 2, minimumDown - nextResidents.Count);
        var nextPrefix = new List<decimal> { minimumByePoints, nextDown };
        // Jeder mögliche nächste Spieler stammt aus dieser Obermenge. Deren kleinste Werte
        // können den tatsächlichen C7-Vektor nur unterschreiten, nie überschreiten.
        nextPrefix.AddRange(bracket.Players.Concat(nextResidents).Select(profile => profile.Points)
            .OrderBy(points => points).Take(nextDown).OrderByDescending(points => points));
        for (var index = nextDown; index < nextCount; index++)
        {
            nextPrefix.Add(decimal.MinValue);
        }

        return local.Take(prefixLength).Concat(nextPrefix).Concat(local.Skip(prefixLength)).ToArray();
    }

    private sealed record CompletedChoice(
        FideDutchCandidate Candidate,
        FideDutchBracket Bracket,
        FideDutchPlayerProfile? Bye,
        IReadOnlyList<decimal> HeadPrefix,
        IReadOnlyList<decimal> Score,
        CompletedChoice? Next);

    /// <summary>
    /// C.04.2 Art. 2.2–2.3 verlangt Startnummern nach Spielstärke. Die App vergibt sie bislang in
    /// Eingabereihenfolge — die Auslosung ist dann zwar deterministisch, aber nicht FIDE-konform.
    /// Die Strategie nummeriert NICHT selbst um: Eine intern abweichende Nummerierung würde
    /// C.04.1 Art. 9 (Erklärbarkeit) verletzen. Stattdessen wird gewarnt.
    /// </summary>
    private static void WarnIfSeedingIsNotFideOrdered(
        IReadOnlyList<FideDutchPlayerProfile> profiles,
        List<string> messages)
    {
        var byTpn = profiles.OrderBy(profile => profile.Tpn).ToList();
        var isOrdered = byTpn
            .Zip(byTpn.Skip(1), (earlier, later) => earlier.Player.Twz(TwzSource.ManualThenDwzThenElo) >= later.Player.Twz(TwzSource.ManualThenDwzThenElo))
            .All(ordered => ordered);

        if (!isOrdered)
        {
            messages.Add(
                "WARNUNG: Die Startliste ist nicht nach Spielstärke sortiert (C.04.2 Art. 2.2–2.3). " +
                "Die Auslosung ist deterministisch und in sich regelkonform, aber die Startnummern " +
                "entsprechen nicht der FIDE-Vorgabe. Startliste vor dem Turnier neu nummerieren.");
        }
    }

    private static TournamentRound BuildRound(
        TournamentState tournament,
        Solution solution,
        FideDutchColourAllocator colours,
        List<string> messages,
        List<string> floaters,
        List<string> colourNotes,
        IReadOnlyList<FideDutchPlayerProfile> profiles)
    {
        var pairings = new List<Pairing>();

        // Farben zuteilen (Art. 5) und Bretter sortieren (C.04.2 Art. 3.6: hoechste Punktzahl im
        // Paar, dann Punktsumme, dann niedrigste Startnummer).
        var allocations = solution.Pairs
            .Select(pair => colours.Allocate(pair.A, pair.B, tournament.Settings.SwissInitialColour))
            .OrderByDescending(allocation => Math.Max(allocation.White.Points, allocation.Black.Points))
            .ThenByDescending(allocation => allocation.White.Points + allocation.Black.Points)
            .ThenBy(allocation => Math.Min(allocation.White.Tpn, allocation.Black.Tpn))
            .ToList();

        var board = 1;
        foreach (var allocation in allocations)
        {
            colourNotes.Add($"Brett {board}: {allocation.Reason} [{allocation.AppliedRule}]");
            pairings.Add(Pairing.Game(board, allocation.White.Player.Id, allocation.Black.Player.Id) with
            {
                Notes = $"Punkte {allocation.White.Points}-{allocation.Black.Points}; {allocation.Reason} [{allocation.AppliedRule}]"
            });
            board++;
        }

        if (solution.ByeAssignee is { } bye)
        {
            pairings.Add(Pairing.Bye(board, bye.Player.Id) with
            {
                Notes = $"Freilos (C.04.1 Art. 3): {bye.Player.Name} (#{bye.Tpn}), {bye.Points} Punkte. " +
                        "Niedrigste Punktzahl unter den freilosberechtigten Spielern ([C5], C.04.3 Art. 2.3.1)."
            });
            messages.Add($"Freilos an {bye.Player.Name} (#{bye.Tpn}, {bye.Points} Punkte) — [C5] C.04.3 Art. 2.3.1.");
        }

        messages.Insert(0,
            "FIDE (Dutch) System nach C.04.3 in der ab 01.02.2026 gültigen Fassung. Bracket-Paarung " +
            "von der obersten Punktgruppe abwärts (Art. 1.9.2), Kandidaten in der Reihenfolge nach " +
            "Art. 3.6/3.7 und Art. 4, bewertet nach [C5]–[C21], Backtracking für [C4] und Vergleich des Folgebrackets für [C8].");

        return new TournamentRound
        {
            RoundNumber = tournament.Rounds.Count + 1,
            Pairings = pairings,
            Audit = new PairingAudit
            {
                Algorithm = "Swiss-FIDE-Dutch-C0403",
                RulesetVersion = "FIDE-C.04.3-2026-02-01",
                Messages = messages,
                ScoreGroups = FideDutchScoreGroups.Build(profiles)
                    .Select(group => $"Punktgruppe {group[0].Points}: " +
                                     string.Join(", ", group.Select(profile => $"#{profile.Tpn} {profile.Player.Name}")))
                    .ToList(),
                Floaters = floaters,
                ColorNotes = colourNotes
            }
        };
    }

    private sealed record PairingContext(
        IReadOnlyList<IReadOnlyList<FideDutchPlayerProfile>> Groups,
        FideDutchCandidateEvaluator Evaluator,
        FideDutchCandidateGenerator Generator,
        int RoundsPlayed,
        FideDutchSearchBudget Search)
    {
        public Dictionary<string, CompletedChoice?> Memo { get; } = new(StringComparer.Ordinal);
    }

    /// <summary>Vollständige Rundenpaarung. Wird erst nach Abschluss aller Nachweise erzeugt.</summary>
    private sealed record Solution(
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> Pairs,
        FideDutchPlayerProfile? ByeAssignee);
}
