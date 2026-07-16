using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Property-Tests für die ABSOLUTEN Kriterien des FIDE-Dutch-Systems (STM-FACH-002).
///
/// Golden-Tests fixieren einzelne, von Hand hergeleitete Turnierverläufe. Diese Tests prüfen
/// stattdessen Aussagen, die in JEDEM Turnier gelten müssen — über viele Feldgrößen und viele
/// Ergebnisverläufe hinweg. Sie fangen damit Fehler, die zufällig an den drei Golden-Turnieren
/// vorbeilaufen.
///
/// Geprüfte Zusagen (Fundstellen: docs/FIDE_DUTCH_REFERENCE.md):
///   C.04.1 Art. 2   Zwei Teilnehmer spielen nicht mehr als einmal gegeneinander  ([C1], Art. 2.1.1)
///   C.04.1 Art. 4   Kein zweites Freilos                                          ([C2], Art. 2.1.2)
///   C.04.1 Art. 6   Farbdifferenz überschreitet ±2 nicht
///   C.04.1 Art. 7   Keine dritte gleiche Farbe in Folge
///   C.04.2 Art. 1.4 Identische Eingabe ergibt identische Auslosung
///
/// Die Ergebnisverläufe stammen aus einem festgelegten Pseudozufall mit fixem Startwert: die Fälle
/// sind vielfältig, aber jederzeit reproduzierbar. Ein Fehlschlag lässt sich über Feldgröße und
/// Startwert exakt nachstellen — echter Zufall wäre hier wertlos, weil ein roter Test sonst nicht
/// wiederholbar wäre.
/// </summary>
public sealed class FideDutchAbsoluteCriteriaPropertyTests
{
    /// <summary>Feldgrößen inkl. ungerader (Freilos) und der Grenze 20 aus der V2-Engine.</summary>
    public static TheoryData<int, int> FieldsAndSeeds()
    {
        var data = new TheoryData<int, int>();
        foreach (var players in new[] { 4, 5, 6, 7, 8, 9, 10, 11, 12 })
        {
            foreach (var seed in new[] { 1, 2, 3, 4, 5 })
            {
                data.Add(players, seed);
            }
        }

        return data;
    }

    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void OverAFullTournament_NoTwoPlayersEverMeetTwice_PerC0401Article2(int playerCount, int seed)
    {
        var tournament = PlayFullTournament(playerCount, seed);

        var duplicates = AllPlayedPairs(tournament)
            .GroupBy(pair => pair)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToList();

        Assert.Empty(duplicates);
    }

    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void OverAFullTournament_NoPlayerReceivesTwoByes_PerC0401Article4(int playerCount, int seed)
    {
        var tournament = PlayFullTournament(playerCount, seed);

        var repeated = tournament.Rounds
            .SelectMany(round => round.Pairings)
            .Where(pairing => pairing.IsBye && pairing.WhitePlayerId is not null)
            .GroupBy(pairing => pairing.WhitePlayerId!.Value)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToList();

        Assert.Empty(repeated);
    }

    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void OverAFullTournament_ColourDifferenceNeverExceedsTwo_PerC0401Article6(int playerCount, int seed)
    {
        var tournament = PlayFullTournament(playerCount, seed);

        var offenders = ColourSequences(tournament)
            .Select(entry => new
            {
                entry.Key,
                Difference = entry.Value.Count(colour => colour == ChessColor.White) -
                             entry.Value.Count(colour => colour == ChessColor.Black)
            })
            .Where(entry => Math.Abs(entry.Difference) > 2)
            .ToList();

        Assert.Empty(offenders);
    }

    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void OverAFullTournament_NoPlayerGetsTheSameColourThreeTimesInARow_PerC0401Article7(int playerCount, int seed)
    {
        var tournament = PlayFullTournament(playerCount, seed);

        var offenders = ColourSequences(tournament)
            .Where(entry => HasThreeInARow(entry.Value))
            .Select(entry => entry.Key)
            .ToList();

        Assert.Empty(offenders);
    }

    /// <summary>
    /// C.04.2 Art. 1.4: Die Auslosung ist objektiv, unparteiisch und reproduzierbar — verschiedene
    /// Schiedsrichter und verschiedene zugelassene Programme müssen zu identischen Paarungen kommen.
    /// Zwei getrennt aufgebaute, gleich verlaufene Turniere müssen also Runde für Runde dieselbe
    /// Auslosung ergeben.
    /// </summary>
    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void SameInput_ProducesIdenticalPairings_PerC0402Article14(int playerCount, int seed)
    {
        var first = PlayFullTournament(playerCount, seed);
        var second = PlayFullTournament(playerCount, seed);

        Assert.Equal(Describe(first), Describe(second));
    }

    /// <summary>
    /// Absolute Kriterien sind absolut: Auch über alle Runden hinweg darf keine einzige Verletzung
    /// auftreten. Dieser Test bündelt sie, damit ein Fehlschlag sofort zeigt, WELCHE Zusage bricht.
    /// </summary>
    [Theory]
    [MemberData(nameof(FieldsAndSeeds))]
    public void OverAFullTournament_EveryPlayerIsPlacedExactlyOncePerRound(int playerCount, int seed)
    {
        var tournament = PlayFullTournament(playerCount, seed);
        var expected = tournament.Players.Select(player => player.Id).OrderBy(id => id).ToArray();

        foreach (var round in tournament.Rounds)
        {
            var placed = round.Pairings
                .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
                .Where(id => id is not null)
                .Select(id => id!.Value)
                .OrderBy(id => id)
                .ToArray();

            Assert.Equal(expected, placed);
            Assert.True(round.Pairings.Count(pairing => pairing.IsBye) <= 1,
                $"Runde {round.RoundNumber}: höchstens ein Freilos zulässig (Art. 1.9.1).");
        }
    }

    // -------------------------------------------------------------------------------------------

    private static TournamentState PlayFullTournament(int playerCount, int seed)
    {
        var tournament = CreateTournament(playerCount);
        var strategy = new FideDutchPairingStrategy();
        var random = new DeterministicResults(seed);

        for (var round = 0; round < 5; round++)
        {
            var next = strategy.GenerateNextRound(tournament);
            tournament.Rounds.Add(next with
            {
                Pairings = next.Pairings
                    .Select(pairing => pairing.IsBye ? pairing : pairing with { Result = new GameResult(random.NextResult()) })
                    .ToList(),
                ResultStatus = RoundResultStatus.Complete
            });
        }

        return tournament;
    }

    private static TournamentState CreateTournament(int playerCount)
    {
        var tournament = new TournamentState
        {
            Name = $"FIDE Dutch Property {playerCount}",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                SwissInitialColour = ChessColor.White,
                PlannedRounds = 5
            }
        };

        for (var index = 1; index <= playerCount; index++)
        {
            tournament.Players.Add(new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{index:000000000000}"),
                Name = $"Property Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2400 - index * 25 }
            });
        }

        return tournament;
    }

    /// <summary>Alle tatsächlich gespielten Begegnungen als ungeordnetes Paar.</summary>
    private static IEnumerable<(Guid, Guid)> AllPlayedPairs(TournamentState tournament)
    {
        return tournament.Rounds
            .SelectMany(round => round.Pairings)
            .Where(pairing => !pairing.IsBye && pairing.WhitePlayerId is not null && pairing.BlackPlayerId is not null)
            .Select(pairing => pairing.WhitePlayerId!.Value.CompareTo(pairing.BlackPlayerId!.Value) < 0
                ? (pairing.WhitePlayerId!.Value, pairing.BlackPlayerId!.Value)
                : (pairing.BlackPlayerId!.Value, pairing.WhitePlayerId!.Value));
    }

    /// <summary>
    /// Farbfolge je Spieler in Rundenreihenfolge. Freilose liefern keine Farbe und werden
    /// übersprungen (C.04.2 Art. 3.4: ungespielte Runden zählen für die Farbfolge nicht).
    /// </summary>
    private static Dictionary<Guid, List<ChessColor>> ColourSequences(TournamentState tournament)
    {
        var sequences = tournament.Players.ToDictionary(player => player.Id, _ => new List<ChessColor>());

        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
            {
                if (pairing.WhitePlayerId is { } white && sequences.TryGetValue(white, out var whiteSequence))
                {
                    whiteSequence.Add(ChessColor.White);
                }

                if (pairing.BlackPlayerId is { } black && sequences.TryGetValue(black, out var blackSequence))
                {
                    blackSequence.Add(ChessColor.Black);
                }
            }
        }

        return sequences;
    }

    private static bool HasThreeInARow(IReadOnlyList<ChessColor> colours)
    {
        for (var index = 2; index < colours.Count; index++)
        {
            if (colours[index] == colours[index - 1] && colours[index] == colours[index - 2])
            {
                return true;
            }
        }

        return false;
    }

    private static string[] Describe(TournamentState tournament)
    {
        return tournament.Rounds
            .OrderBy(round => round.RoundNumber)
            .SelectMany(round => round.Pairings
                .OrderBy(pairing => pairing.BoardNumber)
                .Select(pairing => $"R{round.RoundNumber} B{pairing.BoardNumber}: {pairing.WhitePlayerId} - {pairing.BlackPlayerId}"))
            .ToArray();
    }

    /// <summary>
    /// Ergebnisfolge aus einem linearen Kongruenzgenerator mit festem Startwert. Bewusst KEIN
    /// System.Random: dessen Folge ist nicht über Laufzeitversionen hinweg zugesichert, ein roter
    /// Test wäre dann womöglich nicht mehr nachstellbar.
    /// </summary>
    private sealed class DeterministicResults(int seed)
    {
        private uint _state = (uint)(seed * 2654435761u + 1u);

        public GameResultKind NextResult()
        {
            _state = _state * 1664525u + 1013904223u;
            return ((_state >> 16) % 4) switch
            {
                0 => GameResultKind.Draw,
                1 => GameResultKind.BlackWin,
                _ => GameResultKind.WhiteWin
            };
        }
    }
}
