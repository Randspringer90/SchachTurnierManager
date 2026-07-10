using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class KnownExternalPlayerSnapshotTests
{
    [Fact]
    public void SyntheticReference_FideSnapshot_MapsStableIdentityFields()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = "99900123",
            Name = "Weissbach, Lina",
            Federation = "Germany",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "99900123",
            Elo = 1968,
            ProfileUrl = "https://ratings.fide.com/profile/99900123",
            Notes = "Stabiler Test-Snapshot. Live-Rating kann sich ändern; genaue Ratings werden in Live-Tests bewusst nicht hart verdrahtet."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Weissbach, Lina", player.Name);
        Assert.Equal("99900123", player.FideId);
        Assert.Equal("Germany", player.Federation);
        Assert.Equal(1990, player.BirthYear);
        Assert.Equal(GenderCategory.Male, player.Gender);
        Assert.Equal(1968, player.Rating.Elo);
    }

    [Fact]
    public void SyntheticReference_DsbSnapshot_MapsDwzFieldsWithoutLiveDependency()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Dsb,
            ExternalId = "Lina Weissbach",
            Name = "Weißbach, Lina",
            Club = "Beispiel SV",
            Federation = "DSB",
            Country = "GER",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "99900123",
            Dwz = 1987,
            Notes = "DSB/DeWIS-Snapshot für Mapping-Tests. Der echte Abruf wird erst nach geklärter offizieller Schnittstelle aktiviert."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Weißbach, Lina", player.Name);
        Assert.Equal("Beispiel SV", player.Club);
        Assert.Equal("99900123", player.FideId);
        Assert.Equal(1987, player.Rating.Dwz);
        Assert.Null(player.Rating.Elo);
    }

    [Fact]
    public void SyntheticReference_ThsbSnapshot_MapsRegionalContextWithoutLiveDependency()
    {
        var profile = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Thsb,
            ExternalId = "Beispiel SV/Lina Weissbach",
            Name = "Weißbach, Lina",
            Club = "Beispiel SV",
            Federation = "ThSB",
            Country = "GER",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = "99900123",
            Notes = "ThSB wird fachlich als Regionalfilter auf DSB/DeWIS vorbereitet, bis eine eigene offizielle ThSB-Schnittstelle nachgewiesen ist."
        };

        var player = profile.ToPlayer();

        Assert.Equal("Weißbach, Lina", player.Name);
        Assert.Equal("Beispiel SV", player.Club);
        Assert.Equal("ThSB", player.Federation);
        Assert.Equal("99900123", player.FideId);
    }
}
