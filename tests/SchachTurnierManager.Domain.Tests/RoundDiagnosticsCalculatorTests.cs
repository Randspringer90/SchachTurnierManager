using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class RoundDiagnosticsCalculatorTests
{
    [Fact]
    public void Calculate_ReportsOpenForfeitAndByeBoards()
    {
        var a = Player("A", 1);
        var b = Player("B", 2);
        var c = Player("C", 3);
        var d = Player("D", 4);
        var tournament = new TournamentState
        {
            Name = "Diagnose",
            Players = { a, b, c, d },
            Rounds =
            {
                new TournamentRound
                {
                    RoundNumber = 1,
                    Pairings = new[]
                    {
                        Pairing.Game(1, a.Id, b.Id) with { Result = new GameResult(GameResultKind.NotPlayed) },
                        Pairing.Game(2, c.Id, d.Id) with { Result = new GameResult(GameResultKind.BlackForfeitWin) },
                        Pairing.Bye(3, a.Id)
                    }
                }
            }
        };

        var diagnostics = Assert.Single(new RoundDiagnosticsCalculator().Calculate(tournament));

        Assert.False(diagnostics.IsComplete);
        Assert.Equal(1, diagnostics.OpenBoards);
        Assert.Equal(1, diagnostics.ForfeitBoards);
        Assert.Equal(1, diagnostics.ByeBoards);
        Assert.Contains(diagnostics.Warnings, warning => warning.Contains("offene Bretter", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(diagnostics.Warnings, warning => warning.Contains("kampflos", StringComparison.OrdinalIgnoreCase));
        Assert.Contains(diagnostics.Boards, board => board.BoardNumber == 2 && board.IsForfeit && !board.CountsForPerformance);
    }

    private static Player Player(string name, int rank)
    {
        return new Player { Id = Guid.NewGuid(), Name = name, StartingRank = rank };
    }
}
