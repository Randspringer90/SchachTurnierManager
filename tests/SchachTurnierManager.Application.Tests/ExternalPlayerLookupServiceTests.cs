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
