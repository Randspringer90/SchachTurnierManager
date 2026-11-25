using System.Data.Common;
using System.Globalization;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.Persistence;

public sealed record SchemaMigrationResult(int FromVersion, int ToVersion, string? BackupPath, int MigratedRows, int UnreadableRows)
{
    public bool Changed => FromVersion != ToVersion;
}

/// <summary>
/// Brings an existing local database to the schema of this build. The schema version lives in
/// SQLite's <c>PRAGMA user_version</c>. Before an existing database is changed, a complete copy is
/// written next to it; tournament content (the JSON snapshot) is never rewritten by a migration.
/// </summary>
public static class DatabaseSchemaMigrator
{
    /// <summary>1 = list columns Revision, PlayerCount, RoundCount, Format.</summary>
    public const int CurrentVersion = 1;

    private const string Table = "tournament_snapshots";

    private static readonly (string Name, string Definition)[] VersionOneColumns =
    [
        ("Revision", "INTEGER NOT NULL DEFAULT 0"),
        ("PlayerCount", "INTEGER NOT NULL DEFAULT 0"),
        ("RoundCount", "INTEGER NOT NULL DEFAULT 0"),
        ("Format", "TEXT NOT NULL DEFAULT ''"),
    ];

    public static SchemaMigrationResult Migrate(TournamentDbContext dbContext, string? backupDirectory, Func<DateTimeOffset>? clock = null)
    {
        ArgumentNullException.ThrowIfNull(dbContext);
        var connection = dbContext.Database.GetDbConnection();
        var openedHere = connection.State != System.Data.ConnectionState.Open;
        if (openedHere) connection.Open();
        try
        {
            var version = Convert.ToInt32(Scalar(connection, "PRAGMA user_version;"), CultureInfo.InvariantCulture);
            if (version > CurrentVersion)
            {
                throw new InvalidOperationException(
                    $"Die Datenbank wurde mit einer neueren Programmversion geschrieben (Schema {version}, dieses Programm kennt {CurrentVersion}). " +
                    "Sie wurde nicht verändert. Bitte die aktuelle Programmversion starten.")
                    .WithErrorCode("DATABASE_SCHEMA_NEWER");
            }

            if (!TableExists(connection))
            {
                dbContext.Database.EnsureCreated();
                Execute(connection, $"PRAGMA user_version = {CurrentVersion};");
                return new SchemaMigrationResult(version, CurrentVersion, null, 0, 0);
            }

            if (version == CurrentVersion)
            {
                return new SchemaMigrationResult(version, version, null, 0, 0);
            }

            var missing = MissingColumns(connection);
            var backupPath = missing.Count > 0 ? CreateBackup(connection, backupDirectory, version, clock ?? (() => DateTimeOffset.UtcNow)) : null;
            var (migrated, unreadable) = UpgradeToVersionOne(connection, missing);
            return new SchemaMigrationResult(version, CurrentVersion, backupPath, migrated, unreadable);
        }
        finally
        {
            if (openedHere) connection.Close();
        }
    }

    private static (int Migrated, int Unreadable) UpgradeToVersionOne(DbConnection connection, IReadOnlyCollection<string> missing)
    {
        using var transaction = connection.BeginTransaction();
        foreach (var (name, definition) in VersionOneColumns)
        {
            if (missing.Contains(name))
                Execute(connection, $"ALTER TABLE {Table} ADD COLUMN \"{name}\" {definition};", transaction);
        }

        // Only rows that never received list data are filled, so the step can safely run again.
        var rows = new List<(string Id, string Json)>();
        using (var select = connection.CreateCommand())
        {
            select.Transaction = transaction;
            select.CommandText = $"SELECT \"Id\", \"Json\" FROM {Table} WHERE \"Revision\" = 0;";
            using var reader = select.ExecuteReader();
            while (reader.Read()) rows.Add((reader.GetString(0), reader.IsDBNull(1) ? string.Empty : reader.GetString(1)));
        }

        var unreadable = 0;
        foreach (var (id, json) in rows)
        {
            var (players, rounds, format, readable) = Inspect(json);
            if (!readable) unreadable++;
            using var update = connection.CreateCommand();
            update.Transaction = transaction;
            update.CommandText = $"UPDATE {Table} SET \"Revision\" = 1, \"PlayerCount\" = $players, \"RoundCount\" = $rounds, \"Format\" = $format WHERE \"Id\" = $id;";
            AddParameter(update, "$players", players);
            AddParameter(update, "$rounds", rounds);
            AddParameter(update, "$format", format);
            AddParameter(update, "$id", id);
            update.ExecuteNonQuery();
        }

        Execute(connection, $"PRAGMA user_version = {CurrentVersion};", transaction);
        transaction.Commit();
        return (rows.Count, unreadable);
    }

    /// <summary>Reads list data tolerantly; a damaged snapshot keeps its row and stays restorable from the backup.</summary>
    private static (int Players, int Rounds, string Format, bool Readable) Inspect(string json)
    {
        try
        {
            using var document = JsonDocument.Parse(json);
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) return (0, 0, string.Empty, false);
            var players = root.TryGetProperty("players", out var p) && p.ValueKind == JsonValueKind.Array ? p.GetArrayLength() : 0;
            var rounds = root.TryGetProperty("rounds", out var r) && r.ValueKind == JsonValueKind.Array ? r.GetArrayLength() : 0;
            // A snapshot without an explicit format deserializes to the default format.
            var format = default(TournamentFormat).ToString();
            if (root.TryGetProperty("settings", out var settings) && settings.ValueKind == JsonValueKind.Object &&
                settings.TryGetProperty("format", out var value))
            {
                if (value.ValueKind == JsonValueKind.String && Enum.TryParse<TournamentFormat>(value.GetString(), out var named) && Enum.IsDefined(named))
                    format = named.ToString();
                else if (value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) && Enum.IsDefined(typeof(TournamentFormat), number))
                    format = ((TournamentFormat)number).ToString();
                else
                    format = string.Empty;
            }

            return (players, rounds, format, true);
        }
        catch (JsonException)
        {
            return (0, 0, string.Empty, false);
        }
    }

    private static string? CreateBackup(DbConnection connection, string? backupDirectory, int fromVersion, Func<DateTimeOffset> clock)
    {
        if (string.IsNullOrWhiteSpace(backupDirectory) || connection is not SqliteConnection sqlite) return null;
        var source = new SqliteConnectionStringBuilder(sqlite.ConnectionString);
        if (source.Mode == SqliteOpenMode.Memory || string.IsNullOrWhiteSpace(source.DataSource) ||
            source.DataSource.Equals(":memory:", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        Directory.CreateDirectory(backupDirectory);
        var stamp = clock().UtcDateTime.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        var path = Path.Combine(backupDirectory, $"vor-schema-{fromVersion}-auf-{CurrentVersion}-{stamp}.sqlite");
        for (var attempt = 2; File.Exists(path); attempt++)
            path = Path.Combine(backupDirectory, $"vor-schema-{fromVersion}-auf-{CurrentVersion}-{stamp}-{attempt}.sqlite");

        // The SQLite online backup produces a consistent copy including pages still held in the WAL.
        var target = new SqliteConnectionStringBuilder { DataSource = path, Pooling = false }.ToString();
        using (var destination = new SqliteConnection(target))
        {
            destination.Open();
            sqlite.BackupDatabase(destination);
        }

        if (!File.Exists(path) || new FileInfo(path).Length == 0)
            throw new InvalidOperationException("Die Sicherung vor der Datenbankaktualisierung konnte nicht geschrieben werden. Die Datenbank wurde nicht verändert.")
                .WithErrorCode("DATABASE_BACKUP_FAILED");
        return path;
    }

    private static bool TableExists(DbConnection connection)
    {
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = $name;";
        AddParameter(command, "$name", Table);
        return Convert.ToInt32(command.ExecuteScalar(), CultureInfo.InvariantCulture) > 0;
    }

    private static HashSet<string> MissingColumns(DbConnection connection)
    {
        var existing = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using (var command = connection.CreateCommand())
        {
            command.CommandText = $"PRAGMA table_info({Table});";
            using var reader = command.ExecuteReader();
            while (reader.Read()) existing.Add(reader.GetString(1));
        }

        return VersionOneColumns.Select(column => column.Name).Where(name => !existing.Contains(name))
            .ToHashSet(StringComparer.Ordinal);
    }

    private static object? Scalar(DbConnection connection, string sql)
    {
        using var command = connection.CreateCommand();
        command.CommandText = sql;
        return command.ExecuteScalar();
    }

    private static void Execute(DbConnection connection, string sql, DbTransaction? transaction = null)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandText = sql;
        command.ExecuteNonQuery();
    }

    private static void AddParameter(DbCommand command, string name, object value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }
}
