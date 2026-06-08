using System.Net;
using System.Text;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.External;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class FidePlayerLookupProviderTests
{
    [Fact]
    public async Task LookupByIdAsync_ParsesKnownProfileHtml_WithoutInternet()
    {
        var html = """
            <html>
              <body>
                <h1>Geisshirt, Marco</h1>
                <dl>
                  <dt>FIDE ID</dt><dd>4610563</dd>
                  <dt>Federation</dt><dd>Germany</dd>
                  <dt>B-Year</dt><dd>1990</dd>
                  <dt>Gender</dt><dd>Male</dd>
                  <dt>FIDE title</dt><dd>None</dd>
                </dl>
                <section>
                  <span>1968</span><strong>STANDARD</strong>
                  <span>1800</span><strong>RAPID</strong>
                  <span>1750</span><strong>BLITZ</strong>
                </section>
              </body>
            </html>
            """;
        var handler = new StaticHtmlHandler(html);
        using var httpClient = new HttpClient(handler)
        {
            BaseAddress = new Uri("https://ratings.fide.com/")
        };
        var provider = new FidePlayerLookupProvider(httpClient);

        var result = await provider.LookupByIdAsync("4610563");

        Assert.Equal(ExternalPlayerLookupStatus.Found, result.Status);
        var requestUri = handler.LastRequestUri?.ToString() ?? string.Empty;
        Assert.True(requestUri.EndsWith("profile/4610563", StringComparison.OrdinalIgnoreCase), $"Unexpected request URI: {requestUri}");
        var player = Assert.Single(result.Players);
        Assert.Equal("4610563", player.FideId);
        Assert.Equal("Geisshirt, Marco", player.Name);
        Assert.Equal("Germany", player.Federation);
        Assert.Equal(1990, player.BirthYear);
        Assert.Equal(GenderCategory.Male, player.Gender);
        Assert.Equal(1968, player.Elo);
        Assert.Equal(1800, player.RapidElo);
        Assert.Equal(1750, player.BlitzElo);
    }

    [Fact]
    public async Task LookupByIdAsync_ReturnsInvalid_ForNonNumericId()
    {
        using var httpClient = new HttpClient(new StaticHtmlHandler("<html></html>"))
        {
            BaseAddress = new Uri("https://ratings.fide.com/")
        };
        var provider = new FidePlayerLookupProvider(httpClient);

        var result = await provider.LookupByIdAsync("abc");

        Assert.Equal(ExternalPlayerLookupStatus.InvalidRequest, result.Status);
        Assert.Empty(result.Players);
    }

    private sealed class StaticHtmlHandler(string html) : HttpMessageHandler
    {
        public Uri? LastRequestUri { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastRequestUri = request.RequestUri;
            var response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(html, Encoding.UTF8, "text/html")
            };
            return Task.FromResult(response);
        }
    }
}
