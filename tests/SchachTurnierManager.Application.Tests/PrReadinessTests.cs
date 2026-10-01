using System.Diagnostics;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PrReadinessTests
{
    [Fact]
    public async Task PrReadiness_PassesOfflineRegressionTests()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "SchachTurnierManager.sln")))
        {
            directory = directory.Parent;
        }

        Assert.NotNull(directory);
        var start = new ProcessStartInfo("node")
        {
            WorkingDirectory = directory.FullName,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        start.ArgumentList.Add("--test");
        start.ArgumentList.Add("--test-reporter=tap");
        start.ArgumentList.Add(Path.Combine(directory.FullName, "tests", "scripts", "pr-readiness.test.mjs"));
        start.ArgumentList.Add(Path.Combine(directory.FullName, "tests", "scripts", "pr-readiness-progress.test.mjs"));
        using var process = Process.Start(start);
        Assert.NotNull(process);
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(3));
        try
        {
            await process.WaitForExitAsync(timeout.Token);
        }
        catch (OperationCanceledException)
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
            }
            throw;
        }

        var output = await stdout;
        var errors = await stderr;
        Assert.True(process.ExitCode == 0, output + Environment.NewLine + errors);
        // Count-independent: adding a passing test must not break this wrapper.
        var total = TapCounter(output, "tests");
        Assert.True(total > 0, output);
        Assert.Equal(total, TapCounter(output, "pass"));
        Assert.Equal(0, TapCounter(output, "fail"));
    }

    private static int TapCounter(string output, string name)
    {
        var match = System.Text.RegularExpressions.Regex.Match(output, $@"(?m)^# {name} (\d+)\r?$");
        Assert.True(match.Success, $"TAP summary '# {name}' missing.");
        return int.Parse(match.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture);
    }
}
