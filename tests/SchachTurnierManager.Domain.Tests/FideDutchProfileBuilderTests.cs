using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Prüft <see cref="FideDutchProfileBuilder"/> gegen VERIFIZIERTE Solldaten.
///
/// Die Erwartungswerte sind nicht ausgedacht: Sie stammen aus der Checkliste, die bbpPairings 6.0.0
/// zu Golden-Turnier B nach vier Runden ausgibt (siehe docs/FIDE_DUTCH_REFERENCE.md, Abschnitt
/// „Gegenprobe"). Die Rundenverläufe werden hier direkt konstruiert — dieser Test braucht die
/// Paarungsstrategie also NICHT und läuft grün, bevor auch nur ein Bracket implementiert ist.
///
/// Das ist Absicht: Die drei Regeln, an denen FIDE-Dutch am leichtesten falsch umgesetzt wird,
/// stecken alle im Profil und lassen sich hier einzeln festnageln, statt später im Suchverfahren
/// zwischen einundzwanzig Kriterien gesucht werden zu müssen.
///
/// Verlauf Golden-Turnier B (7 Spieler, Weiß gewinnt jede Partie, jede Runde ein Freilos):
///   R1: 1-4, 5-2, 3-6, Freilos 7
///   R2: 5-1, 7-3, 2-4, Freilos 6
///   R3: 7-5, 1-3, 6-2, Freilos 4
///   R4: 6-7, 2-1, 4-5, Freilos 3
/// </summary>
public sealed class FideDutchProfileBuilderTests
{
    /// <summary>
    /// Erwartung je Startnummer: Farbfolge, Präferenz-Kurzform, Freilos-Sperre, Float der Vorrunde.
    /// Kurzform: Großbuchstabe = absolut, (Klammern) = stark, Kleinbuchstabe = mild.
    /// </summary>
    public static TheoryData<int, string, string, bool, FideFloat> ExpectedProfilesAfterFourRounds()
    {
        return new TheoryData<int, string, string, bool, FideFloat>
        {
            // Startnr, Farbfolge, Präferenz, Freilos gesperrt, Float R4
            { 1, "WBWB", "w",   false, FideFloat.Down },
            { 2, "BWBW", "b",   false, FideFloat.Up },
            { 3, "WBB",  "W",   true,  FideFloat.Down },  // Differenz -1, aber zweimal Schwarz -> ABSOLUT
            { 4, "BBW",  "(W)", true,  FideFloat.Up },
            { 5, "WWBB", "W",   false, FideFloat.Down },  // Differenz 0, aber zweimal Schwarz -> ABSOLUT
            { 6, "BWW",  "B",   true,  FideFloat.Up },    // Differenz +1, aber zweimal Weiß -> ABSOLUT
            { 7, "WWB",  "(B)", true,  FideFloat.Down }
        };
    }

    [Theory]
    [MemberData(nameof(ExpectedProfilesAfterFourRounds))]
    public void AfterFourRounds_ProfileMatchesReferenceEngineChecklist(
        int startingRank,
        string expectedColours,
        string expectedPreference,
        bool expectedByeIneligible,
        FideFloat expectedFloatLastRound)
    {
        var tournament = BuildTournamentBAfterFourRounds();

        var profile = new FideDutchProfileBuilder()
            .Build(tournament)
            .Single(entry => entry.Tpn == startingRank);

        Assert.Equal(expectedColours, Render(profile.PlayedColours));
        Assert.Equal(expectedPreference, profile.Preference.ToAuditToken());
        Assert.Equal(expectedByeIneligible, profile.IsByeIneligible);
        Assert.Equal(expectedFloatLastRound, profile.FloatLastRound);
    }

    /// <summary>
    /// C.04.3 Art. 1.2: Sortierung nach Punkten absteigend, dann Startnummer aufsteigend.
    /// Das Rating darf NICHT einfließen — es ist nach C.04.2 Art. 2.2 bereits in der Startnummer
    /// aufgegangen. Nach R4 stehen 6 und 7 bei 3.0, alle anderen bei 2.0.
    /// </summary>
    [Fact]
    public void Build_OrdersByPointsThenTpn_NotByRating_PerArticle12()
    {
        var tournament = BuildTournamentBAfterFourRounds();

        var order = new FideDutchProfileBuilder().Build(tournament).Select(profile => profile.Tpn).ToArray();

        Assert.Equal(new[] { 6, 7, 1, 2, 3, 4, 5 }, order);
    }

    /// <summary>
    /// C.04.1 Art. 3: Das Freilos bringt die volle Siegpunktzahl, aber KEINE Farbe. Spieler 7 hat
    /// nach R1 also einen Punkt und trotzdem keinerlei Farbhistorie — und damit keine Präferenz.
    /// </summary>
    [Fact]
    public void AfterOneRound_ByePlayerHasPointButNoColourAndNoPreference()
    {
        var tournament = BuildTournamentB(roundsToPlay: 1);

        var profile = new FideDutchProfileBuilder().Build(tournament).Single(entry => entry.Tpn == 7);

        Assert.Equal(1m, profile.Points);
        Assert.Empty(profile.PlayedColours);
        Assert.Equal(FideColourPreferenceStrength.None, profile.Preference.Strength);
        Assert.True(profile.IsByeIneligible);
        Assert.Equal(FideFloat.Down, profile.FloatLastRound);  // Art. 1.4.3: Freilos = Downfloat
    }

    /// <summary>
    /// C.04.2 Art. 3.4 und 3.5: Eine kampflos gewertete Runde zählt weder für die Farbfolge noch als
    /// Begegnung — die beiden dürfen später erneut gepaart werden. Wirkung bleibt nur: Wer kampflos
    /// die volle Siegpunktzahl bekommt, ist für ein Freilos gesperrt ([C2], Art. 2.1.2).
    /// </summary>
    [Fact]
    public void ForfeitedGame_CountsForPointsOnly_NotForColourSequenceOrRematchLock()
    {
        var tournament = CreateTournament(2);
        // Einzige Runde: 1 gewinnt kampflos gegen 2.
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[]
            {
                Pairing.Game(1, PlayerId(1), PlayerId(2)) with { Result = new GameResult(GameResultKind.WhiteForfeitWin) }
            },
            ResultStatus = RoundResultStatus.Complete
        });

        var profiles = new FideDutchProfileBuilder().Build(tournament);
        var winner = profiles.Single(entry => entry.Tpn == 1);
        var loser = profiles.Single(entry => entry.Tpn == 2);

        Assert.Equal(1m, winner.Points);                 // Punkt zaehlt
        Assert.Empty(winner.PlayedColours);              // Art. 3.4: keine Farbe
        Assert.Empty(loser.PlayedColours);
        Assert.Empty(winner.PlayedOpponentIds);          // Art. 3.5: gilt nicht als Begegnung
        Assert.Empty(loser.PlayedOpponentIds);
        Assert.True(winner.IsByeIneligible);             // [C2]: voller Punkt ohne zu spielen
        Assert.False(loser.IsByeIneligible);             // der Unterlegene bleibt freilosfaehig
    }

    // -------------------------------------------------------------------------------------------

    private static TournamentState BuildTournamentBAfterFourRounds() => BuildTournamentB(roundsToPlay: 4);

    private static TournamentState BuildTournamentB(int roundsToPlay)
    {
        // Verifizierter Verlauf (siehe Klassendoku). "0" als Gegner = Freilos.
        var rounds = new[]
        {
            new[] { (1, 4), (5, 2), (3, 6), (7, 0) },
            new[] { (5, 1), (7, 3), (2, 4), (6, 0) },
            new[] { (7, 5), (1, 3), (6, 2), (4, 0) },
            new[] { (6, 7), (2, 1), (4, 5), (3, 0) }
        };

        var tournament = CreateTournament(7);
        for (var index = 0; index < roundsToPlay; index++)
        {
            var board = 0;
            tournament.Rounds.Add(new TournamentRound
            {
                RoundNumber = index + 1,
                Pairings = rounds[index]
                    .Select(pair =>
                    {
                        board++;
                        return pair.Item2 == 0
                            ? Pairing.Bye(board, PlayerId(pair.Item1))
                            : Pairing.Game(board, PlayerId(pair.Item1), PlayerId(pair.Item2)) with
                            {
                                Result = new GameResult(GameResultKind.WhiteWin)
                            };
                    })
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
            Name = "FIDE Dutch Profile",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                PlannedRounds = 5
            }
        };

        for (var index = 1; index <= playerCount; index++)
        {
            tournament.Players.Add(new Player
            {
                Id = PlayerId(index),
                Name = $"Dutch Spieler {index}",
                StartingRank = index,
                Rating = new RatingProfile { ManualTwz = 2400 - index * 50 }
            });
        }

        return tournament;
    }

    private static Guid PlayerId(int startingRank) => Guid.Parse($"00000000-0000-0000-0000-{startingRank:000000000000}");

    private static string Render(IReadOnlyList<ChessColor> colours) =>
        string.Concat(colours.Select(colour => colour == ChessColor.White ? "W" : "B"));
}
