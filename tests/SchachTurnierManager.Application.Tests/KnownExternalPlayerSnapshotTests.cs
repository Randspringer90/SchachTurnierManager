using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class KnownExternalPlayerSnapshotTests
{
    [Fact]
    public void Marco_FideSnapshot_MapsStableIdentityFields()
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
            Elo = 1968,
            ProfileUrl = "https://ratings.fide.com/profile/4610563",
            Notes = "Stabiler Test-Snapshot. Live-Rating kann sich ändern; genaue Ratings werden in Live-Tests bewusst nicht hart verdrahtet."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Geisshirt, Marco", player.Name);
        Assert.Equal("4610563", player.FideId);
        Assert.Equal("Germany", player.Federation);
        Assert.Equal(1990, player.BirthYear);
        Assert.Equal(GenderCategory.Male, player.Gender);
        Assert.Equal(1968, player.Rating.Elo);
    }

    [Fact]
    public void Marco_DsbSnapshot_MapsDwzFieldsWithoutLiveDependency()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Dsb,
            ExternalId = "Marco Geisshirt",
            Name = "Geißhirt, Marco",
            Club = "Ilmenauer SV",
            Federation = "DSB",
            Country = "GER",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "4610563",
            Dwz = 1987,
            Notes = "DSB/DeWIS-Snapshot für Mapping-Tests. Der echte Abruf wird erst nach geklärter offizieller Schnittstelle aktiviert."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Geißhirt, Marco", player.Name);
        Assert.Equal("Ilmenauer SV", player.Club);
        Assert.Equal("4610563", player.FideId);
        Assert.Equal(1987, player.Rating.Dwz);
        Assert.Null(player.Rating.Elo);
    }

    [Fact]
    public void Marco_ThsbSnapshot_MapsRegionalContextWithoutLiveDependency()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Thsb,
            ExternalId = "Ilmenauer SV/Marco Geisshirt",
            Name = "Geißhirt, Marco",
            Club = "Ilmenauer SV",
            Federation = "ThSB",
            Country = "GER",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "4610563",
            Notes = "ThSB wird fachlich als Regionalfilter auf DSB/DeWIS vorbereitet, bis eine eigene offizielle ThSB-Schnittstelle nachgewiesen ist."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Geißhirt, Marco", player.Name);
        Assert.Equal("Ilmenauer SV", player.Club);
        Assert.Equal("ThSB", player.Federation);
        Assert.Equal("4610563", player.FideId);
    }
}
