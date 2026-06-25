using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class ExternalPlayerLookupServiceTests
{
    [Fact]
    public async Task SearchAsync_UsesIdLookupForNumericQuery()
    {
        var provider = new FakeExternalProvider();
        var service = new ExternalPlayerLookupService(new[] { provider });

        var result = await service.SearchAsync(ExternalPlayerSource.Fide, "4610563");

        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        Assert.Equal("4610563", provider.LastIdLookup);
        Assert.Null(provider.LastNameSearch);
    }

    [Fact]
    public async Task SearchAsync_UsesNameSearchForTextQuery()
    {
        var provider = new FakeExternalProvider();
        var service = new ExternalPlayerLookupService(new[] { provider });

        var result = await service.SearchAsync(ExternalPlayerSource.Fide, "Geisshirt");

        Assert.Equal(ExternalPlayerLookupStatus.Unsupported, result.Status);
        Assert.Equal("Geisshirt", provider.LastNameSearch);
        Assert.Null(provider.LastIdLookup);
    }

    [Fact]
    public void ExternalPlayerProfile_ToPlayer_MapsRatingsAndIds()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = "4610563",
            Name = "Geisshirt, Marco",
            Federation = "Germany",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "4610563",
            Title = "FM",
            Elo = 1968,
            RapidElo = 1800,
            BlitzElo = 1750
        };

        var player = profile.ToPlayer();

        Assert.Equal("Geisshirt, Marco", player.Name);
        Assert.Equal("4610563", player.FideId);
        Assert.Equal(1968, player.Rating.Elo);
        Assert.Equal(1800, player.Rating.RapidElo);
        Assert.Equal(1750, player.Rating.BlitzElo);
        Assert.Equal(GenderCategory.Male, player.Gender);
    }

    [Fact]
    public async Task SearchAllAsync_ById_MergesFideEloWithLocalDwz()
    {
        var fide = new StubProvider(ExternalPlayerSource.Fide, supportsId: true, supportsName: false, new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = "4610563",
            Name = "Geisshirt, Marco",
            FideId = "4610563",
            BirthYear = 1990,
            Elo = 1968,
            Confidence = 0.95
        });
        var local = new StubProvider(ExternalPlayerSource.Local, supportsId: true, supportsName: true, new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Local,
            ExternalId = "4610563",
            Name = "Marco Geißhirt",
            FideId = "4610563",
            Dwz = 1987,
            Confidence = 0.6
        });
        var service = new ExternalPlayerLookupService(new IExternalPlayerLookupProvider[] { fide, local });

        var result = await service.SearchAllAsync("4610563");

        var profile = Assert.Single(result.Players);
        Assert.Equal("4610563", profile.FideId);
        Assert.Equal(1968, profile.Elo);
        Assert.Equal(1987, profile.Dwz);
        Assert.Contains(result.Sources, s => s.Source == ExternalPlayerSource.Local && s.IsActive && s.Count == 1);
    }

    [Fact]
    public async Task SearchAllAsync_ByName_UsesLocalSourceWhenFideNameSearchInactive()
    {
        var fide = new StubProvider(ExternalPlayerSource.Fide, supportsId: true, supportsName: false);
        var local = new StubProvider(ExternalPlayerSource.Local, supportsId: true, supportsName: true, new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Local,
            ExternalId = "4610563",
            Name = "Marco Geißhirt",
            FideId = "4610563",
            Dwz = 1987,
            Confidence = 0.6
        });
        var service = new ExternalPlayerLookupService(new IExternalPlayerLookupProvider[] { fide, local });

        var result = await service.SearchAllAsync("Marco Geißhirt");

        Assert.Single(result.Players);
        Assert.Contains(result.Sources, s => s.Source == ExternalPlayerSource.Fide && !s.IsActive);
        Assert.Contains(result.Sources, s => s.Source == ExternalPlayerSource.Local && s.IsActive);
    }

    private sealed class StubProvider : IExternalPlayerLookupProvider
    {
        private readonly ExternalPlayerProfile[] _profiles;
        private readonly bool _supportsId;
        private readonly bool _supportsName;

        public StubProvider(ExternalPlayerSource source, bool supportsId, bool supportsName, params ExternalPlayerProfile[] profiles)
        {
            Source = source;
            _supportsId = supportsId;
            _supportsName = supportsName;
            _profiles = profiles;
            Info = new ExternalPlayerProviderInfo(source, source.ToString(), supportsId, supportsName, "stub", null);
        }

        public ExternalPlayerSource Source { get; }
        public ExternalPlayerProviderInfo Info { get; }

        public Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
            => Task.FromResult(_supportsId && _profiles.Length > 0
                ? ExternalPlayerLookupResult.Found(Source, externalId, _profiles)
                : ExternalPlayerLookupResult.Empty(Source, externalId, "leer"));

        public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
            => Task.FromResult(_supportsName && _profiles.Length > 0
                ? ExternalPlayerLookupResult.Found(Source, name, _profiles)
                : ExternalPlayerLookupResult.Empty(Source, name, "leer"));
    }

    private sealed class FakeExternalProvider : IExternalPlayerLookupProvider
    {
        public ExternalPlayerSource Source => ExternalPlayerSource.Fide;

        public ExternalPlayerProviderInfo Info { get; } = new(ExternalPlayerSource.Fide, "Fake", true, true, "Fake", null);

        public string? LastIdLookup { get; private set; }

        public string? LastNameSearch { get; private set; }

        public Task<ExternalPlayerLookupResult> LookupByIdAsync(string externalId, CancellationToken cancellationToken = default)
        {
            LastIdLookup = externalId;
            return Task.FromResult(ExternalPlayerLookupResult.Found(Source, externalId, new ExternalPlayerProfile
            {
                Source = Source,
                ExternalId = externalId,
                FideId = externalId,
                Name = "Test, Player"
            }));
        }

        public Task<ExternalPlayerLookupResult> SearchByNameAsync(string name, CancellationToken cancellationToken = default)
        {
            LastNameSearch = name;
            return Task.FromResult(ExternalPlayerLookupResult.Unsupported(Source, name, "Name search disabled in fake."));
        }
    }
}
