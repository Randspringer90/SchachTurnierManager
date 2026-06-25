using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class DatabaseStartupDiagnosticsTests
{
    [Fact]
    public void Probe_WritableDirectory_ReportsHealthyAndCreatesDirectory()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-diag-{Guid.NewGuid():N}");
        var databasePath = Path.Combine(testDirectory, "tournament.sqlite");

        try
        {
            var probe = DatabaseStartupDiagnostics.Probe(databasePath);

            Assert.True(Directory.Exists(testDirectory));
            Assert.True(probe.DirectoryExists);
            Assert.True(probe.DirectoryWritable);
            Assert.False(probe.DatabaseFileReadOnly);
            Assert.Null(probe.Error);
            Assert.True(probe.IsHealthy);
        }
        finally
        {
            if (Directory.Exists(testDirectory))
            {
                Directory.Delete(testDirectory, recursive: true);
            }
        }
    }

    [Fact]
    public void Probe_ReadOnlyDatabaseFile_IsReportedAsUnhealthy()
    {
        var testDirectory = Path.Combine(Path.GetTempPath(), $"stm-diag-{Guid.NewGuid():N}");
        Directory.CreateDirectory(testDirectory);
        var databasePath = Path.Combine(testDirectory, "tournament.sqlite");
        File.WriteAllText(databasePath, "x");
        File.SetAttributes(databasePath, FileAttributes.ReadOnly);

        try
        {
            var probe = DatabaseStartupDiagnostics.Probe(databasePath);

            Assert.True(probe.DatabaseFileReadOnly);
            Assert.False(probe.IsHealthy);
        }
        finally
        {
            File.SetAttributes(databasePath, FileAttributes.Normal);
            Directory.Delete(testDirectory, recursive: true);
        }
    }

    [Fact]
    public void BuildFailureReport_ContainsActionableHints()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), "stm-nonexistent", "tournament.sqlite");
        var probe = DatabaseStartupDiagnostics.Probe(databasePath);

        var report = DatabaseStartupDiagnostics.BuildFailureReport(databasePath, probe, "SQLite Error 10: 'disk I/O error'.");

        Assert.Contains("disk I/O error", report, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("OneDrive", report, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(databasePath, report);

        // Aufräumen, falls die Probe das Verzeichnis angelegt hat.
        var directory = Path.GetDirectoryName(databasePath)!;
        if (Directory.Exists(directory))
        {
            Directory.Delete(directory, recursive: true);
        }
    }
}
