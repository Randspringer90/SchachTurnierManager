using System.Diagnostics;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class DependencySupplyChainReadinessTests
{
    [Fact]
    public async Task DependencyGate_PassesSyntheticPositiveAndNegativeCases()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "SchachTurnierManager.sln")))
        {
            directory = directory.Parent;
        }

        Assert.NotNull(directory);
        var start = new ProcessStartInfo("pwsh")
        {
            WorkingDirectory = directory.FullName,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        start.ArgumentList.Add("-NoLogo");
        start.ArgumentList.Add("-NoProfile");
        start.ArgumentList.Add("-File");
        start.ArgumentList.Add(Path.Combine(directory.FullName, "scripts", "Test-DependencySupplyChainReadiness.ps1"));
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
        Assert.Contains("DEPENDENCY_READINESS=PASS; CASES=32", output);
    }
}
