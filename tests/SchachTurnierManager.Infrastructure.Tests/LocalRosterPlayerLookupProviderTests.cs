using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.External;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class LocalRosterPlayerLookupProviderTests
{
    [Fact]
    public async Task LookupById_FindsLocalPlayerAndExposesDwz()
    {
        var store = new InMemoryTournamentStore();
        SeedSyntheticPlayer(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.LookupByIdAsync("99900123");

        var profile = Assert.Single(result.Players);
        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        Assert.Equal("99900123", profile.FideId);
        Assert.Equal(1987, profile.Dwz);
        Assert.Equal(ExternalPlayerSource.Local, profile.Source);
    }

    [Theory]
    [InlineData("Lina Weißbach")]
    [InlineData("Lina Weissbach")]
    [InlineData("Lina Weisbach")]
    [InlineData("Weißbach, Lina")]
    [InlineData("Weissbach Lina")]
    public async Task SearchByName_IsDiacriticAndOrderTolerant(string query)
    {
        var store = new InMemoryTournamentStore();
        SeedSyntheticPlayer(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.SearchByNameAsync(query);

        Assert.NotEmpty(result.Players);
        Assert.Contains(result.Players, p => p.FideId == "99900123");
    }

    [Fact]
    public async Task SearchByName_UnknownPerson_ReturnsEmpty()
    {
        var store = new InMemoryTournamentStore();
        SeedSyntheticPlayer(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.SearchByNameAsync("Unbekannt Beispiel");

        Assert.Empty(result.Players);
    }

    private static void SeedSyntheticPlayer(InMemoryTournamentStore store)
    {
        var service = new TournamentService(store);
        var tournament = service.CreateTournament("Bergfest");
        service.AddPlayer(tournament.Id, new Player
        {
            Name = "Lina Weißbach",
            Club = "Beispiel SV",
            BirthYear = 1990,
            FideId = "99900123",
            Rating = new RatingProfile { Dwz = 1987 }
        });
    }
}
