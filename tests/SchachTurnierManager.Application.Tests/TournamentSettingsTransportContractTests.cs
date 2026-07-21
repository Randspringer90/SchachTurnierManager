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
    public void ApiJsonRoundtrip_PreservesFideDutchPairingStrategyAndSwissInitialColour()
    {
        var settings = new TournamentSettings
        {
            PairingStrategy = SwissPairingStrategyKind.FideDutch,
            SwissInitialColour = ChessColor.Black
        };
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);

        var json = JsonSerializer.Serialize(settings, options);
        var restored = JsonSerializer.Deserialize<TournamentSettings>(json, options);

        Assert.NotNull(restored);
        Assert.Equal(SwissPairingStrategyKind.FideDutch, restored!.PairingStrategy);
        Assert.Equal(ChessColor.Black, restored.SwissInitialColour);
    }

    [Fact]
    public void LegacyJsonWithoutFideDutchFields_UsesOptimalV2AndWhiteDefaults()
    {
        var restored = JsonSerializer.Deserialize<TournamentSettings>("{\"plannedRounds\":7}", new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.NotNull(restored);
        Assert.Equal(SwissPairingStrategyKind.OptimalMatchingV2, restored!.PairingStrategy);
        Assert.Equal(ChessColor.White, restored.SwissInitialColour);
    }

    [Fact]
    public void BackupRestoreThroughImport_PreservesFideDutchPairingStrategyAndSwissInitialColour()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var backup = new TournamentState
        {
            Id = Guid.Parse("00000000-0000-0000-0000-000000000098"),
            Name = "Backup-FIDE-Dutch",
            Settings = new TournamentSettings
            {
                Format = TournamentFormat.Swiss,
                PairingStrategy = SwissPairingStrategyKind.FideDutch,
                SwissInitialColour = ChessColor.Black
            }
        };

        service.SaveImportedTournament(backup, overwriteExisting: false);
        var restored = service.RequireTournament(backup.Id);

        Assert.Equal(SwissPairingStrategyKind.FideDutch, restored.Settings.PairingStrategy);
        Assert.Equal(ChessColor.Black, restored.Settings.SwissInitialColour);
        Assert.Contains(restored.AuditJournal, entry => entry.Action == AuditJournalAction.TournamentImported);
    }

    [Fact]
    public void ApiAndUiContracts_TransportTheSameSetting()
    {
        var contracts = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApi", "Contracts.cs"));
        var ui = ReadWebAppSources();
        // STM-FE-013: the UI/API contract types were extracted from main.tsx into a
        // dedicated module. Type-field declarations are asserted there; the wiring
        // (form <-> settings mapping) stays asserted against main.tsx.
        var uiContracts = File.ReadAllText(FindRepositoryFile("src", "SchachTurnierManager.WebApp", "src", "api", "contracts.ts"));

        Assert.Contains("UpdateTournamentSettingsRequest(TournamentSettings Settings)", contracts);
        Assert.Contains("unplayedRoundBuchholzMode: number", uiContracts);
        Assert.Contains("unplayedRoundBuchholzMode: form.unplayedRoundBuchholzMode", ui);
        Assert.Contains("settings.unplayedRoundBuchholzMode ?? 0", ui);
        Assert.Contains("FIDE-Modus (Schweizer)", ui);
        Assert.Contains("pairingStrategy: number", uiContracts);
        Assert.Contains("swissInitialColour: number", uiContracts);
        Assert.Contains("pairingStrategy: form.pairingStrategy", ui);
        Assert.Contains("swissInitialColour: form.swissInitialColour", ui);
        Assert.Contains("settings.pairingStrategy ?? 0", ui);
        Assert.Contains("settings.swissInitialColour ?? 1", ui);
        Assert.Contains("settingsForm.pairingStrategy === 1", ui);
    }

    [Fact]
    public void BuildWeekDemoPreset_UsesOnlyExplicitSyntheticData()
    {
        var ui = ReadWebAppSources();

        Assert.Contains("async function createDemoTournament()", ui);
        Assert.Contains("Build Week Demo Open", ui);
        Assert.Contains("Demo Player ${String(index + 1).padStart(2, '0')}", ui);
        Assert.Contains("STM_BUILD_WEEK_DEMO_V1", ui);
        Assert.Contains("isBuildWeekDemoTournament", ui);
        Assert.Contains("tournaments.find(isBuildWeekDemoTournament)", ui);
        Assert.Contains("method: 'DELETE'", ui);
        Assert.Contains("pairingStrategy: 1", ui);
        Assert.Contains("plannedRounds: 3", ui);
        Assert.DoesNotContain("fideId: '11", ui);
    }

    [Fact]
    public void ResultEntry_RequiresConfirmationAndOffersUndo()
    {
        var ui = ReadWebAppSources();

        Assert.Contains("requestResultChange(", ui);
        Assert.Contains("confirmResultChange()", ui);
        Assert.Contains("undoLastResultChange()", ui);
        Assert.Contains("role=\"alertdialog\"", ui);
        Assert.Contains("tournamentId: selectedTournament.id", ui);
        Assert.Contains("expectedPreviousResult", ui);
        Assert.Contains("setPendingResultChange(null)", ui);
        Assert.Contains("setLastResultChange(null)", ui);
    }

    /// <summary>
    /// Concatenated text of every WebApp source file.
    /// </summary>
    /// <remarks>
    /// STM-FE-014 split the former <c>main.tsx</c> monolith into modules
    /// (app shell, lib helpers, feature components). These contract assertions
    /// care that the UI still transports a setting, not which file holds it, so
    /// they read the whole source tree and stay stable across further
    /// extraction steps.
    /// </remarks>
    private static string ReadWebAppSources()
    {
        var root = FindRepositoryDirectory("src", "SchachTurnierManager.WebApp", "src");
        var files = Directory
            .EnumerateFiles(root, "*.ts*", SearchOption.AllDirectories)
            .Where(path => path.EndsWith(".ts", StringComparison.Ordinal) || path.EndsWith(".tsx", StringComparison.Ordinal))
            .OrderBy(path => path, StringComparer.Ordinal);

        return string.Join("\n", files.Select(File.ReadAllText));
    }

    private static string FindRepositoryDirectory(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(new[] { directory.FullName }.Concat(segments).ToArray());
            if (Directory.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException($"Repository-Verzeichnis nicht gefunden: {string.Join('/', segments)}");
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
