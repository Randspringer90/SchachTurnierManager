using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class RoundRobinPlanSqliteTests
{
    [Theory]
    [InlineData(4)]
    [InlineData(5)]
    public void RestartAndBackupRestore_PreserveVersionSeedsResultsAndNextRound(int count)
    {
        var directory = Path.Combine(Path.GetTempPath(), $"stm-rr-plan-{Guid.NewGuid():N}");
        Directory.CreateDirectory(directory);
        var options = new DbContextOptionsBuilder<TournamentDbContext>()
            .UseSqlite($"Data Source={Path.Combine(directory, "synthetic.sqlite")};Pooling=False").Options;
        Guid id;
        string expected;
        string firstRound;
        try
        {
            using (var db = new TournamentDbContext(options))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament("Synthetic persisted plan", new TournamentSettings { Format = TournamentFormat.RoundRobin, PlannedRounds = count });
                id = tournament.Id;
                for (var rank = 1; rank <= count; rank++)
                    service.AddPlayer(id, new Player { Name = $"Synthetic {rank:00}", Rating = new RatingProfile { ManualTwz = 2000 - rank } });
                var round = service.GenerateNextRound(id);
                foreach (var pair in round.Pairings.Where(pair => !pair.IsBye)) service.RecordResult(id, 1, pair.BoardNumber, GameResultKind.Draw);
                firstRound = JsonSerializer.Serialize(service.RequireTournament(id).Rounds);
                expected = Signature(service.PreviewNextRound(id).Round);
            }
            using (var db = new TournamentDbContext(options))
            {
                var service = new TournamentService(new SqliteTournamentStore(db));
                var restored = service.RequireTournament(id);
                Assert.NotNull(restored.RoundRobinPlan);
                Assert.Equal("RoundRobin-Berger-v2", restored.RoundRobinPlan.AlgorithmVersion);
                Assert.Equal(count, restored.RoundRobinPlan.ParticipantOrder.Count);
                Assert.Equal(firstRound, JsonSerializer.Serialize(restored.Rounds));
                var backup = JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(restored))!;
                var backupService = new TournamentService(new InMemoryTournamentStore());
                backupService.SaveImportedTournament(backup, overwriteExisting: false);
                Assert.Equal(expected, Signature(backupService.GenerateNextRound(id)));
                var player = restored.Players[1];
                service.UpdatePlayer(id, player.Id, player with { Name = "Synthetic renamed", Rating = new RatingProfile { ManualTwz = 5000 } });
                Assert.Equal(expected, Signature(service.GenerateNextRound(id)));
                Assert.Equal(firstRound, JsonSerializer.Serialize(service.RequireTournament(id).Rounds.Take(1).ToList()));
                using var connection = new SqliteConnection($"Data Source={Path.Combine(directory, "synthetic.sqlite")};Pooling=False");
                connection.Open();
                using var command = connection.CreateCommand();
                command.CommandText = "select sqlite_version()";
                Assert.True(Version.Parse((string)command.ExecuteScalar()!) >= new Version(3, 54, 1), "The test must execute the current native SQLite dependency.");
            }
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    private static string Signature(TournamentRound round) => string.Join('|', round.Pairings.Select(pair => $"{pair.BoardNumber}:{pair.WhitePlayerId}/{pair.BlackPlayerId}"));
}
