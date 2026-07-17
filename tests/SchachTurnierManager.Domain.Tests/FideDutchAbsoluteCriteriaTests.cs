using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Prüft <see cref="FideDutchAbsoluteCriteria"/> ([C1]–[C3], Art. 2.1) und die Topscorer-Regel
/// (Art. 1.8) an den Stellen, die in den Golden-Turnieren tatsächlich den Ausschlag gaben.
/// Regelbelege: docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
public sealed class FideDutchAbsoluteCriteriaTests
{
    /// <summary>
    /// Art. 1.8: Topscorer gibt es NUR bei der Auslosung der Schlussrunde. In Runde 3 von 5 ist
    /// niemand Topscorer — auch der Tabellenführer nicht. Das ist der Grund, warum [C3] in
    /// Golden-Turnier A Runde 3 die Spitzengruppe {6,8} komplett sperrt.
    /// </summary>
    [Theory]
    [InlineData(1, false)]
    [InlineData(2, false)]
    [InlineData(3, false)]
    [InlineData(4, true)]   // 4 gespielte Runden -> Runde 5 ist die Schlussrunde
    public void Topscorers_ExistOnlyWhenPairingTheFinalRound(int roundsPlayed, bool expectTopscorers)
    {
        var tournament = CreateTournament(plannedRounds: 5, roundsPlayed: roundsPlayed);
        var profiles = new[] { Profile(1, points: roundsPlayed), Profile(2, points: 0) };

        var criteria = FideDutchAbsoluteCriteria.ForRound(tournament, profiles);

        Assert.Equal(expectTopscorers, criteria.IsFinalRound);
        Assert.Equal(expectTopscorers, criteria.IsTopscorer(profiles[0]));
    }

    /// <summary>
    /// Art. 1.8: „über 50 % der maximal möglichen Punktzahl" ist ECHT größer. Nach vier Runden liegt
    /// die Schwelle bei 2.0 — wer genau 2.0 hat, ist kein Topscorer. In Golden-Turnier A Runde 5
    /// sind daher nur 3 und 8 (je 3.0) Topscorer, die vier Spieler mit 2.0 nicht.
    /// </summary>
    [Theory]
    [InlineData(3.0, true)]
    [InlineData(2.5, true)]
    [InlineData(2.0, false)]   // exakt 50 % reicht NICHT
    [InlineData(1.5, false)]
    public void Topscorers_RequireStrictlyMoreThanHalf(double points, bool expected)
    {
        var tournament = CreateTournament(plannedRounds: 5, roundsPlayed: 4);
        var profile = Profile(1, points: (decimal)points);

        var criteria = FideDutchAbsoluteCriteria.ForRound(tournament, new[] { profile });

        Assert.Equal(2.0m, criteria.TopscorerThreshold);
        Assert.Equal(expected, criteria.IsTopscorer(profile));
    }

    /// <summary>
    /// [C3] sperrt nur, wenn BEIDE Präferenzen absolut sind UND dieselbe Farbe meinen UND beide
    /// Nicht-Topscorer sind. Die Fälle stammen aus den Golden-Turnieren.
    /// </summary>
    [Theory]
    // Turnier A R3: 6 (WW) und 8 (WW) - beide absolut Schwarz, keine Topscorer -> GESPERRT.
    [InlineData("WW", "WW", false, true, "A R3: Spitzengruppe 6-8")]
    // Turnier A R3: 5 (BB) und 7 (BB) - beide absolut Weiß -> GESPERRT. Das erzwingt die Doppelfloats.
    [InlineData("BB", "BB", false, true, "A R3: Schlussgruppe 5-7")]
    // Turnier C R3: 6 (nur W, kampflose Runde zählt nicht) ist STARK, 8 (WW) absolut -> erlaubt.
    [InlineData("W", "WW", false, false, "C R3: 6-8 wird gepaart, weil 6 nur stark ist")]
    // Absolut Weiß gegen absolut Schwarz: verschiedene Farben -> erlaubt, Art. 5.2.1 erfüllt beide.
    [InlineData("BB", "WW", false, false, "gegenläufige absolute Präferenzen")]
    // Turnier A R5: 3 und 8 sind beide absolut Schwarz, aber TOPSCORER -> [C3] greift nicht.
    [InlineData("WBWW", "WWBW", true, false, "A R5: Topscorer sind ausgenommen")]
    public void IsForbiddenByColour_OnlyWhenBothAbsoluteSameColourAndNeitherIsTopscorer(
        string firstColours,
        string secondColours,
        bool bothAreTopscorers,
        bool expectedForbidden,
        string origin)
    {
        var first = Profile(1, points: 0, colours: firstColours);
        var second = Profile(2, points: 0, colours: secondColours);
        var criteria = bothAreTopscorers
            ? TopscorerCriteriaFor(first, second)
            : FideDutchAbsoluteCriteria.ForRound(CreateTournament(5, 2), new[] { first, second });

        Assert.Equal(expectedForbidden, criteria.IsForbiddenByColour(first, second));
        Assert.Equal(expectedForbidden, !criteria.MayBePaired(first, second));
        Assert.Equal(expectedForbidden, criteria.ExplainRejection(first, second) is not null);
    }

    /// <summary>
    /// [C1] stützt sich auf tatsächlich GESPIELTE Partien. Eine kampflos gewertete Begegnung sperrt
    /// nicht — C.04.2 Art. 3.5 erlaubt die spätere Paarung ausdrücklich. Das ist der Grund, warum in
    /// Golden-Turnier C die Spieler 1 und 6 nach dem kampflosen Brett wieder paarbar sind.
    /// </summary>
    [Fact]
    public void WouldBeRematch_IgnoresPairingsThatWereNeverPlayed_PerArticle35()
    {
        var opponent = Profile(2, points: 0);
        var playedAgainst = Profile(1, points: 0, opponentIds: new[] { opponent.Player.Id });
        var neverPlayed = Profile(1, points: 0);

        Assert.True(FideDutchAbsoluteCriteria.WouldBeRematch(playedAgainst, opponent));
        Assert.False(FideDutchAbsoluteCriteria.WouldBeRematch(neverPlayed, opponent));
    }

    /// <summary>[C2] (Art. 2.1.2) / C.04.1 Art. 4.</summary>
    [Fact]
    public void MayReceiveBye_IsFalseOncePlayerGotFullPointWithoutPlaying()
    {
        Assert.True(FideDutchAbsoluteCriteria.MayReceiveBye(Profile(1, points: 0)));
        Assert.False(FideDutchAbsoluteCriteria.MayReceiveBye(Profile(1, points: 0, byeIneligible: true)));
    }

    /// <summary>Die Begründung muss die Fundstelle nennen — sonst ist die Auslosung nicht erklärbar
    /// (C.04.1 Art. 9).</summary>
    [Fact]
    public void ExplainRejection_NamesTheArticleThatBlocks()
    {
        var criteria = FideDutchAbsoluteCriteria.ForRound(CreateTournament(5, 2), Array.Empty<FideDutchPlayerProfile>());
        var opponent = Profile(2, points: 0, colours: "WW");
        var rematch = Profile(1, points: 0, colours: "BW", opponentIds: new[] { opponent.Player.Id });
        var colourClash = Profile(1, points: 0, colours: "WW");

        Assert.Contains("[C1]", criteria.ExplainRejection(rematch, opponent));
        Assert.Contains("Art. 2.1.1", criteria.ExplainRejection(rematch, opponent));
        Assert.Contains("[C3]", criteria.ExplainRejection(colourClash, opponent));
        Assert.Contains("Art. 2.1.3", criteria.ExplainRejection(colourClash, opponent));
        Assert.Null(criteria.ExplainRejection(Profile(1, points: 0, colours: "BB"), opponent));
    }

    // -------------------------------------------------------------------------------------------

    /// <summary>Kriterien, bei denen beide übergebenen Spieler Topscorer sind (Schlussrunde).</summary>
    private static FideDutchAbsoluteCriteria TopscorerCriteriaFor(params FideDutchPlayerProfile[] profiles)
    {
        var withPoints = profiles.Select(profile => profile with { Points = 3m }).ToArray();
        var criteria = FideDutchAbsoluteCriteria.ForRound(CreateTournament(5, 4), withPoints);
        Assert.All(withPoints, profile => Assert.True(criteria.IsTopscorer(profile)));
        return criteria;
    }

    private static TournamentState CreateTournament(int plannedRounds, int roundsPlayed)
    {
        var tournament = new TournamentState
        {
            Name = "Absolute Criteria",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                PlannedRounds = plannedRounds
            }
        };

        for (var round = 1; round <= roundsPlayed; round++)
        {
            tournament.Rounds.Add(new TournamentRound { RoundNumber = round, Pairings = Array.Empty<Pairing>() });
        }

        return tournament;
    }

    private static FideDutchPlayerProfile Profile(
        int tpn,
        decimal points,
        string colours = "",
        bool byeIneligible = false,
        IEnumerable<Guid>? opponentIds = null)
    {
        var sequence = colours.Select(c => c == 'W' ? ChessColor.White : ChessColor.Black).ToList();

        return new FideDutchPlayerProfile(
            Player: new Player { Id = Guid.Parse($"00000000-0000-0000-0000-{tpn:000000000000}"), Name = $"Spieler {tpn}", StartingRank = tpn },
            Points: points,
            Tpn: tpn,
            PlayedColours: sequence,
            ColourByRound: sequence.Select((colour, index) => (index + 1, colour)).ToDictionary(e => e.Item1, e => e.colour),
            PlayedOpponentIds: (opponentIds ?? Array.Empty<Guid>()).ToHashSet(),
            IsByeIneligible: byeIneligible,
            FloatLastRound: FideFloat.None,
            FloatTwoRoundsBack: FideFloat.None);
    }
}
