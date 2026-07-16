using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// FIDE-C.07/03-2026-Modell für eigene ungespielte Runden in Buchholz und
/// seinen Cut-/Median-Varianten.
/// </summary>
public sealed class UnplayedRoundTiebreakTests
{
    [Theory]
    [InlineData(GameResultKind.WhiteWin, false)]
    [InlineData(GameResultKind.Draw, false)]
    [InlineData(GameResultKind.BlackWin, false)]
    [InlineData(GameResultKind.ArmageddonWhiteWin, false)]
    [InlineData(GameResultKind.ArmageddonBlackWin, false)]
    [InlineData(GameResultKind.NotPlayed, true)]
    [InlineData(GameResultKind.Bye, true)]
    [InlineData(GameResultKind.WhiteForfeitWin, true)]
    [InlineData(GameResultKind.BlackForfeitWin, true)]
    [InlineData(GameResultKind.DoubleForfeit, true)]
    public void IsUnplayedRound_ClassifiesResultKinds(GameResultKind kind, bool expectedUnplayed)
    {
        Assert.Equal(expectedUnplayed, UnplayedRoundTiebreak.IsUnplayedRound(kind));
    }

    // a) Normal gespielte Partie: keine ungespielte Runde, kein virtueller Gegner.
    [Fact]
    public void PlayedGame_ContributesNoVirtualOpponent()
    {
        Assert.False(UnplayedRoundTiebreak.IsUnplayedRound(GameResultKind.WhiteWin));

        var contribution = UnplayedRoundTiebreak.OwnUnplayedBuchholzContribution(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            playerOwnFinalScore: 4.5m,
            unplayedRoundCount: 0);

        Assert.Equal(0m, contribution);
    }

    // b) Kampfloser Sieg: eigene ungespielte Runde => virtueller Gegner mit eigener Punktzahl.
    [Fact]
    public void ForfeitWin_IsUnplayedAndUsesPlayerOwnScoreAsVirtualOpponent()
    {
        Assert.True(UnplayedRoundTiebreak.IsUnplayedRound(GameResultKind.WhiteForfeitWin));

        var contribution = UnplayedRoundTiebreak.OwnUnplayedBuchholzContribution(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            playerOwnFinalScore: 3m,
            unplayedRoundCount: 1);

        Assert.Equal(3m, contribution);
    }

    // c) Spielfrei/Bye: eigene ungespielte Runde, virtueller Gegner = eigene Punktzahl.
    [Fact]
    public void Bye_UsesVirtualOpponentEqualToOwnScore()
    {
        Assert.True(UnplayedRoundTiebreak.IsUnplayedRound(GameResultKind.Bye));
        Assert.Equal(5.5m, UnplayedRoundTiebreak.VirtualOpponentScore(5.5m));

        var contribution = UnplayedRoundTiebreak.OwnUnplayedBuchholzContribution(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            playerOwnFinalScore: 5.5m,
            unplayedRoundCount: 1);

        Assert.Equal(5.5m, contribution);
    }

    // d) Ungespielte Runde zählt für Buchholz konfigurierbar anders.
    [Fact]
    public void UnplayedRound_ContributionIsConfigurablePerMode()
    {
        var ignored = UnplayedRoundTiebreak.OwnUnplayedBuchholzContribution(
            UnplayedRoundBuchholzMode.IgnoreUnplayedRounds,
            playerOwnFinalScore: 4m,
            unplayedRoundCount: 2);

        var fide = UnplayedRoundTiebreak.OwnUnplayedBuchholzContribution(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            playerOwnFinalScore: 4m,
            unplayedRoundCount: 2);

        Assert.Equal(0m, ignored);
        Assert.Equal(8m, fide);
    }

    // e) Cut-Buchholz/Streichergebnis vorbereitet: Liste ist sortiert und enthält
    //    virtuelle Gegner, sodass Cut-1 den niedrigsten Wert streichen kann.
    [Fact]
    public void BuildBuchholzScoreList_FideMode_AddsSortedVirtualOpponentsForCut()
    {
        var realOpponents = new[] { 4m, 2m, 5m };

        var list = UnplayedRoundTiebreak.BuildBuchholzScoreList(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            realOpponents,
            playerOwnFinalScore: 3m,
            unplayedRoundCount: 1);

        Assert.Equal(new[] { 2m, 3m, 4m, 5m }, list);

        var fullBuchholz = list.Sum();
        var cutOne = list.Skip(1).Sum(); // niedrigsten Wert streichen
        Assert.Equal(14m, fullBuchholz);
        Assert.Equal(12m, cutOne);
    }

    [Fact]
    public void BuildBuchholzScoreList_IgnoreMode_KeepsOnlyRealOpponentsSorted()
    {
        var realOpponents = new[] { 4m, 2m, 5m };

        var list = UnplayedRoundTiebreak.BuildBuchholzScoreList(
            UnplayedRoundBuchholzMode.IgnoreUnplayedRounds,
            realOpponents,
            playerOwnFinalScore: 3m,
            unplayedRoundCount: 2);

        Assert.Equal(new[] { 2m, 4m, 5m }, list);
    }

    [Theory]
    [InlineData(5.0, 3.0, 3.0)]
    [InlineData(2.0, 3.0, 2.0)]
    public void DummyOpponentScore_UsesOwnScoreWithFideCap(double own, double cap, double expected)
    {
        Assert.Equal((decimal)expected, UnplayedRoundTiebreak.DummyOpponentScore((decimal)own, (decimal)cap));
    }

    [Fact]
    public void CanonicalScoreList_DefaultMode_DropsVirtualEntriesAndKeepsLegacyCuts()
    {
        var scores = UnplayedRoundTiebreak.BuildCanonicalScoreList(
            UnplayedRoundBuchholzMode.IgnoreUnplayedRounds,
            new[]
            {
                new BuchholzScoreEntry(1m),
                new BuchholzScoreEntry(4m),
                new BuchholzScoreEntry(3m)
            },
            new[] { new BuchholzScoreEntry(2m, IsVoluntaryUnplayedRound: true) });

        Assert.Equal(new[] { 1m, 3m, 4m }, scores.Select(entry => entry.Score));
        Assert.Equal(7m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, scores, 1, 0));
        Assert.Equal(4m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, scores, 2, 0));
        Assert.Equal(3m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, scores, 1, 1));
    }

    [Fact]
    public void CanonicalScoreList_FideMode_AppliesVurExceptionToCutOneCutTwoAndMedian()
    {
        var scores = UnplayedRoundTiebreak.BuildCanonicalScoreList(
            UnplayedRoundBuchholzMode.FideVirtualOpponent,
            new[]
            {
                new BuchholzScoreEntry(1m),
                new BuchholzScoreEntry(4m),
                new BuchholzScoreEntry(5m)
            },
            new[]
            {
                new BuchholzScoreEntry(2m, IsVoluntaryUnplayedRound: true),
                new BuchholzScoreEntry(3m, IsVoluntaryUnplayedRound: true)
            });

        Assert.Equal(15m, scores.Sum(entry => entry.Score));
        Assert.Equal(13m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.FideVirtualOpponent, scores, 1, 0));
        Assert.Equal(10m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.FideVirtualOpponent, scores, 2, 0));
        Assert.Equal(8m, UnplayedRoundTiebreak.SumAfterDropping(UnplayedRoundBuchholzMode.FideVirtualOpponent, scores, 1, 1));
    }
}
