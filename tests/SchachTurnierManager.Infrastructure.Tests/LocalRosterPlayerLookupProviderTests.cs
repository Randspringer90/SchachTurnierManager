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
        SeedMarco(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.LookupByIdAsync("4610563");

        var profile = Assert.Single(result.Players);
        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        Assert.Equal("4610563", profile.FideId);
        Assert.Equal(1987, profile.Dwz);
        Assert.Equal(ExternalPlayerSource.Local, profile.Source);
    }

    [Theory]
    [InlineData("Marco Geißhirt")]
    [InlineData("Marco Geisshirt")]
    [InlineData("Marco Geishirt")]
    [InlineData("Geißhirt, Marco")]
    [InlineData("Geisshirt Marco")]
    public async Task SearchByName_IsDiacriticAndOrderTolerant(string query)
    {
        var store = new InMemoryTournamentStore();
        SeedMarco(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.SearchByNameAsync(query);

        Assert.NotEmpty(result.Players);
        Assert.Contains(result.Players, p => p.FideId == "4610563");
    }

    [Fact]
    public async Task SearchByName_UnknownPerson_ReturnsEmpty()
    {
        var store = new InMemoryTournamentStore();
        SeedMarco(store);
        var provider = new LocalRosterPlayerLookupProvider(store);

        var result = await provider.SearchByNameAsync("Magnus Carlsen");

        Assert.Empty(result.Players);
    }

    private static void SeedMarco(InMemoryTournamentStore store)
    {
        var service = new TournamentService(store);
        var tournament = service.CreateTournament("Bergfest");
        service.AddPlayer(tournament.Id, new Player
        {
            Name = "Marco Geißhirt",
            Club = "Ilmenauer SV",
            BirthYear = 1990,
            FideId = "4610563",
            Rating = new RatingProfile { Dwz = 1987 }
        });
    }
}
