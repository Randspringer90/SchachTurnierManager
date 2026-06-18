using Microsoft.Data.Sqlite;
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
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "tournament.sqlite");

        try
        {
            var options = CreateOptions(databasePath);

            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament("Persistenztest", new TournamentSettings { Format = TournamentFormat.RoundRobin });
                var a = service.AddPlayer(tournament.Id, new Player { Name = "Alice", Rating = new RatingProfile { ManualTwz = 1900 } });
                service.AddPlayer(tournament.Id, new Player { Name = "Bob", Rating = new RatingProfile { ManualTwz = 1800 } });
                var round = service.GenerateNextRound(tournament.Id);
                service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: false, seed: 518);
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
                Assert.NotNull(reloaded.Rounds[0].Pairings[0].Chess960StartPosition);
                Assert.InRange(reloaded.Rounds[0].Pairings[0].Chess960StartPosition!.PositionNumber, 0, 959);
            }
        }
        finally
        {
            DeleteTestDirectory(testDirectory);
        }
    }

    private static DbContextOptions<TournamentDbContext> CreateOptions(string databasePath)
    {
        var connectionString = new SqliteConnectionStringBuilder
        {
            DataSource = databasePath,
            Pooling = false
        }.ToString();

        return new DbContextOptionsBuilder<TournamentDbContext>()
            .UseSqlite(connectionString)
            .Options;
    }

    private static void DeleteTestDirectory(string testDirectory)
    {
        SqliteConnection.ClearAllPools();

        for (var attempt = 1; attempt <= 5; attempt++)
        {
            try
            {
                if (Directory.Exists(testDirectory))
                {
                    Directory.Delete(testDirectory, recursive: true);
                }

                return;
            }
            catch (IOException) when (attempt < 5)
            {
                Thread.Sleep(TimeSpan.FromMilliseconds(100 * attempt));
            }
            catch (UnauthorizedAccessException) when (attempt < 5)
            {
                Thread.Sleep(TimeSpan.FromMilliseconds(100 * attempt));
            }
        }

        if (Directory.Exists(testDirectory))
        {
            Directory.Delete(testDirectory, recursive: true);
        }
    }
}
