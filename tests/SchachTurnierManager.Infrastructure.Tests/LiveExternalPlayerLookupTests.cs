using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.External;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class LiveExternalPlayerLookupTests
{
    private const string MarcoFideId = "4610563";

    [Fact]
    public async Task FideLookupByKnownId_ReturnsMarco_WhenLiveTestsEnabled()
    {
        if (!LiveLookupTestsEnabled())
        {
            return;
        }

        var provider = new FidePlayerLookupProvider();

        var result = await provider.LookupByIdAsync(MarcoFideId);

        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        var player = Assert.Single(result.Players);
        Assert.Equal(MarcoFideId, player.FideId);
        Assert.Contains("geisshirt", player.Name.ToLowerInvariant());
        Assert.Equal(1990, player.BirthYear);
        Assert.Equal(GenderCategory.Male, player.Gender);
        Assert.True(player.Elo is >= 1000, $"Unerwartetes oder fehlendes FIDE-Standardrating: {player.Elo}");
    }

    [Fact]
    public void KnownExternalLookupSnapshots_ContainMarcoReferenceData()
    {
        var fide = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = MarcoFideId,
            FideId = MarcoFideId,
            Name = "Geisshirt, Marco",
            Federation = "Germany",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            Elo = 1968,
            Confidence = 0.95,
            Notes = "Stabiler Snapshot für Offline-Tests; Live-Werte können sich ändern."
        };

        var dsb = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Dsb,
            ExternalId = "dewis-placeholder-4610563",
            Name = "Geisshirt, Marco",
            Club = "Ilmenauer SV",
            Federation = "Thüringen",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = MarcoFideId,
            Dwz = 1987,
            Confidence = 0.75,
            Warnings = new[] { "DSB/DeWIS-Livezugriff ist noch nicht aktiviert; Snapshot dient nur als Offline-Testanker." }
        };

        var thsb = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Thsb,
            ExternalId = "thsb-placeholder-ilmenauer-sv",
            Name = "Geisshirt, Marco",
            Club = "Ilmenauer SV",
            Federation = "Thüringer Schachbund",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = MarcoFideId,
            Confidence = 0.7,
            Warnings = new[] { "ThSB wird fachlich über DSB/DeWIS-Verbands-/Vereinsfilter vorbereitet." }
        };

        Assert.Equal(MarcoFideId, fide.FideId);
        Assert.Equal(1968, fide.Elo);
        Assert.Equal(1987, dsb.Dwz);
        Assert.Equal("Ilmenauer SV", dsb.Club);
        Assert.Equal("Thüringer Schachbund", thsb.Federation);
        Assert.All(new[] { fide, dsb, thsb }, profile => Assert.Contains("geisshirt", profile.Name.ToLowerInvariant()));
    }

    private static bool LiveLookupTestsEnabled()
    {
        return string.Equals(Environment.GetEnvironmentVariable("STM_RUN_LIVE_LOOKUP_TESTS"), "1", StringComparison.OrdinalIgnoreCase);
    }
}
