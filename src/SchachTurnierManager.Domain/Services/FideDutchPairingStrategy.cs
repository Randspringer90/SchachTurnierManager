using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

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

    public SwissPairingStrategyKind Kind => SwissPairingStrategyKind.FideDutch;

    public TournamentRound GenerateNextRound(TournamentState tournament)
    {
        var profiles = _profiles.Build(tournament);
        var criteria = FideDutchAbsoluteCriteria.ForRound(tournament, profiles);
        var colours = new FideDutchColourAllocator();
        var evaluator = new FideDutchCandidateEvaluator(criteria, colours, tournament.Settings.SwissInitialColour);
        var generator = new FideDutchCandidateGenerator(criteria);

        var groups = FideDutchScoreGroups.Build(profiles);
        var messages = new List<string>();
        var floaters = new List<string>();
        var colourNotes = new List<string>();

        WarnIfSeedingIsNotFideOrdered(profiles, messages);

        var context = new PairingContext(
            groups, criteria, evaluator, generator, tournament.Rounds.Count, floaters);

        var solution = PairFrom(context, groupIndex: 0, movedDown: Array.Empty<FideDutchPlayerProfile>());

        if (solution is null)
        {
            // Art. 1.9.3: Ist eine Rundenpaarung nicht moeglich, entscheidet der Schiedsrichter.
            // Weder abstuerzen noch stillschweigend regelwidrig paaren - den Fall sauber abgeben.
            throw new InvalidOperationException(
                "FIDE-Dutch: Für diese Runde existiert keine regelkonforme Paarung (C.04.3 Art. 1.9.3). " +
                "Die Entscheidung liegt beim Schiedsrichter — bitte manuell paaren und im Audit begründen.");
        }

        return BuildRound(tournament, solution, colours, messages, floaters, colourNotes, profiles);
    }

    /// <summary>
    /// Paart ab der angegebenen Punktgruppe abwärts. Liefert <c>null</c>, wenn der Rest der Runde
    /// mit den übergebenen Absteigern nicht regelkonform aufgeht — das ist [C4] (Art. 2.2.1).
    /// </summary>
    private static Solution? PairFrom(
        PairingContext context,
        int groupIndex,
        IReadOnlyList<FideDutchPlayerProfile> movedDown)
    {
        if (groupIndex >= context.Groups.Count)
        {
            // Keine Punktgruppe mehr da. Uebrig gebliebene Absteiger koennen nicht mehr gepaart
            // werden - hoechstens einer darf als Freilos stehen bleiben (Art. 1.9.1).
            return movedDown.Count switch
            {
                0 => Solution.Empty,
                1 when FideDutchAbsoluteCriteria.MayReceiveBye(movedDown[0]) => Solution.WithBye(movedDown[0]),
                _ => null
            };
        }

        var bracket = FideDutchScoreGroups.ToBracket(context.Groups[groupIndex], movedDown);
        var isLastGroup = groupIndex == context.Groups.Count - 1;

        // Kandidaten werden in Stufen gleicher Downfloater-Zahl abgearbeitet. Grund: [C6]
        // (Art. 2.4.1) ist das erste Qualitaetskriterium und bevorzugt IMMER weniger Downfloater.
        // Eine Stufe mit mehr Downfloatern kann also nie besser sein - sie wird nur gebraucht, wenn
        // [C4] (Art. 2.2.1) sie erzwingt, weil sonst der Rest der Runde nicht aufgeht. Deshalb wird
        // die naechste Stufe erst erzeugt, wenn die aktuelle vollstaendig gescheitert ist.
        foreach (var tier in TiersByDownfloatCount(context, bracket, isLastGroup))
        {
            foreach (var entry in tier)
            {
                // Im letzten Bracket gibt es kein "weiter unten" - der uebrig gebliebene Spieler
                // bekommt das Freilos.
                if (isLastGroup)
                {
                    RecordFloats(context, bracket, entry.Candidate);
                    return Solution.From(entry.Candidate, entry.Bye);
                }

                // [C4]/[C8]: Der Kandidat gilt nur, wenn der REST der Runde damit aufgeht.
                var rest = PairFrom(context, groupIndex + 1, entry.Candidate.Downfloaters);
                if (rest is null)
                {
                    continue;
                }

                RecordFloats(context, bracket, entry.Candidate);
                return Solution.From(entry.Candidate, byeAssignee: null).Combine(rest);
            }
        }

        return null;
    }

    /// <summary>
    /// Gruppiert die Kandidaten nach Downfloater-Zahl (aufsteigend, also [C6]-beste zuerst) und
    /// sortiert innerhalb jeder Stufe nach [C5]–[C21]; bei Gleichstand entscheidet die
    /// Erzeugungsreihenfolge (Art. 3.8). Die Stufen werden faul erzeugt.
    /// </summary>
    private static IEnumerable<List<RankedCandidate>> TiersByDownfloatCount(
        PairingContext context,
        FideDutchBracket bracket,
        bool isLastGroup)
    {
        var tier = new List<RankedCandidate>();
        var currentCount = -1;

        foreach (var candidate in context.Generator.Generate(bracket))
        {
            if (!IsLocallyViable(candidate, isLastGroup))
            {
                continue;
            }

            if (candidate.Downfloaters.Count != currentCount && tier.Count > 0)
            {
                yield return Rank(tier);
                tier = new List<RankedCandidate>();
            }

            currentCount = candidate.Downfloaters.Count;
            var bye = ByeAssigneeFor(candidate, isLastGroup);
            tier.Add(new RankedCandidate(
                candidate,
                bye,
                context.Evaluator.Evaluate(candidate, bracket, bye, context.RoundsPlayed)));
        }

        if (tier.Count > 0)
        {
            yield return Rank(tier);
        }
    }

    private static List<RankedCandidate> Rank(List<RankedCandidate> tier) =>
        tier.OrderBy(entry => entry.Score, Comparer<IReadOnlyList<decimal>>.Create(FideDutchCandidateEvaluator.Compare))
            .ThenBy(entry => entry.Candidate.GenerationIndex)
            .ToList();

    private sealed record RankedCandidate(
        FideDutchCandidate Candidate,
        FideDutchPlayerProfile? Bye,
        IReadOnlyList<decimal> Score);

    /// <summary>
    /// Kann dieser Kandidat für sich genommen stehen? Im letzten Bracket darf höchstens einer
    /// ungepaart bleiben (Art. 1.9.1), und der muss ein Freilos bekommen dürfen ([C2], Art. 2.1.2).
    /// </summary>
    private static bool IsLocallyViable(FideDutchCandidate candidate, bool isLastGroup)
    {
        if (!isLastGroup)
        {
            return true;
        }

        return candidate.Downfloaters.Count switch
        {
            0 => true,
            1 => FideDutchAbsoluteCriteria.MayReceiveBye(candidate.Downfloaters[0]),
            _ => false
        };
    }

    private static FideDutchPlayerProfile? ByeAssigneeFor(FideDutchCandidate candidate, bool isLastGroup) =>
        isLastGroup && candidate.Downfloaters.Count == 1 ? candidate.Downfloaters[0] : null;

    private static void RecordFloats(PairingContext context, FideDutchBracket bracket, FideDutchCandidate candidate)
    {
        foreach (var downfloater in candidate.Downfloaters)
        {
            context.Floaters.Add(
                $"{downfloater.Player.Name} (#{downfloater.Tpn}, {downfloater.Points} Punkte) floatet aus dem " +
                $"{(bracket.IsHomogeneous ? "homogenen" : "heterogenen")} Bracket der Punktgruppe " +
                $"{bracket.ResidentPoints} ab (C.04.3 Art. 1.4.1).");
        }
    }

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
            "Art. 3.6/3.7 und Art. 4, bewertet nach [C5]–[C21], Backtracking für [C4].");

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
        FideDutchAbsoluteCriteria Criteria,
        FideDutchCandidateEvaluator Evaluator,
        FideDutchCandidateGenerator Generator,
        int RoundsPlayed,
        List<string> Floaters);

    /// <summary>Das Ergebnis einer (Teil-)Auslosung: Paare plus höchstens ein Freilos.</summary>
    private sealed record Solution(
        IReadOnlyList<(FideDutchPlayerProfile A, FideDutchPlayerProfile B)> Pairs,
        FideDutchPlayerProfile? ByeAssignee)
    {
        public static Solution Empty { get; } = new(Array.Empty<(FideDutchPlayerProfile, FideDutchPlayerProfile)>(), null);

        public static Solution WithBye(FideDutchPlayerProfile player) =>
            new(Array.Empty<(FideDutchPlayerProfile, FideDutchPlayerProfile)>(), player);

        public static Solution From(FideDutchCandidate candidate, FideDutchPlayerProfile? byeAssignee) =>
            new(candidate.Pairs, byeAssignee);

        public Solution Combine(Solution other) =>
            new(Pairs.Concat(other.Pairs).ToList(), ByeAssignee ?? other.ByeAssignee);
    }
}
