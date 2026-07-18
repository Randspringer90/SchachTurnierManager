using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class BergfestWebApiStartupContractTests
{
    [Fact]
    public void WebApi_BindsContentRootToApplicationDirectoryNotCurrentWorkingDirectory()
    {
        // STM-REL-001: Desktop-/Portable-Starts ueber "start" bzw. Verknuepfungen erben ein
        // beliebiges Arbeitsverzeichnis. Bleibt ContentRootPath am Default (CWD), wird wwwroot
        // nicht gefunden und das eingebettete Dashboard still durch die API-Fallback-Seite
        // ersetzt. Der Bau ueber WebApplicationOptions.ContentRootPath = AppContext.BaseDirectory
        // ist damit ein Verhaltensvertrag und darf nicht versehentlich zurueckgebaut werden.
        var programPath = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs");
        var program = File.ReadAllText(programPath);

        Assert.Contains("ContentRootPath = AppContext.BaseDirectory", program);
        Assert.DoesNotContain("WebApplication.CreateBuilder(args)", program);
    }

    [Fact]
    public void WebApi_UsesConfiguredSingleLineConsoleLoggingForLocalOperatorStartup()
    {
        var programPath = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs");
        var program = File.ReadAllText(programPath);

        Assert.Contains("builder.Logging.ClearProviders();", program);
        Assert.Contains("builder.Logging.AddConfiguration(builder.Configuration.GetSection(\"Logging\"));", program);
        Assert.Contains("builder.Logging.AddSimpleConsole", program);
        Assert.Contains("options.SingleLine = true;", program);
        Assert.Contains("SchachTurnierManager.Http", program);
    }

    [Fact]
    public void WebApi_Trf16ExportEndpoint_IsRegisteredAndDelegatesToTournamentService()
    {
        var programPath = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs");
        var program = File.ReadAllText(programPath);

        Assert.Contains("app.MapGet(\"/api/tournaments/{id:guid}/standings/export.trf16\"", program);
        Assert.Contains("ToDownload(service.ExportTrf16(id))", program);
    }

    [Fact]
    public void WebApi_ContainsDefaultLoggingConfigurationFiles()
    {
        var appSettings = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "appsettings.json");
        var developmentSettings = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "appsettings.Development.json");

        var appSettingsText = File.ReadAllText(appSettings);
        var developmentSettingsText = File.ReadAllText(developmentSettings);

        Assert.Contains("\"SchachTurnierManager\": \"Information\"", appSettingsText);
        Assert.Contains("\"SchachTurnierManager\": \"Debug\"", developmentSettingsText);
        Assert.Contains("\"Microsoft.EntityFrameworkCore\": \"Warning\"", appSettingsText);
    }

    [Fact]
    public void PublicHealthResponse_DoesNotExposeAbsoluteStoragePaths()
    {
        var programPath = FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Program.cs");
        var program = File.ReadAllText(programPath);

        Assert.DoesNotContain("databasePath = databaseFullPath", program);
        Assert.DoesNotContain("directory = runtimeLogDirectory", program);
        Assert.Contains("storage = \"local\"", program);
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
