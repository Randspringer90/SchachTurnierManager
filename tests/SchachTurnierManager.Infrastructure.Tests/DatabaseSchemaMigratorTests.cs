using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

/// <summary>
/// Persistence v2 (ADR-0006): an existing database of an older build is copied before its schema
/// changes, keeps every tournament byte-identical and becomes listable without parsing snapshots.
/// </summary>
public sealed class DatabaseSchemaMigratorTests : IDisposable
{
    private static readonly JsonSerializerOptions LegacyJson = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly string _directory = Path.Combine(Path.GetTempPath(), $"stm-schema-{Guid.NewGuid():N}");
    private readonly string _database;
    private readonly string _backups;

    public DatabaseSchemaMigratorTests()
    {
        Directory.CreateDirectory(_directory);
        _database = Path.Combine(_directory, "synthetic.sqlite");
        _backups = Path.Combine(_directory, "backups");
    }

    [Fact]
    public void LegacyDatabase_IsBackedUpThenUpgraded_AndKeepsEveryTournamentByteIdentical()
    {
        var legacy = SyntheticTournament("Altturnier", players: 5, format: TournamentFormat.Swiss);
        var legacyJson = CreateLegacyDatabase((legacy.Id, legacy.Name, LegacySnapshotJson(legacy)));

        SchemaMigrationResult result;
        using (var db = Open()) result = DatabaseSchemaMigrator.Migrate(db, _backups, () => new DateTimeOffset(2026, 11, 25, 9, 30, 0, TimeSpan.Zero));

        Assert.Equal(0, result.FromVersion);
        Assert.Equal(DatabaseSchemaMigrator.CurrentVersion, result.ToVersion);
        Assert.Equal(1, result.MigratedRows);
        Assert.Equal(0, result.UnreadableRows);
        Assert.NotNull(result.BackupPath);
        Assert.Equal(Path.Combine(_backups, "vor-schema-0-auf-1-20261125-093000.sqlite"), result.BackupPath);

        // The copy still has the old shape and the old content.
        Assert.DoesNotContain("Revision", Columns(result.BackupPath!));
        Assert.Equal(legacyJson[legacy.Id], ReadText(result.BackupPath!, "SELECT \"Json\" FROM tournament_snapshots;"));
        Assert.Equal(0L, ReadScalar(result.BackupPath!, "PRAGMA user_version;"));

        // The live database is upgraded; the snapshot itself is untouched.
        Assert.Equal((long)DatabaseSchemaMigrator.CurrentVersion, ReadScalar(_database, "PRAGMA user_version;"));
        Assert.Equal(legacyJson[legacy.Id], ReadText(_database, "SELECT \"Json\" FROM tournament_snapshots;"));
        using var verify = Open();
        var store = new SqliteTournamentStore(verify);
        var loaded = store.Get(legacy.Id);
        Assert.NotNull(loaded);
        Assert.Equal(1, loaded!.Revision);
        Assert.Equal(5, loaded.Players.Count);
        var summary = Assert.Single(store.ListSummaries());
        Assert.Equal((legacy.Id, "Altturnier", 1L, TournamentFormat.Swiss, 5, 0),
            (summary.Id, summary.Name, summary.Revision, summary.Format, summary.PlayerCount, summary.RoundCount));
    }

    [Fact]
    public void FreshDatabase_IsCreatedAtCurrentVersion_WithoutBackup_AndSecondRunChangesNothing()
    {
        SchemaMigrationResult first, second;
        using (var db = Open()) first = DatabaseSchemaMigrator.Migrate(db, _backups);
        using (var db = Open()) second = DatabaseSchemaMigrator.Migrate(db, _backups);

        Assert.Equal(DatabaseSchemaMigrator.CurrentVersion, first.ToVersion);
        Assert.Null(first.BackupPath);
        Assert.False(second.Changed);
        Assert.Null(second.BackupPath);
        Assert.False(Directory.Exists(_backups));
        Assert.Contains("Revision", Columns(_database));
    }

    [Fact]
    public void MigratedDatabase_IsNotMigratedOrBackedUpAgain()
    {
        var legacy = SyntheticTournament("Altturnier", players: 3, format: TournamentFormat.RoundRobin);
        CreateLegacyDatabase((legacy.Id, legacy.Name, LegacySnapshotJson(legacy)));
        using (var db = Open()) DatabaseSchemaMigrator.Migrate(db, _backups);

        SchemaMigrationResult again;
        using (var db = Open()) again = DatabaseSchemaMigrator.Migrate(db, _backups);

        Assert.False(again.Changed);
        Assert.Equal(0, again.MigratedRows);
        Assert.Single(Directory.GetFiles(_backups));
    }

    [Fact]
    public void DatabaseOfANewerProgram_IsRejectedUnchanged()
    {
        using (var db = Open()) DatabaseSchemaMigrator.Migrate(db, _backups);
        Execute(_database, "PRAGMA user_version = 99;");

        using var newer = Open();
        var error = Assert.Throws<InvalidOperationException>(() => DatabaseSchemaMigrator.Migrate(newer, _backups));

        Assert.Equal("DATABASE_SCHEMA_NEWER", RuleErrorMetadata.GetErrorCode(error));
        Assert.Equal(99L, ReadScalar(_database, "PRAGMA user_version;"));
        Assert.False(Directory.Exists(_backups));
    }

    [Fact]
    public void DamagedSnapshot_BlocksNeitherMigrationNorTheList()
    {
        var good = SyntheticTournament("Lesbar", players: 4, format: TournamentFormat.Swiss);
        var damagedId = Guid.NewGuid();
        CreateLegacyDatabase((good.Id, good.Name, LegacySnapshotJson(good)), (damagedId, "Beschädigt", "{ this is not json"));

        SchemaMigrationResult result;
        using (var db = Open()) result = DatabaseSchemaMigrator.Migrate(db, _backups);

        Assert.Equal(2, result.MigratedRows);
        Assert.Equal(1, result.UnreadableRows);
        using var verify = Open();
        var store = new SqliteTournamentStore(verify);
        var summaries = store.ListSummaries();
        Assert.Equal(2, summaries.Count);
        Assert.Contains(summaries, summary => summary.Id == damagedId && summary.PlayerCount == 0);
        Assert.Equal(4, store.Get(good.Id)!.Players.Count);
        Assert.Throws<InvalidOperationException>(() => store.Get(damagedId));
    }

    [Fact]
    public void Revision_IncreasesOnlyWhenContentChanges_AndBelongsToThisDatabase()
    {
        using (var db = Open()) DatabaseSchemaMigrator.Migrate(db, _backups);
        using var context = Open();
        var store = new SqliteTournamentStore(context);
        var tournament = SyntheticTournament("Revision", players: 2, format: TournamentFormat.Swiss);
        tournament.Revision = 57; // e.g. the counter of another installation inside an imported backup

        store.Save(tournament);
        Assert.Equal(1, store.Get(tournament.Id)!.Revision);

        store.UpdateAtomically(tournament.Id, state => { state.Name = "Revision geändert"; return 0; });
        Assert.Equal(2, store.Get(tournament.Id)!.Revision);
        var rowAfterChange = ReadText(_database, "SELECT \"UpdatedAt\" || '|' || \"Json\" FROM tournament_snapshots;");

        store.UpdateAtomically(tournament.Id, _ => 0); // idempotent retry
        Assert.Equal(2, store.Get(tournament.Id)!.Revision);
        Assert.Equal(rowAfterChange, ReadText(_database, "SELECT \"UpdatedAt\" || '|' || \"Json\" FROM tournament_snapshots;"));

        var summary = Assert.Single(store.ListSummaries());
        Assert.Equal(("Revision geändert", 2L, 2), (summary.Name, summary.Revision, summary.PlayerCount));

        store.Save(store.Get(tournament.Id)!);
        Assert.Equal(3, store.Get(tournament.Id)!.Revision);
    }

    public void Dispose()
    {
        SqliteConnection.ClearAllPools();
        if (Directory.Exists(_directory)) Directory.Delete(_directory, recursive: true);
    }

    private TournamentDbContext Open() => new(new DbContextOptionsBuilder<TournamentDbContext>()
        .UseSqlite($"Data Source={_database};Pooling=False").Options);

    private static TournamentState SyntheticTournament(string name, int players, TournamentFormat format)
    {
        var tournament = new TournamentState { Name = name, Settings = new TournamentSettings { Format = format } };
        for (var index = 0; index < players; index++)
            tournament.Players.Add(new Player { Name = $"Synthetisch {index + 1}", StartingRank = index + 1 });
        return tournament;
    }

    /// <summary>A snapshot exactly as an older build wrote it: no revision property.</summary>
    private static string LegacySnapshotJson(TournamentState tournament)
    {
        var node = JsonNode.Parse(JsonSerializer.Serialize(tournament, LegacyJson))!.AsObject();
        node.Remove("revision");
        return node.ToJsonString();
    }

    private Dictionary<Guid, string> CreateLegacyDatabase(params (Guid Id, string Name, string Json)[] rows)
    {
        Execute(_database,
            "CREATE TABLE \"tournament_snapshots\" (\"Id\" TEXT NOT NULL CONSTRAINT \"PK_tournament_snapshots\" PRIMARY KEY, " +
            "\"Name\" TEXT NOT NULL, \"CreatedOn\" TEXT NOT NULL, \"UpdatedAt\" TEXT NOT NULL, \"Json\" TEXT NOT NULL);" +
            "CREATE INDEX \"IX_tournament_snapshots_Name\" ON \"tournament_snapshots\" (\"Name\");");
        using var connection = new SqliteConnection($"Data Source={_database};Pooling=False");
        connection.Open();
        foreach (var row in rows)
        {
            using var insert = connection.CreateCommand();
            insert.CommandText = "INSERT INTO tournament_snapshots (\"Id\", \"Name\", \"CreatedOn\", \"UpdatedAt\", \"Json\") VALUES ($id, $name, '2026-10-01', '2026-10-01 10:00:00+00:00', $json);";
            insert.Parameters.AddWithValue("$id", row.Id.ToString().ToUpperInvariant());
            insert.Parameters.AddWithValue("$name", row.Name);
            insert.Parameters.AddWithValue("$json", row.Json);
            insert.ExecuteNonQuery();
        }

        return rows.ToDictionary(row => row.Id, row => row.Json);
    }

    private static void Execute(string database, string sql)
    {
        using var connection = new SqliteConnection($"Data Source={database};Pooling=False");
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static long ReadScalar(string database, string sql)
    {
        using var connection = new SqliteConnection($"Data Source={database};Pooling=False;Mode=ReadOnly");
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt64(command.ExecuteScalar());
    }

    private static string ReadText(string database, string sql)
    {
        using var connection = new SqliteConnection($"Data Source={database};Pooling=False;Mode=ReadOnly");
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToString(command.ExecuteScalar())!;
    }

    private static List<string> Columns(string database)
    {
        using var connection = new SqliteConnection($"Data Source={database};Pooling=False;Mode=ReadOnly");
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = "PRAGMA table_info(tournament_snapshots);";
        using var reader = command.ExecuteReader();
        var names = new List<string>();
        while (reader.Read()) names.Add(reader.GetString(1));
        return names;
    }
}
