using System.Reflection;
using System.Runtime.ExceptionServices;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Regel-Orakel nach https://handbook.fide.com/chapter/C0403202602 (abgerufen 2026-10-07).
/// Die Paarungen sind kleine, von Hand prüfbare Gegenbeispiele; Golden-Dateien bleiben unverändert.
/// </summary>
public sealed class FideDutchReviewOracleTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void RepeatedUpfloatScoreDifference_IsComparedAfterEqualHigherCriteria(bool twoRoundsBack)
    {
        var a = Profile(1, 4m);
        var b = Profile(2, 3m);
        var x = Profile(3, 2m) with
        {
            FloatLastRound = twoRoundsBack ? FideFloat.None : FideFloat.Up,
            FloatTwoRoundsBack = twoRoundsBack ? FideFloat.Up : FideFloat.None
        };
        var y = Profile(4, 2m);
        var bracket = new FideDutchBracket(new[] { a, b }, new[] { x, y });
        var evaluator = Evaluator(bracket.Players);
        var gapTwo = new FideDutchCandidate(new[] { (a, x), (b, y) }, Array.Empty<FideDutchPlayerProfile>(), 0);
        var gapOne = new FideDutchCandidate(new[] { (a, y), (b, x) }, Array.Empty<FideDutchPlayerProfile>(), 1);
        var first = evaluator.Evaluate(gapTwo, bracket);
        var second = evaluator.Evaluate(gapOne, bracket);
        var prefixLength = 2 + bracket.Players.Count;
        var c19Start = prefixLength + 9 + bracket.Mdps.Count;
        var criterionStart = twoRoundsBack ? c19Start + 2 * bracket.Mdps.Count : c19Start;

        // C15/C17 zählen jeweils denselben einen Upfloater. Erst C19/C21 unterscheidet 2 gegen 1.
        Assert.Equal(first.Take(criterionStart), second.Take(criterionStart));
        Assert.Equal(2m, first[criterionStart]);
        Assert.Equal(1m, second[criterionStart]);
        Assert.True(FideDutchCandidateEvaluator.Compare(second, first) < 0);
    }

    [Fact]
    public void C8_PrefersDownfloaterThatAllowsMorePairsInFollowingBracket()
    {
        var profiles = C8Profiles(constrained: true);
        var tournament = Tournament(profiles);
        var round = RunCore(new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive), tournament, profiles);

        // U3-V2, U3-V3 und V2-V3 sind gesperrt. U1-U2 würde U3 abfloaten:
        // Mitte dann nur U3-V1, zwei Absteiger; die Runde wäre trotzdem vollständig paarbar.
        // U1-U3 lässt U2 abfloaten: Mitte U2-V2 + V1-V3, null Absteiger. C8 entscheidet davor.
        Assert.Contains("1-3", PairKeys(profiles, round));
        Assert.DoesNotContain("1-2", PairKeys(profiles, round));
        Assert.Contains("4-6", PairKeys(profiles, round));
        Assert.Contains("7-8", PairKeys(profiles, round));
        AssertPlacedExactlyOnce(profiles, round);
        Assert.Empty(tournament.Rounds);
        Assert.Equal(1, round.Audit.Floaters.Count(line => line.StartsWith("Oracle 2 ", StringComparison.Ordinal)));
        Assert.DoesNotContain(round.Audit.Floaters, line => line.StartsWith("Oracle 3 ", StringComparison.Ordinal));
    }

    [Fact]
    public void EqualC8AndAllOtherCriteria_PreserveEarliestGenerationIndex()
    {
        var profiles = C8Profiles(constrained: false);
        var round = RunCore(new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive), Tournament(profiles), profiles);

        Assert.Contains("1-2", PairKeys(profiles, round));
        AssertPlacedExactlyOnce(profiles, round);
    }

    [Fact]
    public void C9_AppliesOnlyToExactlyOneDownfloaterWhoActuallyReceivesBye()
    {
        var profiles = new[] { Profile(1, 0m), Profile(2, 0m), Profile(3, 0m) };
        var bracket = new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(), profiles);
        var candidate = new FideDutchCandidate(new[] { (profiles[0], profiles[1]) }, new[] { profiles[2] }, 0);
        var evaluator = Evaluator(profiles);
        var c9 = 2 + profiles.Length;
        Assert.Equal(3m, evaluator.Evaluate(candidate, bracket, profiles[2], roundsPlayed: 3)[c9]);
        Assert.Equal(decimal.MinValue, evaluator.Evaluate(candidate, bracket, Profile(4, 0m), roundsPlayed: 3)[c9]);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(200)]
    public void UnavoidableColourMajority_UsesSoundBoundAndEarliestDutchSplit(int count)
    {
        var profiles = Enumerable.Range(1, count)
            .Select(tpn => Profile(tpn, 1m, new[] { ChessColor.Black })).ToArray();
        var options = FideDutchSearchOptions.Exhaustive with { MaxGeneratedCandidates = 1 };
        var round = RunCore(new FideDutchPairingStrategy(options), Tournament(profiles), profiles);
        var expected = Enumerable.Range(1, count / 2)
            .Select(tpn => $"{tpn}-{tpn + count / 2}").OrderBy(key => key, StringComparer.Ordinal).ToArray();

        // Jeder Spieler möchte Weiß, aber nur count/2 können Weiß erhalten. C12 und C13
        // müssen beide count/2 zulassen; ein pauschaler Nullvektor würde weiter suchen.
        Assert.Equal(expected, PairKeys(profiles, round));
        AssertPlacedExactlyOnce(profiles, round);
    }

    [Fact]
    public void LowerBounds_NeverExceedAnyGeneratedSmallCandidateCriterion()
    {
        for (var seed = 0; seed < 8; seed++)
        {
            foreach (var bracket in SmallBrackets(seed))
            {
                var evaluator = Evaluator(bracket.Players);
                var generator = new FideDutchCandidateGenerator(Criteria(bracket.Players));
                var seen = 0;
                foreach (var candidate in generator.Generate(bracket))
                {
                    seen++;
                    var bye = candidate.Downfloaters.Count == 1 ? candidate.Downfloaters[0] : null;
                    var score = evaluator.Evaluate(candidate, bracket, bye, roundsPlayed: 3);
                    var lower = evaluator.LowerBound(bracket, candidate.Downfloaters.Count, bye is not null, roundsPlayed: 3);
                    Assert.Equal(score.Count, lower.Count);
                    for (var index = 0; index < score.Count; index++)
                    {
                        Assert.True(lower[index] <= score[index],
                            $"seed={seed}; index={index}; lower={lower[index]}; actual={score[index]}");
                    }
                }

                Assert.True(seen > 0);
            }
        }
    }

    [Fact]
    public void PrefixLowerBounds_NeverExceedAnySmallCompletionCriterion()
    {
        for (var seed = 0; seed < 8; seed++)
        {
            foreach (var bracket in SmallBrackets(seed))
            {
                var evaluator = Evaluator(bracket.Players);
                foreach (var candidate in new FideDutchCandidateGenerator(Criteria(bracket.Players)).Generate(bracket))
                {
                    var bye = candidate.Downfloaters.Count == 1 ? candidate.Downfloaters[0] : null;
                    var score = evaluator.Evaluate(candidate, bracket, bye, roundsPlayed: 3);
                    for (var length = 0; length <= candidate.Pairs.Count; length++)
                    {
                        var lower = evaluator.LowerBound(bracket, candidate.Downfloaters.Count,
                            bye is not null, roundsPlayed: 3, pairedPrefix: candidate.Pairs.Take(length).ToArray());
                        Assert.Equal(score.Count, lower.Count);
                        for (var index = 0; index < score.Count; index++)
                        {
                            Assert.True(lower[index] <= score[index],
                                $"seed={seed}; prefix={length}; index={index}; lower={lower[index]}; actual={score[index]}");
                        }
                    }
                }
            }
        }
    }

    [Fact]
    public void PrefixPruning_PreservesWinnerOfUnprunedSmallCandidateEnumeration()
    {
        var profiles = Enumerable.Range(1, 6).Select(tpn =>
            Profile(tpn, 0m, new[] { tpn <= 3 ? ChessColor.Black : ChessColor.White })).ToArray();
        // Nur zwei verschiedene Kreuzfarben-Begegnungen sind erlaubt. Jede vollständige
        // Paarung muss ein Weißpräferenz-Paar und ein Schwarzpräferenz-Paar enthalten.
        profiles = Forbid(profiles, new[] { (1, 5), (1, 6), (2, 4), (2, 6), (3, 4), (3, 5), (3, 6) });
        var bracket = new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(), profiles);
        var evaluator = Evaluator(profiles);
        var expected = new FideDutchCandidateGenerator(Criteria(profiles)).Generate(bracket)
            .Where(candidate => candidate.Downfloaters.Count == 0)
            .OrderBy(candidate => evaluator.Evaluate(candidate, bracket),
                Comparer<IReadOnlyList<decimal>>.Create(FideDutchCandidateEvaluator.Compare))
            .ThenBy(candidate => candidate.GenerationIndex).First();
        var expectedKeys = expected.Pairs.Select(pair =>
            $"{Math.Min(pair.A.Tpn, pair.B.Tpn)}-{Math.Max(pair.A.Tpn, pair.B.Tpn)}")
            .OrderBy(key => key, StringComparer.Ordinal).ToArray();
        var options = FideDutchSearchOptions.Exhaustive with { MaxGeneratedCandidates = 2 };
        var actual = RunCore(new FideDutchPairingStrategy(options), Tournament(profiles), profiles);

        Assert.Equal(expectedKeys, PairKeys(profiles, actual));
        AssertPlacedExactlyOnce(profiles, actual);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(200)]
    public void PrefixPruning_HandlesMirroredMixedPreferencesInsideUnchangedStepLimit(int count)
    {
        var half = count / 2;
        var profiles = Enumerable.Range(1, count).Select(tpn => Profile(tpn, 1m,
            new[] { ((tpn - 1) % half + 1) % 4 == 0 ? ChessColor.White : ChessColor.Black })).ToArray();
        var options = FideDutchSearchOptions.Exhaustive with { MaxGeneratedCandidates = count / 2 + 1 };
        var round = RunCore(new FideDutchPairingStrategy(options), Tournament(profiles), profiles);
        var placed = profiles.ToDictionary(profile => profile.Player.Id);
        var candidate = new FideDutchCandidate(round.Pairings.Select(pair =>
            (A: placed[pair.WhitePlayerId!.Value], B: placed[pair.BlackPlayerId!.Value])).ToArray(),
            Array.Empty<FideDutchPlayerProfile>(), 0);
        var bracket = new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(), profiles);
        var evaluator = Evaluator(profiles);
        var score = evaluator.Evaluate(candidate, bracket);
        var lower = evaluator.LowerBound(bracket, downfloatCount: 0, hasBye: false);

        Assert.Equal(lower, score);
        AssertPlacedExactlyOnce(profiles, round);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(200)]
    public void FixedMdpPrefix_DoesNotBuildIrrelevantRemainderExchangeLists(int residentCount)
    {
        var half = residentCount / 2;
        var profiles = new[] { Profile(1, 2m, new[] { ChessColor.Black }) }
            .Concat(Enumerable.Range(2, residentCount).Select(tpn => Profile(tpn, 1m,
                new[] { tpn <= half + 1 ? ChessColor.Black : ChessColor.White })))
            .Append(Profile(residentCount + 2, 0m)).ToArray();
        // Der erste MDP-Gegner hat dieselbe starke Präferenz. Das verursacht genau eine
        // bereits feste Verweigerung. Der restliche Resident-Bracket erreicht seine relative
        // Untergrenze ohne Exchange; jede weitere Änderung derselben MDP-Paarung ist nutzlos.
        // Der erste Gegner mit Gegenpräferenz steht erst nach half solchen MDP-Auswahlen.
        var options = FideDutchSearchOptions.Exhaustive with { MaxRetainedExchanges = 1 };
        var tournament = Tournament(profiles);
        var round = RunCore(new FideDutchPairingStrategy(options), tournament, profiles);

        Assert.Contains($"1-{half + 2}", PairKeys(profiles, round));
        AssertPlacedExactlyOnce(profiles, round);
        Assert.Empty(tournament.Rounds);
        Assert.Empty(tournament.AuditJournal);
        // Die striktere Ein-Deskriptor-Grenze beweist: nutzlose Exchange-Materialisierung
        // wird vermieden; die normalen 50k/2M/4M-Produktivgrenzen bleiben unverändert.
    }

    [Fact]
    public void ExchangeOrder_UsesLargestDifferingOutgoingBsn_NotOnlyLargestBsn()
    {
        var order = Enumerable.Range(1, 13).Select(tpn => Profile(tpn, 0m)).ToArray();
        var exchanges = Exchanges(order.Take(9).ToArray(), order.Skip(9).ToArray(), order);
        var first = Array.FindIndex(exchanges, entry => Outgoing(entry, order.Take(9)).SequenceEqual(new[] { 2, 3, 8, 9 }));
        var second = Array.FindIndex(exchanges, entry => Outgoing(entry, order.Take(9)).SequenceEqual(new[] { 1, 5, 7, 9 }));

        // Gleiche Größe, Summe 22 und größtes Element 9. Die abweichende 8 schlägt die 7.
        Assert.True(first >= 0 && second >= 0);
        Assert.True(first < second);
    }

    [Fact]
    public void ExchangeOrder_UsesSmallestDifferingIncomingBsn_NotOnlySmallestBsn()
    {
        var order = Enumerable.Range(1, 10).Select(tpn => Profile(tpn, 0m)).ToArray();
        var exchanges = Exchanges(order.Take(3).ToArray(), order.Skip(3).ToArray(), order);
        var first = Array.FindIndex(exchanges, entry => Incoming(entry, order.Take(3)).SequenceEqual(new[] { 6, 7, 10 }));
        var second = Array.FindIndex(exchanges, entry => Incoming(entry, order.Take(3)).SequenceEqual(new[] { 6, 8, 9 }));

        // Gleiche Größe und Eingangssumme 23, gleicher Ausgang; die abweichende 7 schlägt die 8.
        Assert.True(first >= 0 && second >= 0);
        Assert.True(first < second);
    }

    [Theory]
    [InlineData("MaxSearchSteps")]
    [InlineData("MaxGeneratedCandidates")]
    [InlineData("MaxRetainedExchanges")]
    [InlineData("MaxRetainedExchangeIndices")]
    [InlineData("MaxRetainedKeyCharacters")]
    [InlineData("MaxMemoizedStates")]
    [InlineData("MaxCachedPairDecisions")]
    [InlineData("MaxRecursionDepth")]
    public void ExhaustiveStillEnforcesResources_WithoutReturningPartialRound(string resource)
    {
        var profiles = resource == "MaxMemoizedStates" ? C8Profiles(constrained: true) : ColourBlockedProfiles();
        var tournament = Tournament(profiles);
        var baseline = FideDutchSearchOptions.Exhaustive;
        var options = resource switch
        {
            "MaxSearchSteps" => baseline with { MaxSearchSteps = 1 },
            "MaxGeneratedCandidates" => baseline with { MaxGeneratedCandidates = 1 },
            "MaxRetainedExchanges" => baseline with { MaxRetainedExchanges = 1 },
            "MaxRetainedExchangeIndices" => baseline with { MaxRetainedExchangeIndices = 1 },
            "MaxRetainedKeyCharacters" => baseline with { MaxRetainedKeyCharacters = 1 },
            "MaxMemoizedStates" => baseline with { MaxMemoizedStates = 1 },
            "MaxCachedPairDecisions" => baseline with { MaxCachedPairDecisions = 1 },
            "MaxRecursionDepth" => baseline with { MaxRecursionDepth = 1 },
            _ => throw new ArgumentException(resource)
        };
        var exception = Assert.Throws<FideDutchPairingResourceLimitException>(
            () => RunCore(new FideDutchPairingStrategy(options), tournament, profiles));

        Assert.Equal(resource, exception.Resource);
        Assert.Contains("ohne Teilergebnis", exception.Message);
        Assert.Empty(tournament.Rounds);
        Assert.Empty(tournament.AuditJournal);
        Assert.Equal(profiles.Select(profile => profile.Player.Id), tournament.Players.Select(player => player.Id));
    }

    [Fact]
    public void CandidateLimitReachedAfterCompleteButUnprovedCandidate_StillFailsClosed()
    {
        var profiles = ColourBlockedProfiles();
        var generator = new FideDutchCandidateGenerator(Criteria(profiles));
        var firstComplete = generator.Generate(new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(), profiles))
            .First(candidate => candidate.Downfloaters.Count == 0);
        Assert.Equal(2, firstComplete.Pairs.Count); // Eine vollständige zulässige Paarung existiert.

        var options = FideDutchSearchOptions.Exhaustive with { MaxGeneratedCandidates = 1 };
        var tournament = Tournament(profiles);
        Assert.Throws<FideDutchPairingResourceLimitException>(
            () => RunCore(new FideDutchPairingStrategy(options), tournament, profiles));
        Assert.Empty(tournament.Rounds);
        Assert.Empty(tournament.AuditJournal);
    }

    [Fact]
    public void DuplicateTpn_DoesNotCollapseDistinctPairingsInGenerator()
    {
        var profiles = Enumerable.Range(1, 4).Select(tpn => Profile(tpn, 0m) with { Tpn = 1 }).ToArray();
        var bracket = new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(), profiles);
        var candidates = new FideDutchCandidateGenerator(Criteria(profiles)).Generate(bracket)
            .Where(candidate => candidate.Downfloaters.Count == 0).ToArray();
        // Vier Spieler haben genau drei verschiedene vollständige Paarungen, trotz TPN-Kollision.
        Assert.Equal(3, candidates.Length);
        Assert.Equal(new[] { 0, 1, 2 }, candidates.Select(candidate => candidate.GenerationIndex));
    }

    [Fact]
    public void PlayerLimit_IsCheckedBeforeBuildingProfiles()
    {
        var profiles = Enumerable.Range(1, 4).Select(tpn => Profile(tpn, 0m)).ToArray();
        var tournament = Tournament(profiles);
        var strategy = new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive with { MaxPlayers = 3 });
        var exception = Assert.Throws<FideDutchPairingResourceLimitException>(() => strategy.GenerateNextRound(tournament));
        Assert.Equal("MaxPlayers", exception.Resource);
        Assert.Empty(tournament.Rounds);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void InvalidResourcePolicy_IsRejected(int limit)
    {
        var tournament = Tournament(new[] { Profile(1, 0m), Profile(2, 0m) });
        var strategy = new FideDutchPairingStrategy(FideDutchSearchOptions.Exhaustive with { MaxSearchSteps = limit });
        Assert.Throws<ArgumentOutOfRangeException>(() => strategy.GenerateNextRound(tournament));
    }

    private static FideDutchPlayerProfile[] ColourBlockedProfiles()
    {
        var profiles = new[]
        {
            Profile(1, 0m, new[] { ChessColor.Black }),
            Profile(2, 0m, new[] { ChessColor.Black }),
            Profile(3, 0m, new[] { ChessColor.White }),
            Profile(4, 0m, new[] { ChessColor.White })
        };
        return Forbid(profiles, new[] { (1, 3), (1, 4), (2, 3), (2, 4) });
    }

    private static FideDutchPlayerProfile[] C8Profiles(bool constrained)
    {
        var profiles = new[]
        {
            Profile(1, 3m), Profile(2, 3m), Profile(3, 3m),
            Profile(4, 2m), Profile(5, 2m), Profile(6, 2m),
            Profile(7, 1m), Profile(8, 1m)
        };
        return constrained ? Forbid(profiles, new[] { (3, 5), (3, 6), (5, 6) }) : profiles;
    }

    private static FideDutchPlayerProfile[] Forbid(
        FideDutchPlayerProfile[] profiles, IReadOnlyList<(int A, int B)> edges)
    {
        return profiles.Select(profile => profile with
        {
            PlayedOpponentIds = edges.Where(edge => edge.A == profile.Tpn || edge.B == profile.Tpn)
                .Select(edge => profiles.Single(other => other.Tpn == (edge.A == profile.Tpn ? edge.B : edge.A)).Player.Id)
                .ToHashSet()
        }).ToArray();
    }

    private static IEnumerable<FideDutchBracket> SmallBrackets(int seed)
    {
        FideDutchPlayerProfile Make(int tpn, decimal points)
        {
            var colours = ((tpn + seed) % 3) switch
            {
                0 => Array.Empty<ChessColor>(),
                1 => new[] { ChessColor.Black },
                _ => new[] { ChessColor.Black, ChessColor.White }
            };
            return Profile(tpn, points, colours) with
            {
                FloatLastRound = (FideFloat)((tpn + seed) % 3),
                FloatTwoRoundsBack = (FideFloat)((tpn * 2 + seed) % 3)
            };
        }

        foreach (var count in new[] { 4, 5, 6 })
        {
            yield return new FideDutchBracket(Array.Empty<FideDutchPlayerProfile>(),
                Enumerable.Range(1, count).Select(tpn => Make(tpn, 1m)).ToArray());
        }

        yield return new FideDutchBracket(
            new[] { Make(1, 3m), Make(2, 2m) },
            Enumerable.Range(3, 4).Select(tpn => Make(tpn, 1m)).ToArray());
        yield return new FideDutchBracket(
            new[] { Make(1, 3m), Make(2, 3m), Make(3, 2m) },
            new[] { Make(4, 1m), Make(5, 1m) });
    }

    private static FideDutchCandidateEvaluator Evaluator(IReadOnlyList<FideDutchPlayerProfile> profiles) =>
        new(Criteria(profiles), new FideDutchColourAllocator(), ChessColor.White);

    private static FideDutchAbsoluteCriteria Criteria(IReadOnlyList<FideDutchPlayerProfile> profiles) =>
        FideDutchAbsoluteCriteria.ForRound(Tournament(profiles), profiles);

    private static TournamentState Tournament(IReadOnlyList<FideDutchPlayerProfile> profiles) =>
        new()
        {
            Name = "FIDE rule oracle",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                PlannedRounds = 5,
                SwissInitialColour = ChessColor.White
            },
            Players = profiles.Select(profile => profile.Player).ToList()
        };

    private static FideDutchPlayerProfile Profile(int tpn, decimal points, IReadOnlyList<ChessColor>? colours = null) =>
        new(
            new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{tpn:000000000000}"),
                Name = $"Oracle {tpn}",
                StartingRank = tpn
            },
            points, tpn, colours ?? Array.Empty<ChessColor>(),
            (colours ?? Array.Empty<ChessColor>()).Select((colour, index) => (colour, round: index + 1))
                .ToDictionary(entry => entry.round, entry => entry.colour),
            new HashSet<Guid>(), false, FideFloat.None, FideFloat.None);

    private static TournamentRound RunCore(
        FideDutchPairingStrategy strategy, TournamentState tournament, IReadOnlyList<FideDutchPlayerProfile> profiles)
    {
        var method = typeof(FideDutchPairingStrategy).GetMethod("GenerateNextRoundCore",
            BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(method);
        try
        {
            return (TournamentRound)method.Invoke(strategy, new object[] { tournament, profiles })!;
        }
        catch (TargetInvocationException exception) when (exception.InnerException is not null)
        {
            ExceptionDispatchInfo.Capture(exception.InnerException).Throw();
            throw;
        }
    }

    private static (List<FideDutchPlayerProfile> S1, List<FideDutchPlayerProfile> S2)[] Exchanges(
        IReadOnlyList<FideDutchPlayerProfile> s1, IReadOnlyList<FideDutchPlayerProfile> s2,
        IReadOnlyList<FideDutchPlayerProfile> order)
    {
        var generator = new FideDutchCandidateGenerator(Criteria(order));
        var method = typeof(FideDutchCandidateGenerator).GetMethod("EnumerateExchanges",
            BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(method);
        return ((IEnumerable<(List<FideDutchPlayerProfile>, List<FideDutchPlayerProfile>)>)
            method.Invoke(generator, new object[] { s1, s2, order })!).ToArray();
    }

    private static int[] Outgoing(
        (List<FideDutchPlayerProfile> S1, List<FideDutchPlayerProfile> S2) exchange,
        IEnumerable<FideDutchPlayerProfile> originalS1) =>
        originalS1.Where(profile => !exchange.S1.Contains(profile)).Select(profile => profile.Tpn).OrderBy(tpn => tpn).ToArray();

    private static int[] Incoming(
        (List<FideDutchPlayerProfile> S1, List<FideDutchPlayerProfile> S2) exchange,
        IEnumerable<FideDutchPlayerProfile> originalS1) =>
        exchange.S1.Except(originalS1).Select(profile => profile.Tpn).OrderBy(tpn => tpn).ToArray();

    private static string[] PairKeys(IReadOnlyList<FideDutchPlayerProfile> profiles, TournamentRound round)
    {
        var tpnById = profiles.ToDictionary(profile => profile.Player.Id, profile => profile.Tpn);
        return round.Pairings.Where(pair => !pair.IsBye).Select(pair =>
        {
            var a = tpnById[pair.WhitePlayerId!.Value];
            var b = tpnById[pair.BlackPlayerId!.Value];
            return $"{Math.Min(a, b)}-{Math.Max(a, b)}";
        }).OrderBy(key => key, StringComparer.Ordinal).ToArray();
    }

    private static void AssertPlacedExactlyOnce(IReadOnlyList<FideDutchPlayerProfile> profiles, TournamentRound round)
    {
        var placed = round.Pairings.SelectMany(pair => new[] { pair.WhitePlayerId, pair.BlackPlayerId })
            .Where(id => id is not null).Select(id => id!.Value).OrderBy(id => id).ToArray();
        Assert.Equal(profiles.Select(profile => profile.Player.Id).OrderBy(id => id), placed);
    }
}
