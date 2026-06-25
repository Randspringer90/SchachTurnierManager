using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class Chess960PositionServiceTests
{
    [Theory]
    [InlineData("RNBQKBNR", 518)]
    [InlineData("BBQNNRKR", 0)]
    public void ValidatePosition_AcceptsKnownValidPositions(string position, int expectedNumber)
    {
        var service = new Chess960PositionService();

        Assert.True(service.ValidatePosition(position));
        Assert.Equal(expectedNumber, service.GetPositionNumber(position));
    }

    [Theory]
    [InlineData("RQBNNBRK")]
    [InlineData("BQBNNRKR")]
    [InlineData("RNBQKBN")]
    [InlineData("RNBQKBNX")]
    public void ValidatePosition_RejectsInvalidPositions(string position)
    {
        var service = new Chess960PositionService();

        Assert.False(service.ValidatePosition(position));
        Assert.Throws<ArgumentException>(() => service.GetPositionNumber(position));
    }

    [Fact]
    public void FromPositionNumber_StandardChessPositionIsNumber518()
    {
        var service = new Chess960PositionService();

        var position = service.FromPositionNumber(518, seed: 1234);

        Assert.Equal("RNBQKBNR", position.WhiteBackRank);
        Assert.Equal("rnbqkbnr", position.BlackBackRank);
        Assert.Equal(518, position.PositionNumber);
        Assert.Equal(1234, position.Seed);
    }

    [Fact]
    public void GenerateRandomPosition_WithSeedIsReproducibleAndValid()
    {
        var service = new Chess960PositionService();

        var first = service.GenerateRandomPosition(seed: 42);
        var second = service.GenerateRandomPosition(seed: 42);

        Assert.Equal(first.WhiteBackRank, second.WhiteBackRank);
        Assert.Equal(first.PositionNumber, second.PositionNumber);
        Assert.True(service.ValidatePosition(first.WhiteBackRank));
    }

    [Fact]
    public void AllPositionNumbersCreateExactly960ValidPositions()
    {
        var service = new Chess960PositionService();
        var positions = Enumerable.Range(0, 960)
            .Select(number => service.FromPositionNumber(number).WhiteBackRank)
            .ToList();

        Assert.Equal(960, positions.Distinct().Count());
        Assert.All(positions, position => Assert.True(service.ValidatePosition(position)));
    }
}
