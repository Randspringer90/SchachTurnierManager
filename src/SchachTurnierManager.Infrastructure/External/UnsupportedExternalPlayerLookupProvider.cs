using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.External;

public abstract class UnsupportedExternalPlayerLookupProvider : IExternalPlayerLookupProvider
{
    protected UnsupportedExternalPlayerLookupProvider(ExternalPlayerSource source, string name, string description, string? url)
    {
        Source = source;
        Info = new ExternalPlayerProviderInfo(source, name, SupportsIdLookup: false, SupportsNameSearch: false, description, url);
    }

    public ExternalPlayerSource Source { get; }

    public ExternalPlayerProviderInfo Info { get; }

    public Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
    {
        return Task.FromResult(ExternalPlayerLookupResult.Unsupported(Source, externalId, Info.Description));
    }

    public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
    {
        return Task.FromResult(ExternalPlayerLookupResult.Unsupported(Source, name, Info.Description));
    }
}

public sealed class DsbPlayerLookupProvider() : UnsupportedExternalPlayerLookupProvider(
    ExternalPlayerSource.Dsb,
    "DSB / DeWIS",
    "DSB-/DWZ-Abfragen sind vorbereitet, aber noch nicht aktiviert. Für eine robuste Integration muss die offizielle DeWIS-/DWZ-Schnittstelle samt Registrierung/API-Zugriff geklärt werden.",
    "https://www.schachbund.de/dwz.html");

public sealed class ThsbPlayerLookupProvider() : UnsupportedExternalPlayerLookupProvider(
    ExternalPlayerSource.Thsb,
    "Thüringer Schachbund",
    "ThSB-Spielerdaten werden zunächst über DSB/DeWIS mit Verbands-/Vereinsfilter vorbereitet. Eine eigene öffentliche ThSB-Spieler-API ist in diesem Stand nicht hinterlegt.",
    "https://www.thsb.de/");
