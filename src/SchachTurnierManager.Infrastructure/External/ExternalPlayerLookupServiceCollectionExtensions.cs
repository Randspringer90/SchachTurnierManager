using Microsoft.Extensions.DependencyInjection;
using SchachTurnierManager.Application.External;

namespace SchachTurnierManager.Infrastructure.External;

public static class ExternalPlayerLookupServiceCollectionExtensions
{
    public static IServiceCollection AddExternalPlayerLookupAdapters(this IServiceCollection services)
    {
        services.AddSingleton<IExternalPlayerLookupProvider, FidePlayerLookupProvider>();
        services.AddSingleton<IExternalPlayerLookupProvider, DsbPlayerLookupProvider>();
        services.AddSingleton<IExternalPlayerLookupProvider, ThsbPlayerLookupProvider>();
        services.AddScoped<ExternalPlayerLookupService>();
        return services;
    }
}
