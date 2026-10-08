using System.Diagnostics;
using System.Text.RegularExpressions;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class DependencySupplyChainReadinessTests
{
    [Fact]
    public async Task DependencyGate_PassesSyntheticPositiveAndNegativeCases()
    {
        var root = FindRepositoryRoot();
        var (exitCode, output) = await RunPwshAsync(root, Path.Combine(root, "scripts", "Test-DependencySupplyChainReadiness.ps1"));

        Assert.True(exitCode == 0, output);
        // Count-independent: new synthetic cases must not break this wrapper.
        var match = Regex.Match(output, @"DEPENDENCY_READINESS=PASS; CASES=(\d+)");
        Assert.True(match.Success, output);
        Assert.True(int.Parse(match.Groups[1].Value, System.Globalization.CultureInfo.InvariantCulture) >= 43, output);
    }

    [Fact]
    public async Task DependencyGate_PassesOnTheRealRepositoryAndReportsItsLimits()
    {
        // The synthetic fixtures do not prove that the real manifests and lockfile pass.
        var root = FindRepositoryRoot();
        var (exitCode, output) = await RunPwshAsync(root, Path.Combine(root, "scripts", "Test-DependencySupplyChainSafety.ps1"), "-Root", root);

        Assert.True(exitCode == 0, output);
        Assert.Contains("DEPENDENCY_STRUCTURE=PASS", output);
        Assert.Matches(@"DEPENDENCY_NPM_EDGE_COUNT=\d+", output);
        // Limits stay visible: PARTIAL/minimum-only are reported, never hidden as complete.
        Assert.Matches(@"DEPENDENCY_PROVENANCE=(PARTIAL|METADATA_COMPLETE)", output);
        Assert.Matches(@"DEPENDENCY_NUGET_PINNING=(EXACT|MINIMUM_ONLY; COUNT=\d+)", output);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "SchachTurnierManager.sln")))
        {
            directory = directory.Parent;
        }

        Assert.NotNull(directory);
        return directory.FullName;
    }

    private static async Task<(int ExitCode, string Output)> RunPwshAsync(string workingDirectory, string script, params string[] arguments)
    {
        var start = new ProcessStartInfo("pwsh")
        {
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        start.ArgumentList.Add("-NoLogo");
        start.ArgumentList.Add("-NoProfile");
        start.ArgumentList.Add("-File");
        start.ArgumentList.Add(script);
        foreach (var argument in arguments)
        {
            start.ArgumentList.Add(argument);
        }

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

        return (process.ExitCode, await stdout + Environment.NewLine + await stderr);
    }
}
