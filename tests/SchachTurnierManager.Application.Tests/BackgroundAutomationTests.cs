using System.Diagnostics;
using System.Text.Json;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class BackgroundAutomationTests
{
    [Fact]
    public void RuntimeBindings_UseReviewedExplicitModelsWithoutChangingSafety()
    {
        using var policy = JsonDocument.Parse(File.ReadAllText(RepositoryFile("config", "provider-runtime-policy.json")));
        var root = policy.RootElement;
        var providers = root.GetProperty("providers");
        Assert.Equal("gpt-6.1-sol", Model(providers, "openai", "sol"));
        Assert.Equal("gpt-6.1-sol", Model(providers, "openai", "luna"));
        Assert.Equal("gpt-6-luna", Model(providers, "openai", "terra"));
        Assert.Equal("claude-fable-5-1", Model(providers, "anthropic", "fabel"));
        Assert.Equal("claude-opus-5-5", Model(providers, "anthropic", "opus"));
        Assert.Equal("claude-sonnet-5-5", Model(providers, "anthropic", "sonnet"));
        var safety = root.GetProperty("safety");
        Assert.False(safety.GetProperty("childrenMayCommit").GetBoolean());
        Assert.False(safety.GetProperty("childrenMayPush").GetBoolean());
        Assert.True(safety.GetProperty("noSilentModelSwitch").GetBoolean());
    }

    [Fact]
    public async Task BackgroundRunner_ExecutesRealProcessRegressionSuite()
    {
        var script = RepositoryFile("scripts", "Test-BackgroundProcess.ps1");
        var root = Directory.GetParent(Path.GetDirectoryName(script)!)!.FullName;
        var start = new ProcessStartInfo
        {
            FileName = "pwsh",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };
        foreach (var argument in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-File", script, "-Root", root })
        {
            start.ArgumentList.Add(argument);
        }
        // PowerShell 7 is a declared integration-test prerequisite (also present in Windows CI).
        // A missing runtime is an error, never an implicit skip or a fabricated PASS.
        using var process = Process.Start(start) ?? throw new InvalidOperationException("PowerShell test process did not start.");
        process.StandardInput.Close();
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(120));
        try
        {
            await process.WaitForExitAsync(deadline.Token);
            var output = await stdout.WaitAsync(deadline.Token);
            var error = await stderr.WaitAsync(deadline.Token);
            Assert.True(process.ExitCode == 0, $"Background process regression failed ({process.ExitCode}): {error}\n{output}");
            Assert.Contains("BACKGROUND_PROCESS_TEST=PASS", output);
            if (OperatingSystem.IsWindows()) { Assert.Contains("windowsConsoleProbe=True", output); }
        }
        finally
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(10_000);
            }
        }
    }

    private static string? Model(JsonElement providers, string provider, string profile) =>
        providers.GetProperty(provider).GetProperty("profiles").GetProperty(profile).GetProperty("model").GetString();

    private static string RepositoryFile(params string[] parts)
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            var path = Path.Combine(new[] { directory.FullName }.Concat(parts).ToArray());
            if (File.Exists(path)) { return path; }
        }
        throw new FileNotFoundException($"Repository file not found: {Path.Combine(parts)}");
    }
}
