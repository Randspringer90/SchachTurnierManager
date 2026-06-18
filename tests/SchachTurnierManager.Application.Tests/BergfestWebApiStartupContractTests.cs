using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class BergfestWebApiStartupContractTests
{
    [Fact]
    public void WebApi_UsesConsoleLoggingForLocalOperatorStartup()
    {
        var programPath = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs");
        var program = File.ReadAllText(programPath);

        Assert.Contains("builder.Logging.ClearProviders();", program);
        Assert.Contains("builder.Logging.AddConsole();", program);
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
