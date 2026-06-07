using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class ArmageddonBiddingServiceTests
{
    [Fact]
    public void Decide_LowerBidWinsBlackAndDrawOdds()
    {
        var decision = new ArmageddonBiddingService().Decide(TimeSpan.FromMinutes(4), TimeSpan.FromMinutes(5));

        Assert.Equal(ArmageddonBidWinner.WhiteCandidate, decision.LowerBidder);
        Assert.Equal(TimeSpan.FromMinutes(4), decision.AcceptedTime);
    }
}
