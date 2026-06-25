using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SchachTurnierManager.Application;
using SchachTurnierManager.Infrastructure.Persistence;

namespace SchachTurnierManager.Infrastructure;

public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddSchachTurnierPersistence(this IServiceCollection services, string sqliteConnectionString)
    {
        if (IsSharedMemoryConnection(sqliteConnectionString))
        {
            var keepAliveConnection = new SqliteConnection(sqliteConnectionString);
            keepAliveConnection.Open();
            services.AddSingleton(keepAliveConnection);
        }

        services.AddDbContext<TournamentDbContext>(options => options.UseSqlite(sqliteConnectionString));
        services.AddScoped<ITournamentStore, SqliteTournamentStore>();
        return services;
    }

    /// <summary>
    /// Registriert den append-only Datei-Audit-Spiegel. Das Verzeichnis liegt lokal (AppData)
    /// und enthält pro Turnier eine JSONL-Datei – außerhalb des Repositorys.
    /// </summary>
    public static IServiceCollection AddFileAuditJournalSink(this IServiceCollection services, string auditDirectory)
    {
        services.AddSingleton<IAuditJournalSink>(new FileAuditJournalSink(auditDirectory));
        return services;
    }

    private static bool IsSharedMemoryConnection(string sqliteConnectionString)
    {
        var builder = new SqliteConnectionStringBuilder(sqliteConnectionString);
        return builder.Mode == SqliteOpenMode.Memory && builder.Cache == SqliteCacheMode.Shared;
    }
}
