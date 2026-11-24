using System.Net;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace SchachTurnierManager.WebApi.Security;

/// <summary>Local API boundary, independent of browser CORS response filtering.</summary>
public sealed class LocalApiAccessGuard
{
    private readonly RequestDelegate _next;
    private readonly bool _development;
    private readonly HashSet<string> _lanHosts;
    private readonly byte[]? _lanCredentialHash;

    public LocalApiAccessGuard(RequestDelegate next, IConfiguration configuration, IHostEnvironment environment)
    {
        _next = next;
        _development = environment.IsDevelopment();
        _lanHosts = configuration.GetSection("SchachTurnierManager:AllowedLanHosts").GetChildren()
            .Select(item => item.Value?.Trim().ToLowerInvariant())
            .Where(host => host is not null && Uri.CheckHostName(host) != UriHostNameType.Unknown && !host.Contains('*'))
            .Select(host => host!).ToHashSet(StringComparer.OrdinalIgnoreCase);
        // No generated credentials or persisted plaintext. Operators must configure
        // an existing protected environment/secret source and a TLS listener.
        var credential = configuration["SchachTurnierManager:LanAccessToken"];
        if (credential is { Length: >= 32 and <= 256 } && !string.IsNullOrWhiteSpace(credential))
            _lanCredentialHash = SHA256.HashData(Encoding.UTF8.GetBytes(credential));
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Path.StartsWithSegments("/api", StringComparison.OrdinalIgnoreCase)) { await _next(context); return; }
        string host;
        try { host = context.Request.Host.Host.Trim('[', ']').ToLowerInvariant(); }
        catch (FormatException) { context.Response.StatusCode = 400; return; }
        var loopbackHost = host == "localhost" || host is "127.0.0.1" or "::1";
        var remote = context.Connection.RemoteIpAddress;
        if (remote?.IsIPv4MappedToIPv6 == true) remote = remote.MapToIPv4();
        var localClient = remote is not null && IPAddress.IsLoopback(remote);
        if (!loopbackHost && localClient && !_lanHosts.Contains(host)) { context.Response.StatusCode = 400; return; }
        if (!(localClient && loopbackHost))
        {
            var supplied = context.Request.Headers["X-STM-Lan-Token"];
            if (!context.Request.IsHttps || !_lanHosts.Contains(host) || _lanCredentialHash is null || supplied.Count != 1 ||
                supplied[0] is not { Length: >= 32 and <= 256 } candidate ||
                !CryptographicOperations.FixedTimeEquals(_lanCredentialHash, SHA256.HashData(Encoding.UTF8.GetBytes(candidate))))
            { context.Response.StatusCode = 403; return; }
        }
        var origins = context.Request.Headers.Origin;
        if (origins.Count != 0)
        {
            if (origins.Count != 1 || !Uri.TryCreate(origins[0], UriKind.Absolute, out var origin) ||
                origin.Scheme is not ("http" or "https") || origin.UserInfo.Length != 0 || origin.AbsolutePath != "/" ||
                origin.Query.Length != 0 || origin.Fragment.Length != 0)
            { context.Response.StatusCode = 403; return; }
            var requestPort = context.Request.Host.Port ?? (context.Request.IsHttps ? 443 : 80);
            var sameOrigin = origin.Scheme.Equals(context.Request.Scheme, StringComparison.OrdinalIgnoreCase) &&
                origin.Host.Trim('[', ']').Equals(host, StringComparison.OrdinalIgnoreCase) && origin.Port == requestPort;
            var developmentOrigin = _development && localClient && loopbackHost && origin.Port == 5173 &&
                origin.Host.Trim('[', ']') is "localhost" or "127.0.0.1" && origin.Scheme is "http" or "https";
            if (!sameOrigin && !developmentOrigin) { context.Response.StatusCode = 403; return; }
        }
        else if (context.Request.Headers["Sec-Fetch-Site"] == "cross-site")
        { context.Response.StatusCode = 403; return; }
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        await _next(context);
    }
}
