using System.Text;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.External;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class FideRatingListCatalogTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "stm-fide-catalog-" + Guid.NewGuid().ToString("N"));
    private const string Header = "ID Number     Name                                    Fed SRtng SGm Tit WTit Flag";
    private static string Row(string id, string name, string fed, string rating = "1800") =>
        id.PadRight(14) + name.PadRight(40) + fed.PadRight(4) + rating.PadRight(6) + "1   ".PadRight(4) + "f   ".PadRight(4) + "    ".PadRight(5);
    private static Stream Input(params string[] rows) => new MemoryStream(Encoding.UTF8.GetBytes(Header + "\n" + string.Join('\n', rows) + "\n"));

    [Fact]
    public async Task NameAndFederationSearch_IsOfflineDeterministicAndPreservesAmbiguousNames()
    {
        var catalog = new FideRatingListCatalog(_directory);
        using var input = Input(Row("99900101", "Synthetic, Alpha", "GER"), Row("99900102", "Synthetic, Alpha", "USA"), Row("99900103", "Synthetic, Béta", "GER"));
        var imported = await catalog.ImportAsync(input);
        Assert.Equal(3, imported.Players);
        Assert.True(catalog.Info.Available);
        Assert.Equal(2, (await catalog.SearchAsync("alpha synthetic")).Players.Count);
        var player = Assert.Single((await catalog.SearchAsync("Synthetic Alpha", "GER")).Players);
        Assert.Equal("99900101", player.FideId);
        Assert.Equal(1800, player.Elo);
        Assert.Equal("FM", player.Title);
        Assert.Single((await catalog.SearchAsync("Beta")).Players);
        Assert.Equal("99900101", Assert.Single((await new FideRatingListCatalog(_directory).SearchAsync("99900101")).Players).ExternalId);
    }

    [Theory]
    [InlineData("broken header\nanything")]
    [InlineData("ID Number Name Fed Rrtng Rgm\ninvalid")]
    [InlineData("ID Number Name Fed SRtng SGm\nshort")]
    public async Task InvalidImport_NeverReplacesTheExistingCatalog(string invalid)
    {
        var catalog = new FideRatingListCatalog(_directory);
        using (var valid = Input(Row("99900101", "Synthetic, Kept", "GER"))) await catalog.ImportAsync(valid);
        using var bad = new MemoryStream(Encoding.UTF8.GetBytes(invalid));
        await Assert.ThrowsAnyAsync<Exception>(() => catalog.ImportAsync(bad));
        Assert.Single((await catalog.SearchAsync("Kept")).Players);
    }

    [Fact]
    public async Task DuplicateIdAndOversizedLine_AreRejectedBeforeReplacingCache()
    {
        var catalog = new FideRatingListCatalog(_directory);
        using var duplicate = Input(Row("99900101", "Synthetic, One", "GER"), Row("99900101", "Synthetic, Other", "USA"));
        await Assert.ThrowsAsync<InvalidDataException>(() => catalog.ImportAsync(duplicate));
        Assert.False(catalog.Info.Available);
        using var longLine = Input(new string('A', 1025));
        await Assert.ThrowsAsync<InvalidDataException>(() => catalog.ImportAsync(longLine));
        Assert.False(catalog.Info.Available);
    }

    [Fact]
    public async Task SearchHasBoundedResultsExplicitOfflineAndStrictQueryValidation()
    {
        var catalog = new FideRatingListCatalog(_directory);
        Assert.Equal(ExternalPlayerLookupStatus.Unavailable, (await catalog.SearchAsync("Synthetic")).Status);
        using var input = Input(Enumerable.Range(1, 60).Select(n => Row((99900000 + n).ToString(), "Synthetic " + n, "GER")).ToArray());
        await catalog.ImportAsync(input);
        Assert.Equal(50, (await catalog.SearchAsync("Synthetic")).Players.Count);
        Assert.Equal(ExternalPlayerLookupStatus.InvalidRequest, (await catalog.SearchAsync("x")).Status);
        Assert.Equal(ExternalPlayerLookupStatus.InvalidRequest, (await catalog.SearchAsync("Synthetic", "GER' OR 1=1")).Status);
    }

    [Fact]
    public async Task CancellationAndStaleCache_AreVisibleWithoutAnyNetworkFallback()
    {
        var catalog = new FideRatingListCatalog(_directory);
        using var input = Input(Row("99900101", "Synthetic, Offline", "GER"));
        await catalog.ImportAsync(input);
        foreach (var file in Directory.GetFiles(_directory)) File.SetLastWriteTimeUtc(file, DateTime.UtcNow.AddDays(-2));
        var stale = new FideRatingListCatalog(_directory);
        Assert.True(stale.Info.Stale);
        Assert.NotEmpty(Assert.Single((await stale.SearchAsync("Offline")).Players).Warnings);
        using var cancel = new CancellationTokenSource(); cancel.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => stale.SearchAsync("Offline", cancellationToken: cancel.Token));
    }

    public void Dispose()
    {
        if (Directory.Exists(_directory)) Directory.Delete(_directory, recursive: true);
    }
}
