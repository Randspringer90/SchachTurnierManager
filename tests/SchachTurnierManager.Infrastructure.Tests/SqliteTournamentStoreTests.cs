using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class SqliteTournamentStoreTests
{
    [Fact]
    public void SaveAndReload_PreservesPlayersRoundsAndResults()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}.sqlite");
        try
        {
            var options = new DbContextOptionsBuilder<TournamentDbContext>()
                .UseSqlite($"Data Source={databasePath}")
                .Options;

            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament("Persistenztest", new TournamentSettings { Format = TournamentFormat.RoundRobin });
                var a = service.AddPlayer(tournament.Id, new Player { Name = "Alice", Rating = new RatingProfile { ManualTwz = 1900 } });
                service.AddPlayer(tournament.Id, new Player { Name = "Bob", Rating = new RatingProfile { ManualTwz = 1800 } });
                var round = service.GenerateNextRound(tournament.Id);
                var result = round.Pairings[0].WhitePlayerId == a.Id ? GameResultKind.WhiteWin : GameResultKind.BlackWin;
                service.RecordResult(tournament.Id, round.RoundNumber, round.Pairings[0].BoardNumber, result);
            }

            using (var db = new TournamentDbContext(options))
            {
                var reloaded = new TournamentService(new SqliteTournamentStore(db)).ListTournaments().Single();

                Assert.Equal("Persistenztest", reloaded.Name);
                Assert.Equal(2, reloaded.Players.Count);
                Assert.Single(reloaded.Rounds);
                Assert.True(reloaded.Rounds[0].Pairings[0].Result.IsPlayed);
            }
        }
        finally
        {
            if (File.Exists(databasePath))
            {
                File.Delete(databasePath);
            }
        }
    }
}
