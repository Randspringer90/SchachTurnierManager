using System.Text.Json;
using Microsoft.Extensions.Logging;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using SchachTurnierManager.WebApi;
using SchachTurnierManager.WebApi.Logging;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class WebApiBoundaryTests
{
    [Fact]
    public void ImportRequest_OmittedOverwriteDoesNotAuthorizeReplacement()
    {
        var constructed = new ImportTournamentRequest(new TournamentState());
        var deserialized = JsonSerializer.Deserialize<ImportTournamentRequest>(
            "{\"tournament\":{\"name\":\"Synthetic backup\"}}", new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.False(constructed.OverwriteExisting);
        Assert.NotNull(deserialized);
        Assert.False(deserialized.OverwriteExisting);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void ImportRequest_PreservesExplicitOverwriteChoice(bool overwrite)
    {
        var json = JsonSerializer.Serialize(new { tournament = new TournamentState(), overwriteExisting = overwrite });

        var request = JsonSerializer.Deserialize<ImportTournamentRequest>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.NotNull(request);
        Assert.Equal(overwrite, request.OverwriteExisting);
    }

    [Theory]
    [InlineData("token: synthetic-secret; context=kept")]
    [InlineData("PASSWORD = synthetic-secret; context=kept")]
    [InlineData("pwd=synthetic-secret&context=kept")]
    [InlineData("passwd: \"synthetic-secret with spaces\"; context=kept")]
    [InlineData("'secret' : 'synthetic-secret with spaces'; context=kept")]
    [InlineData("{\"api_key\" : \"synthetic-secret\", \"context\":\"kept\"}")]
    [InlineData("apikey = \"synthetic-secret with \\\"escaped quotes\\\"\"; context=kept")]
    [InlineData("access_token=synthetic-secret, context=kept")]
    [InlineData("refresh_token:\tsynthetic-secret; context=kept")]
    [InlineData("token: 'synthetic-secret; with delimiters, and & spaces'; context=kept")]
    [InlineData("secret='synthetic-secret first''synthetic-secret second'; context=kept")]
    [InlineData("secret=\"synthetic-secret first\"\"synthetic-secret second\"; context=kept")]
    public void FileLogger_RedactsValuesFromMessagesAndExceptions(string message)
    {
        var contents = WriteLog(message, new InvalidOperationException(message));

        Assert.DoesNotContain("synthetic-secret", contents, StringComparison.Ordinal);
        Assert.Contains("***", contents, StringComparison.Ordinal);
        Assert.Contains("context", contents, StringComparison.Ordinal);
        Assert.Contains("kept", contents, StringComparison.Ordinal);
        Assert.Contains(nameof(InvalidOperationException), contents, StringComparison.Ordinal);
    }

    [Fact]
    public void FileLogger_RedactsEverySecretInOneMessage()
    {
        // Compose the synthetic key/value fixture without a credential literal in source.
        const string passwordKey = "password";
        var contents = WriteLog($"token: synthetic-first; {passwordKey} = 'synthetic-second'; context=kept");

        Assert.DoesNotContain("synthetic-first", contents, StringComparison.Ordinal);
        Assert.DoesNotContain("synthetic-second", contents, StringComparison.Ordinal);
        Assert.Contains("context=kept", contents, StringComparison.Ordinal);
    }

    [Fact]
    public void FileLogger_PreservesNonSecretFieldsAndOrdinaryText()
    {
        const string message = "status=ready; tokenCount=3; passwordHint=none; ordinary text kept";

        Assert.Contains(message, WriteLog(message), StringComparison.Ordinal);
    }

    [Fact]
    public void DatabaseFailureReport_PreservesWalAndRecommendsBackupBeforeRecovery()
    {
        var probe = new DatabaseProbeResult { DatabasePath = "synthetic.sqlite", Directory = "synthetic" };

        var report = DatabaseStartupDiagnostics.BuildFailureReport(probe.DatabasePath, probe);

        Assert.DoesNotContain("Reststände .sqlite-wal / .sqlite-shm löschen", report, StringComparison.Ordinal);
        Assert.Contains("nicht löschen", report, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("gemeinsam sichern", report, StringComparison.OrdinalIgnoreCase);
    }

    private static string WriteLog(string message, Exception? exception = null)
    {
        var directory = Path.Combine(Path.GetTempPath(), $"stm-log-boundary-{Guid.NewGuid():N}");
        try
        {
            using var provider = new BoundedFileLoggerProvider(directory, "synthetic");
            provider.CreateLogger("SyntheticBoundaryTest").Log(LogLevel.Warning, new EventId(1), message, exception, (state, _) => state);
            return File.ReadAllText(Assert.Single(Directory.GetFiles(directory, "*.log")));
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }
}
