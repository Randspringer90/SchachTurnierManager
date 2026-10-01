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
        Assert.Contains("# tests 70", output);
        Assert.Contains("# fail 0", output);
    }
}
