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
