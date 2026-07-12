using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class BergfestDemoScriptContractTests
{
    [Fact]
    public void DemoScript_AcceptsFridayRunbookPlayersAlias()
    {
        var scriptPath = FindRepositoryFile("scripts", "New-DemoTournament.ps1");
        var script = File.ReadAllText(scriptPath);

        Assert.Contains("[Alias(\"Players\")]", script);
        Assert.Contains("[int]$PlayerCount", script);
    }

    [Fact]
    public void PresetImportScript_UsesPreviewGateAndStructuredReport()
    {
        var scriptPath = FindRepositoryFile("scripts", "Import-TournamentPreset.ps1");
        var script = File.ReadAllText(scriptPath);

        Assert.Contains("[switch]$AllowWarnings", script);
        Assert.Contains("[switch]$ShowCsvPreview", script);
        Assert.Contains("players/preview-import.csv", script);
        Assert.Contains("preset-import-report-", script);
        Assert.Contains("Stop-WithReport", script);
    }

    private static string FindRepositoryFile(params string[] relativeParts)
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            var candidate = Path.Combine(new[] { current.FullName }.Concat(relativeParts).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            current = current.Parent;
        }

        throw new FileNotFoundException(
            $"Repository file not found: {Path.Combine(relativeParts)}",
            Path.Combine(relativeParts));
    }
}
