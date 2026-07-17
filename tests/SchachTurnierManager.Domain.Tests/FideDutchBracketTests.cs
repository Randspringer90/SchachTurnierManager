using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Prüft die Bracket-Struktur nach C.04.3 Art. 1.3, 1.9.2 und 3.2.
/// Die Fälle stammen aus den gegengeprüften Golden-Turnieren; Regelbelege:
/// docs/FIDE_DUTCH_REFERENCE.md.
/// </summary>
public sealed class FideDutchBracketTests
{
    /// <summary>
    /// Art. 1.3.1 / 1.9.2: Punktgruppen fassen gleiche Punktzahlen zusammen und werden von OBEN
    /// nach unten abgearbeitet. Lage aus Golden-Turnier A vor Runde 3: 6,8 = 2.0 | 1,2,3,4 = 1.0 |
    /// 5,7 = 0.
    /// </summary>
    [Fact]
    public void Build_GroupsByPointsDescending_AndKeepsTpnOrderWithinGroup()
    {
        var profiles = new[]
        {
            Profile(6, 2m), Profile(8, 2m),
            Profile(1, 1m), Profile(2, 1m), Profile(3, 1m), Profile(4, 1m),
            Profile(5, 0m), Profile(7, 0m)
        };

        var groups = FideDutchScoreGroups.Build(profiles);

        Assert.Equal(3, groups.Count);
        Assert.Equal(new[] { 6, 8 }, groups[0].Select(p => p.Tpn));
        Assert.Equal(new[] { 1, 2, 3, 4 }, groups[1].Select(p => p.Tpn));
        Assert.Equal(new[] { 5, 7 }, groups[2].Select(p => p.Tpn));
    }

    /// <summary>
    /// Art. 3.2.2: Bei einem homogenen Bracket ist S1 die obere Hälfte, S2 die untere — und gepaart
    /// wird erster gegen ersten (Art. 3.3.1). Genau das erzeugt in Runde 1 die Paarungen 1-5, 2-6,
    /// 3-7, 4-8 aus Golden-Turnier A.
    /// </summary>
    [Fact]
    public void SplitIntoSubgroups_HomogeneousBracket_SplitsIntoUpperAndLowerHalf()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: Enumerable.Range(1, 8).Select(tpn => Profile(tpn, 0m)).ToList(),
            movedDownPlayers: Array.Empty<FideDutchPlayerProfile>());

        Assert.True(bracket.IsHomogeneous);
        Assert.Equal(0, bracket.M0);
        Assert.Equal(4, bracket.MaxPairsUpperBound);

        var subgroups = bracket.SplitIntoSubgroups(m1: 0);

        Assert.Equal(new[] { 1, 2, 3, 4 }, subgroups.S1.Select(p => p.Tpn));
        Assert.Equal(new[] { 5, 6, 7, 8 }, subgroups.S2.Select(p => p.Tpn));
        Assert.Empty(subgroups.Limbo);
    }

    /// <summary>
    /// Bei ungerader Spielerzahl bleibt einer übrig — er floatet ab und erhält in der letzten
    /// Gruppe das Freilos (Art. 1.9.1). Golden-Turnier B Runde 1: S1 = {1,2,3}, S2 = {4,5,6,7},
    /// Spieler 7 bleibt übrig.
    /// </summary>
    [Fact]
    public void SplitIntoSubgroups_OddHomogeneousBracket_LeavesTheLowestPlayerUnpaired()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: Enumerable.Range(1, 7).Select(tpn => Profile(tpn, 0m)).ToList(),
            movedDownPlayers: Array.Empty<FideDutchPlayerProfile>());

        Assert.Equal(3, bracket.MaxPairsUpperBound);

        var subgroups = bracket.SplitIntoSubgroups(m1: 0);

        Assert.Equal(new[] { 1, 2, 3 }, subgroups.S1.Select(p => p.Tpn));
        Assert.Equal(new[] { 4, 5, 6, 7 }, subgroups.S2.Select(p => p.Tpn));
    }

    /// <summary>
    /// Art. 1.3.3: Sobald Absteiger dabei sind, ist das Bracket heterogen. Art. 3.2.3: S1 sind dann
    /// die MDPs, S2 sind ALLE Residents. Lage aus Golden-Turnier A Runde 3: die 1.0-Gruppe
    /// {1,2,3,4} bekommt die Absteiger 6 und 8 aus der 2.0-Gruppe.
    /// </summary>
    [Fact]
    public void SplitIntoSubgroups_HeterogeneousBracket_PutsMdpsIntoS1AndAllResidentsIntoS2()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: new[] { Profile(1, 1m), Profile(2, 1m), Profile(3, 1m), Profile(4, 1m) },
            movedDownPlayers: new[] { Profile(6, 2m), Profile(8, 2m) });

        Assert.True(bracket.IsHeterogeneous);
        Assert.Equal(2, bracket.M0);
        Assert.Equal(new[] { 6, 8, 1, 2, 3, 4 }, bracket.Players.Select(p => p.Tpn));   // Art. 1.2

        var subgroups = bracket.SplitIntoSubgroups(m1: 2);

        Assert.Equal(new[] { 6, 8 }, subgroups.S1.Select(p => p.Tpn));
        Assert.Equal(new[] { 1, 2, 3, 4 }, subgroups.S2.Select(p => p.Tpn));
        Assert.Empty(subgroups.Limbo);
    }

    /// <summary>
    /// Art. 3.2.4: Werden weniger MDPs gepaart als angekommen sind (M1 &lt; M0), landen die übrigen
    /// im Limbo — sie können hier nicht gepaart werden und floaten zwangsläufig erneut ab.
    /// Golden-Turnier A Runde 5: von den Absteigern 3 und 8 wird nur einer gepaart, der andere geht
    /// ins Limbo.
    /// </summary>
    [Fact]
    public void SplitIntoSubgroups_WhenFewerMdpsArePaired_TheRestGoesToLimbo()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: new[] { Profile(1, 2m), Profile(2, 2m), Profile(5, 2m), Profile(6, 2m) },
            movedDownPlayers: new[] { Profile(3, 3m), Profile(8, 3m) });

        var subgroups = bracket.SplitIntoSubgroups(m1: 1);

        Assert.Equal(new[] { 3 }, subgroups.S1.Select(p => p.Tpn));
        Assert.Equal(new[] { 8 }, subgroups.Limbo.Select(p => p.Tpn));      // bound to double-float
        Assert.Equal(new[] { 1, 2, 5, 6 }, subgroups.S2.Select(p => p.Tpn));
    }

    /// <summary>
    /// Art. 3.3.2: Ist M1 = 0, bleibt S1 leer und ALLE MDPs gehen ins Limbo.
    /// </summary>
    [Fact]
    public void SplitIntoSubgroups_WithM1Zero_LeavesS1EmptyAndAllMdpsInLimbo()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: new[] { Profile(1, 1m), Profile(2, 1m) },
            movedDownPlayers: new[] { Profile(5, 2m) });

        var subgroups = bracket.SplitIntoSubgroups(m1: 0);

        Assert.Empty(subgroups.S1);
        Assert.Equal(new[] { 5 }, subgroups.Limbo.Select(p => p.Tpn));
        Assert.Equal(new[] { 1, 2 }, subgroups.S2.Select(p => p.Tpn));
    }

    /// <summary>
    /// MaxPairsUpperBound ist NUR die Obergrenze aus der Spielerzahl — die Kriterien können sie
    /// senken. In Golden-Turnier A Runde 3 hätte die 1.0-Gruppe mit den beiden Absteigern rechnerisch
    /// 3 Paare, darf aber nur 2 bilden, weil sonst 5 und 7 übrig blieben, die nach [C3] nicht
    /// gegeneinander dürfen ([C4] Art. 2.2.1 schlägt [C6]).
    /// Dieser Test hält fest, dass die Zahl bewusst NICHT die tatsächliche Paarzahl ist.
    /// </summary>
    [Fact]
    public void MaxPairsUpperBound_IsOnlyAnUpperBound_NotTheActualPairCount()
    {
        var bracket = FideDutchScoreGroups.ToBracket(
            scoreGroup: new[] { Profile(1, 1m), Profile(2, 1m), Profile(3, 1m), Profile(4, 1m) },
            movedDownPlayers: new[] { Profile(6, 2m), Profile(8, 2m) });

        Assert.Equal(3, bracket.MaxPairsUpperBound);   // rechnerisch 6 Spieler / 2
        // Die tatsaechliche Paarzahl in dieser Lage ist 2 - das entscheidet erst das Suchverfahren
        // anhand von [C4] und [C6], nicht diese Kennzahl.
    }

    private static FideDutchPlayerProfile Profile(int tpn, decimal points)
    {
        return new FideDutchPlayerProfile(
            Player: new Player { Id = Guid.Parse($"00000000-0000-0000-0000-{tpn:000000000000}"), Name = $"Spieler {tpn}", StartingRank = tpn },
            Points: points,
            Tpn: tpn,
            PlayedColours: Array.Empty<ChessColor>(),
            ColourByRound: new Dictionary<int, ChessColor>(),
            PlayedOpponentIds: new HashSet<Guid>(),
            IsByeIneligible: false,
            FloatLastRound: FideFloat.None,
            FloatTwoRoundsBack: FideFloat.None);
    }
}
