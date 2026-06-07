using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ScoringRulesTests
{
    [Fact]
    public void NorwayArmageddon_GivesOneAndHalfForArmageddonWinnerAndOneForLoser()
    {
        var result = new GameResult(GameResultKind.ArmageddonBlackWin);

        Assert.Equal(1m, ScoringRules.ScoreFor(result, isWhite: true, ScoringSystem.NorwayArmageddon));
        Assert.Equal(1.5m, ScoringRules.ScoreFor(result, isWhite: false, ScoringSystem.NorwayArmageddon));
    }

    [Fact]
    public void ThreeOneZero_DrawGivesOnePointEach()
    {
        var result = new GameResult(GameResultKind.Draw);

        Assert.Equal(1m, ScoringRules.ScoreFor(result, isWhite: true, ScoringSystem.ThreeOneZero));
        Assert.Equal(1m, ScoringRules.ScoreFor(result, isWhite: false, ScoringSystem.ThreeOneZero));
    }
}
