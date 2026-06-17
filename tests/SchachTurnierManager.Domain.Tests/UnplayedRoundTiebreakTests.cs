using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// Prepared FIDE virtual-opponent model for unplayed rounds (C.07/2024 Art. 16.2/16.4).
/// Pure domain service; not yet wired into <see cref="StandingsCalculator"/>.
/// Cases follow the requested matrix: gespielte Partie, kampfloser Sieg, Bye,
/// konfigurierbare ungespielte Runde, vorbereitete Cut-Buchholz-Liste.
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
}
