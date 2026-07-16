using System.Text.Json;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class TournamentSettingsTransportContractTests
{
    [Fact]
    public void ApiJsonRoundtrip_PreservesUnplayedRoundBuchholzMode()
    {
        var settings = new TournamentSettings
        {
            UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent
        };
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);

        var json = JsonSerializer.Serialize(settings, options);
        var restored = JsonSerializer.Deserialize<TournamentSettings>(json, options);

        Assert.Contains("\"unplayedRoundBuchholzMode\":1", json);
        Assert.NotNull(restored);
        Assert.Equal(UnplayedRoundBuchholzMode.FideVirtualOpponent, restored!.UnplayedRoundBuchholzMode);
    }

    [Fact]
    public void LegacyJsonWithoutNewField_UsesBackwardCompatibleDefault()
    {
        var restored = JsonSerializer.Deserialize<TournamentSettings>("{\"plannedRounds\":7}", new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.NotNull(restored);
        Assert.Equal(7, restored!.PlannedRounds);
        Assert.Equal(UnplayedRoundBuchholzMode.IgnoreUnplayedRounds, restored.UnplayedRoundBuchholzMode);
    }

    [Fact]
    public void BackupRestoreThroughImport_PreservesMode()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var backup = new TournamentState
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000099"),
            Name = "Backup",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                UnplayedRoundBuchholzMode = UnplayedRoundBuchholzMode.FideVirtualOpponent
            }
        };

        service.SaveImportedTournament(backup, overwriteExisting: false);
        var restored = service.RequireTournament(backup.Id);

        Assert.Equal(UnplayedRoundBuchholzMode.FideVirtualOpponent, restored.Settings.UnplayedRoundBuchholzMode);
        Assert.Contains(restored.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
    }

    [Fact]
    public void ApiAndUiContracts_TransportTheSameSetting()
    {
        var contracts = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Contracts.cs"));
        var ui = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApp", "src", "main.tsx"));

        Assert.Contains("UpdateTournamentSettingsRequest(TournamentSettings Settings)", contracts);
        Assert.Contains("unplayedRoundBuchholzMode: number", ui);
        Assert.Contains("unplayedRoundBuchholzMode: form.unplayedRoundBuchholzMode", ui);
        Assert.Contains("settings.unplayedRoundBuchholzMode ?? 0", ui);
        Assert.Contains("FIDE-Modus (Schweizer)", ui);
    }

    private static string FindRepositoryFile(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(new[] { directory.FullName }.Concat(segments).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException($"Repository-Datei nicht gefunden: {string.Join('/', segments)}");
    }
}
