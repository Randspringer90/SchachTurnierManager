using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentServiceTests
{
    [Fact]
    public void CreateAddGenerateRecord_CalculatesStandings()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vereinsturnier", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        var a = service.AddPlayer(tournament.Id, new Player { Name = "Alice", Rating = new RatingProfile { ManualTwz = 1900 } });
        service.AddPlayer(tournament.Id, new Player { Name = "Bob", Rating = new RatingProfile { ManualTwz = 1800 } });

        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, 1, round.Pairings[0].WhitePlayerId == a.Id ? GameResultKind.WhiteWin : GameResultKind.BlackWin);

        var standings = service.GetStandings(tournament.Id);

        Assert.Equal("Alice", standings[0].Name);
        Assert.Equal(1m, standings[0].Points);
    }
}
