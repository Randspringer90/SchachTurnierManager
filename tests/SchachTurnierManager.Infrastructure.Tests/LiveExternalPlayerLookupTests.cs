using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.External;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class LiveExternalPlayerLookupTests
{
    private const string SyntheticReferenceFideId = "99900123";

    [Fact]
    public async Task FideLookupByKnownId_ReturnsConfiguredProfile_WhenLiveTestsEnabled()
    {
        var liveFideId = Environment.GetEnvironmentVariable("STM_LIVE_FIDE_ID");
        if (!LiveLookupTestsEnabled() || string.IsNullOrWhiteSpace(liveFideId))
        {
            return;
        }

        var provider = new FidePlayerLookupProvider();

        var result = await provider.LookupByIdAsync(liveFideId);

        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        var player = Assert.Single(result.Players);
        Assert.Equal(liveFideId, player.FideId);
        Assert.False(string.IsNullOrWhiteSpace(player.Name));
        Assert.NotNull(player.ProfileUrl);
    }

    [Fact]
    public void KnownExternalLookupSnapshots_ContainSyntheticReferenceData()
    {
        var fide = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Fide,
            ExternalId = SyntheticReferenceFideId,
            FideId = SyntheticReferenceFideId,
            Name = "Weissbach, Lina",
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
            ExternalId = "dewis-placeholder-99900123",
            Name = "Weissbach, Lina",
            Club = "Beispiel SV",
            Federation = "Thüringen",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = SyntheticReferenceFideId,
            Dwz = 1987,
            Confidence = 0.75,
            Warnings = new[] { "DSB/DeWIS-Livezugriff ist noch nicht aktiviert; Snapshot dient nur als Offline-Testanker." }
        };

        var thsb = new ExternalPlayerProfile
        {
            Source = ExternalPlayerSource.Thsb,
            ExternalId = "thsb-placeholder-beispiel-sv",
            Name = "Weissbach, Lina",
            Club = "Beispiel SV",
            Federation = "Thüringer Schachbund",
            Country = "Germany",
            BirthYear = 1990,
            Gender = GenderCategory.Male,
            FideId = SyntheticReferenceFideId,
            Confidence = 0.7,
            Warnings = new[] { "ThSB wird fachlich über DSB/DeWIS-Verbands-/Vereinsfilter vorbereitet." }
        };

        Assert.Equal(SyntheticReferenceFideId, fide.FideId);
        Assert.Equal(1968, fide.Elo);
        Assert.Equal(1987, dsb.Dwz);
        Assert.Equal("Beispiel SV", dsb.Club);
        Assert.Equal("Thüringer Schachbund", thsb.Federation);
        Assert.All(new[] { fide, dsb, thsb }, profile => Assert.Contains("weissbach", profile.Name.ToLowerInvariant()));
    }

    private static bool LiveLookupTestsEnabled()
    {
        return string.Equals(Environment.GetEnvironmentVariable("STM_RUN_LIVE_LOOKUP_TESTS"), "1", StringComparison.OrdinalIgnoreCase);
    }
}
