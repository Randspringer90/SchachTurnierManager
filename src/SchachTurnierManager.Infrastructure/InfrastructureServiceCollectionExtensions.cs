using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SchachTurnierManager.Application;
using SchachTurnierManager.Infrastructure.Persistence;

namespace SchachTurnierManager.Infrastructure;

public static class InfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddSchachTurnierPersistence(this IServiceCollection services, string sqliteConnectionString)
    {
        services.AddDbContext<TournamentDbContext>(options => options.UseSqlite(sqliteConnectionString));
        services.AddScoped<ITournamentStore, SqliteTournamentStore>();
        return services;
    }
}
