using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using SchachTurnierManager.WebApi.Security;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class LocalApiAccessGuardTests
{
    private sealed class TestEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Production;
        public string ApplicationName { get; set; } = "Synthetic";
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
    private static async Task<int> Request(string host = "127.0.0.1:5088", string? origin = null, string remote = "127.0.0.1", string scheme = "http", string? credential = null, bool configuredLan = false, bool development = false)
    {
        var config = new Dictionary<string, string?>();
        if (configuredLan) { config["SchachTurnierManager:LanAccessToken"] = new string('s', 48); config["SchachTurnierManager:AllowedLanHosts:0"] = "192.168.1.10"; }
        var context = new DefaultHttpContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse(remote);
        context.Request.Host = new HostString(host); context.Request.Scheme = scheme;
        context.Request.Path = "/api/tournaments"; context.Request.Method = "POST";
        if (origin is not null) context.Request.Headers.Origin = origin;
        if (credential is not null) context.Request.Headers["X-STM-Lan-Token"] = credential;
        var guard = new LocalApiAccessGuard(_ => { context.Response.StatusCode = 204; return Task.CompletedTask; },
            new ConfigurationBuilder().AddInMemoryCollection(config).Build(), new TestEnvironment { EnvironmentName = development ? Environments.Development : Environments.Production });
        await guard.InvokeAsync(context);
        return context.Response.StatusCode;
    }
    [Theory]
    [InlineData("127.0.0.1:5088", "http://127.0.0.1:5088", "127.0.0.1")]
    [InlineData("localhost:5088", "http://localhost:5088", "127.0.0.1")]
    [InlineData("[::1]:5088", "http://[::1]:5088", "::1")]
    public async Task LocalSameOriginClientWorks(string host, string origin, string remote) => Assert.Equal(204, await Request(host, origin, remote));

    [Theory]
    [InlineData("https://synthetic-attacker.invalid")]
    [InlineData("null")]
    [InlineData("http://localhost:5088/extra")]
    [InlineData("http://localhost:5088?query")]
    [InlineData("http://user@127.0.0.1:5088")]
    [InlineData("http://127.0.0.1:5173")]
    [InlineData("http://127.0.0.1:5088, https://synthetic-attacker.invalid")]
    public async Task ForeignMalformedOrProductionDevOriginNeverReachesAnEndpoint(string origin) => Assert.Equal(403, await Request(origin: origin));

    [Theory]
    [InlineData("synthetic-rebinding.invalid:5088")]
    [InlineData("localhost.synthetic.invalid:5088")]
    [InlineData("2130706433:5088")]
    public async Task ArbitraryHostCannotRebindLoopback(string host) => Assert.Equal(400, await Request(host));

    [Fact]
    public async Task ExplicitDevelopmentOriginWorksOnlyInDevelopment()
    {
        Assert.Equal(204, await Request(origin: "http://localhost:5173", development: true));
        Assert.Equal(403, await Request(origin: "http://localhost:5173"));
    }

    [Fact]
    public async Task LanRequiresExplicitHostTlsAndValidCredential()
    {
        Assert.Equal(403, await Request("192.168.1.10:5088", remote: "192.168.1.20"));
        Assert.Equal(403, await Request("192.168.1.10:5088", remote: "192.168.1.20", configuredLan: true, credential: new string('s', 48)));
        Assert.Equal(403, await Request("192.168.1.10:5088", remote: "192.168.1.20", configuredLan: true, scheme: "https"));
        Assert.Equal(403, await Request("192.168.1.10:5088", remote: "192.168.1.20", configuredLan: true, scheme: "https", credential: new string('x', 48)));
        Assert.Equal(204, await Request("192.168.1.10:5088", remote: "192.168.1.20", configuredLan: true, scheme: "https", credential: new string('s', 48)));
        Assert.Equal(403, await Request("192.168.1.99:5088", remote: "192.168.1.20", configuredLan: true, scheme: "https", credential: new string('s', 48)));
        Assert.Equal(403, await Request("192.168.1.10:5088", origin: "https://synthetic-attacker.invalid", remote: "192.168.1.20", configuredLan: true, scheme: "https", credential: new string('s', 48)));
    }
}
