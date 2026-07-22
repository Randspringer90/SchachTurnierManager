using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

/// <summary>
/// "App-Neustart erhaelt das Turnier" auf Datenebene (STM-STAB-001).
///
/// Der Firefox-End-to-End-Test prueft den Neustart durch die Oberflaeche. Diese
/// Tests sichern dieselbe Zusage darunter ab, damit ein Regress in der
/// Persistenz nicht erst im Browser auffaellt: der Zustand muss einen komplett
/// geschlossenen DbContext ueberleben, so wie ihn ein beendeter Serverprozess
/// hinterlaesst.
/// </summary>
public sealed class TournamentRestartPersistenceTests
{
    [Fact]
    public void TournamentSurvivesACompleteRestartWithPlayersRoundsAndResults()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-restart-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "restart.sqlite");

        try
        {
            Guid tournamentId;
            int roundNumber;

            // --- Erster Prozess: Turnier anlegen und eine Runde spielen ---
            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                var tournament = service.CreateTournament(
                    "Neustart Turnier",
                    new TournamentSettings { Format = TournamentFormat.RoundRobin, PlannedRounds = 3 });
                tournamentId = tournament.Id;

                service.AddPlayer(tournamentId, new Player { Name = "Synthetic Player 01", Club = "Example Knights" });
                service.AddPlayer(tournamentId, new Player { Name = "Synthetic Player 02", Club = "Sample Rooks" });

                var round = service.GenerateNextRound(tournamentId);
                roundNumber = round.RoundNumber;
                service.RecordResult(tournamentId, roundNumber, round.Pairings.Single().BoardNumber, GameResultKind.WhiteWin);
            }

            // --- Zweiter Prozess: derselbe Datenbestand, frischer Kontext ---
            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                var service = new TournamentService(new SqliteTournamentStore(db));

                var listed = service.ListTournaments();
                Assert.Single(listed);

                var reopened = service.RequireTournament(tournamentId);
                Assert.Equal("Neustart Turnier", reopened.Name);
                Assert.Equal(TournamentFormat.RoundRobin, reopened.Settings.Format);
                Assert.Equal(3, reopened.Settings.PlannedRounds);
                Assert.Equal(2, reopened.Players.Count);
                Assert.Contains(reopened.Players, player => player.Club == "Example Knights");

                var round = Assert.Single(reopened.Rounds);
                Assert.Equal(roundNumber, round.RoundNumber);
                Assert.Equal(GameResultKind.WhiteWin, round.Pairings.Single().Result.Kind);

                var standings = service.GetStandings(tournamentId);
                Assert.Equal(2, standings.Count);
                Assert.Equal(1m, standings[0].Points);
            }
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            Directory.Delete(testDirectory, recursive: true);
        }
    }

    [Fact]
    public void ADeletedTournamentStaysDeletedAcrossARestart()
    {
        // Nach dem Loeschen darf ein Neustart das Turnier nicht wieder
        // auftauchen lassen - sonst waere die Auswahl in der Oberflaeche nach
        // jedem Serverstart wieder inkonsistent.
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-restart-delete-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "restart-delete.sqlite");

        try
        {
            Guid keptId;
            Guid removedId;

            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                keptId = service.CreateTournament("Bleibt").Id;
                removedId = service.CreateTournament("Verschwindet").Id;

                Assert.True(service.DeleteTournament(removedId));
            }

            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                var service = new TournamentService(new SqliteTournamentStore(db));

                var listed = service.ListTournaments();
                Assert.Single(listed);
                Assert.Equal(keptId, listed[0].Id);
                Assert.Throws<InvalidOperationException>(() => service.RequireTournament(removedId));
            }
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            Directory.Delete(testDirectory, recursive: true);
        }
    }

    [Fact]
    public void CreatingATournamentIsDurableWithoutAnyFurtherWrite()
    {
        // Genau der Fall aus dem Bedienfehlerbericht: Turnier anlegen, danach
        // stuerzt der Server ab oder wird geschlossen. Ohne weiteren Schreibzug
        // muss das Turnier trotzdem vorhanden sein.
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-restart-create-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "restart-create.sqlite");

        try
        {
            Guid createdId;

            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                db.Database.EnsureCreated();
                var service = new TournamentService(new SqliteTournamentStore(db));
                createdId = service.CreateTournament("Sofort Persistent").Id;
            }

            using (var db = new TournamentDbContext(CreateOptions(databasePath)))
            {
                var service = new TournamentService(new SqliteTournamentStore(db));
                Assert.Equal("Sofort Persistent", service.RequireTournament(createdId).Name);
            }
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            Directory.Delete(testDirectory, recursive: true);
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
}
