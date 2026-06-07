using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class CrossTableCalculatorTests
{
    [Fact]
    public void Calculate_ShowsResultFromPlayerPerspective()
    {
        var white = new Player { Id = Guid.NewGuid(), Name = "Weiß", StartingRank = 1 };
        var black = new Player { Id = Guid.NewGuid(), Name = "Schwarz", StartingRank = 2 };
        var tournament = new TournamentState
        {
            Name = "Test",
            Players = { white, black },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = { Pairing.Game(1, white.Id, black.Id) with { Result = new GameResult(GameResultKind.WhiteWin) } }
                }
            }
        };

        var crossTable = new CrossTableCalculator().Calculate(tournament);

        var whiteRow = Assert.Single(crossTable.Rows, row => row.PlayerId == white.Id);
        var blackRow = Assert.Single(crossTable.Rows, row => row.PlayerId == black.Id);
        Assert.Equal("1", Assert.Single(whiteRow.Cells, cell => cell.OpponentId == black.Id).ResultLabel);
        Assert.Equal("0", Assert.Single(blackRow.Cells, cell => cell.OpponentId == white.Id).ResultLabel);
    }
}
