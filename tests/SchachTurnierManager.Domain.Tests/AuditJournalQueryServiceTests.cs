using Xunit;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Domain.Tests;

public sealed class AuditJournalQueryServiceTests
{
    private readonly AuditJournalQueryService _service = new();

    [Fact]
    public void Query_FiltersBySeverityAndRound()
    {
        var entries = CreateEntries();

        var result = _service.Query(entries, new AuditJournalQuery
        {
            Severity = AuditJournalSeverity.Warning,
            RoundNumber = 2
        });

        var entry = Assert.Single(result.Entries);
        Assert.Equal(AuditJournalAction.PairingOverridden, entry.Action);
        Assert.Equal(2, entry.RoundNumber);
        Assert.Equal(1, result.Statistics.WarningCount);
        Assert.Equal(0, result.Statistics.CriticalCount);
    }

    [Fact]
    public void Query_SearchesAcrossSummaryDetailsReasonActorAndPlayer()
    {
        var entries = CreateEntries();

        var byReason = _service.Query(entries, new AuditJournalQuery { SearchText = "falsches Ergebnis" });
        var byPlayer = _service.Query(entries, new AuditJournalQuery { SearchText = "Spieler B" });
        var byAction = _service.Query(entries, new AuditJournalQuery { SearchText = "RoundLocked" });

        Assert.Single(byReason.Entries);
        Assert.Single(byPlayer.Entries);
        Assert.Single(byAction.Entries);
        Assert.Equal(AuditJournalAction.ResultRecorded, byReason.Entries[0].Action);
        Assert.Equal(AuditJournalAction.PlayerStatusChanged, byPlayer.Entries[0].Action);
        Assert.Equal(AuditJournalAction.RoundLocked, byAction.Entries[0].Action);
    }

    [Fact]
    public void Query_DefaultSortsNewestFirstAndSupportsPaging()
    {
        var entries = CreateEntries();

        var result = _service.Query(entries, new AuditJournalQuery { MaxResults = 2 });

        Assert.Equal(2, result.ReturnedCount);
        Assert.True(result.IsTruncated);
        Assert.Equal(entries.Count, result.TotalBeforePaging);
        Assert.True(result.Entries[0].CreatedAt >= result.Entries[1].CreatedAt);
        Assert.Equal(AuditJournalAction.RoundLocked, result.Entries[0].Action);
    }

    [Fact]
    public void Query_CanSortOldestFirst()
    {
        var entries = CreateEntries();

        var result = _service.Query(entries, new AuditJournalQuery
        {
            SortDirection = AuditJournalSortDirection.OldestFirst,
            MaxResults = 1
        });

        var entry = Assert.Single(result.Entries);
        Assert.Equal(AuditJournalAction.TournamentCreated, entry.Action);
        Assert.False(result.Entries[0].CreatedAt > entries[1].CreatedAt);
    }

    [Fact]
    public void BuildStatistics_CountsSeverityAndReferences()
    {
        var entries = CreateEntries();

        var stats = _service.BuildStatistics(entries);

        Assert.Equal(6, stats.TotalCount);
        Assert.Equal(3, stats.InfoCount);
        Assert.Equal(2, stats.WarningCount);
        Assert.Equal(1, stats.CriticalCount);
        Assert.Equal(4, stats.RoundRelatedCount);
        Assert.Equal(2, stats.BoardRelatedCount);
        Assert.Equal(1, stats.PlayerRelatedCount);
        Assert.Equal(entries.Max(entry => entry.CreatedAt), stats.LatestCreatedAt);
        Assert.Equal(entries.Min(entry => entry.CreatedAt), stats.OldestCreatedAt);
    }

    private static IReadOnlyList<AuditJournalEntry> CreateEntries()
    {
        var playerId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
        var start = new DateTimeOffset(2026, 6, 9, 12, 0, 0, TimeSpan.Zero);

        return new[]
        {
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(0),
                Action = AuditJournalAction.TournamentCreated,
                Summary = "Turnier angelegt",
                Severity = AuditJournalSeverity.Info,
                Actor = "Turnierleitung"
            },
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(1),
                Action = AuditJournalAction.RoundGenerated,
                Summary = "Runde 1 ausgelost",
                Severity = AuditJournalSeverity.Info,
                RoundNumber = 1
            },
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(2),
                Action = AuditJournalAction.ResultRecorded,
                Summary = "Ergebnis eingetragen",
                Details = "1-0 wurde auf 0-1 korrigiert",
                Reason = "Falsches Ergebnis gemeldet",
                Severity = AuditJournalSeverity.Warning,
                RoundNumber = 1,
                BoardNumber = 2
            },
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(3),
                Action = AuditJournalAction.PlayerStatusChanged,
                Summary = "Spielerstatus geändert",
                Severity = AuditJournalSeverity.Critical,
                PlayerId = playerId,
                PlayerName = "Spieler B"
            },
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(4),
                Action = AuditJournalAction.PairingOverridden,
                Summary = "Paarung manuell geändert",
                Details = "Brett 1 korrigiert",
                Severity = AuditJournalSeverity.Warning,
                RoundNumber = 2,
                BoardNumber = 1
            },
            new AuditJournalEntry
            {
                CreatedAt = start.AddMinutes(5),
                Action = AuditJournalAction.RoundLocked,
                Summary = "Runde 2 gesperrt",
                Severity = AuditJournalSeverity.Info,
                RoundNumber = 2
            }
        };
    }
}
