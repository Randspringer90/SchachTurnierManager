using Microsoft.Extensions.DependencyInjection;
using SchachTurnierManager.Application.External;

namespace SchachTurnierManager.Infrastructure.External;

public static class ExternalPlayerLookupServiceCollectionExtensions
{
    public static IServiceCollection AddExternalPlayerLookupAdapters(this IServiceCollection services, string? dataDirectory = null)
    {
        var cacheDirectory = Path.Combine(dataDirectory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SchachTurnierManager"), "fide-cache");
        services.AddSingleton<IFideRatingListCatalog>(_ => new FideRatingListCatalog(cacheDirectory));
        services.AddSingleton<IExternalPlayerLookupProvider>(provider => new FidePlayerLookupProvider(provider.GetRequiredService<IFideRatingListCatalog>()));
        services.AddSingleton<IExternalPlayerLookupProvider, DsbPlayerLookupProvider>();
        services.AddSingleton<IExternalPlayerLookupProvider, ThsbPlayerLookupProvider>();
        // Lokale Quelle ist scoped, weil sie den ITournamentStore (scoped) nutzt.
        services.AddScoped<IExternalPlayerLookupProvider, LocalRosterPlayerLookupProvider>();
        services.AddScoped<ExternalPlayerLookupService>();
        return services;
    }
}
