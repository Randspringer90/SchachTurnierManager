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
    public async Task RecordResult_ConcurrentSameExpectedValue_AllowsExactlyOneWriter()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "concurrent-result.sqlite");

        try
        {
            var options = CreateOptions(databasePath);
            Guid tournamentId;
            int roundNumber;
            int boardNumber;

            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament("Concurrent Result", new TournamentSettings { Format = TournamentFormat.RoundRobin });
                service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 01" });
                service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Player 02" });
                var round = service.GenerateNextRound(tournament.Id);
                tournamentId = tournament.Id;
                roundNumber = round.RoundNumber;
                boardNumber = round.Pairings.Single().BoardNumber;
            }

            using var start = new ManualResetEventSlim(false);
            async Task<bool> TryWriteAsync(GameResultKind result)
            {
                return await Task.Run(() =>
                {
                    using var db = new TournamentDbContext(CreateOptions(databasePath));
                    var service = new TournamentService(new SqliteTournamentStore(db));
                    start.Wait();
                    try
                    {
                        service.RecordResult(tournamentId, roundNumber, boardNumber, result, GameResultKind.NotPlayed);
                        return true;
                    }
                    catch (InvalidOperationException)
                    {
                        return false;
                    }
                });
            }

            var whiteWrite = TryWriteAsync(GameResultKind.WhiteWin);
            var blackWrite = TryWriteAsync(GameResultKind.BlackWin);
            start.Set();
            var outcomes = await Task.WhenAll(whiteWrite, blackWrite);

            Assert.Single(outcomes, success => success);
            using var verifyDb = new TournamentDbContext(CreateOptions(databasePath));
            var storedResult = new SqliteTournamentStore(verifyDb).Get(tournamentId)!
                .Rounds.Single().Pairings.Single().Result.Kind;
            Assert.Contains(storedResult, new[] { GameResultKind.WhiteWin, GameResultKind.BlackWin });
        }
        finally
        {
            DeleteTestDirectory(testDirectory);
        }
    }

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
                var tournament = service.CreateTournament("Persistenztest", new TournamentSettings
                {
                    Format = TournamentFormat.RoundRobin,
                    UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent
                });
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
                Assert.Equal(UnplayedRoundBuchholzMode.FideVirtualOpponent, reloaded.Settings.UnplayedRoundBuchholzMode);
            }
        }
        finally
        {
            DeleteTestDirectory(testDirectory);
        }
    }

    [Fact]
    public void SaveAndReload_PreservesFideDutchPairingStrategyAndSwissInitialColour()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "fide-dutch-persistence.sqlite");

        try
        {
            var options = CreateOptions(databasePath);
            Guid tournamentId;

            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament("FIDE-Dutch-Persistenztest", new TournamentSettings
                {
                    PairingStrategy = SwissPairingStrategyKind.FideDutch,
                    SwissInitialColour = ChessColor.Black
                });
                tournamentId = tournament.Id;
            }

            using (var db = new TournamentDbContext(options))
            {
                var reloaded = new SqliteTournamentStore(db).Get(tournamentId);

                Assert.NotNull(reloaded);
                Assert.Equal(SwissPairingStrategyKind.FideDutch, reloaded!.Settings.PairingStrategy);
                Assert.Equal(ChessColor.Black, reloaded.Settings.SwissInitialColour);
            }
        }
        finally
        {
            DeleteTestDirectory(testDirectory);
        }
    }

    [Fact]
    public void Reload_LegacySnapshotWithoutFideDutchSettings_UsesOptimalV2AndWhiteDefaults()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "legacy-fide-dutch.sqlite");
        var tournamentId = Guid.Parse("00000000-0000-0000-0000-000000000078");

        try
        {
            var options = CreateOptions(databasePath);
            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                db.TournamentSnapshots.Add(new TournamentSnapshot
                {
                    Id = tournamentId,
                    Name = "Legacy",
                    CreatedOn = "2026-01-01",
                    UpdatedAt = DateTimeOffset.UtcNow,
                    Json = $"{{\"id\":\"{tournamentId}\",\"name\":\"Legacy\",\"settings\":{{\"plannedRounds\":5}},\"players\":[],\"rounds\":[],\"auditJournal\":[]}}"
                });
                db.SaveChanges();
            }

            using (var db = new TournamentDbContext(options))
            {
                var reloaded = new SqliteTournamentStore(db).Get(tournamentId);

                Assert.NotNull(reloaded);
                Assert.Equal(SwissPairingStrategyKind.OptimalMatchingV2, reloaded!.Settings.PairingStrategy);
                Assert.Equal(ChessColor.White, reloaded.Settings.SwissInitialColour);
            }
        }
        finally
        {
            DeleteTestDirectory(testDirectory);
        }
    }

    [Fact]
    public void Reload_LegacySnapshotWithoutUnplayedRoundMode_UsesDefault()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "legacy.sqlite");
        var tournamentId = Guid.Parse("00000000-0000-0000-0000-000000000077");

        try
        {
            var options = CreateOptions(databasePath);
            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                db.TournamentSnapshots.Add(new TournamentSnapshot
                {
                    Id = tournamentId,
                    Name = "Legacy",
                    CreatedOn = "2026-01-01",
                    UpdatedAt = DateTimeOffset.UtcNow,
                    Json = $"{{\"id\":\"{tournamentId}\",\"name\":\"Legacy\",\"settings\":{{\"plannedRounds\":5}},\"players\":[],\"rounds\":[],\"auditJournal\":[]}}"
                });
                db.SaveChanges();
            }

            using (var db = new TournamentDbContext(options))
            {
                var reloaded = new SqliteTournamentStore(db).Get(tournamentId);

                Assert.NotNull(reloaded);
                Assert.Equal(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, reloaded!.Settings.UnplayedRoundBuchholzMode);
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
