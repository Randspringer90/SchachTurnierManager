using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public enum AuditJournalSortDirection
{
    NewestFirst = 0,
    OldestFirst = 1
}

public sealed record AuditJournalQuery
{
    public AuditJournalSeverity? Severity { get; init; }
    public AuditJournalAction? Action { get; init; }
    public int? RoundNumber { get; init; }
    public int? BoardNumber { get; init; }
    public Guid? PlayerId { get; init; }
    public string? SearchText { get; init; }
    public int? MaxResults { get; init; } = 50;
    public AuditJournalSortDirection SortDirection { get; init; } = AuditJournalSortDirection.NewestFirst;
}

public sealed record AuditJournalStatistics
{
    public int TotalCount { get; init; }
    public int InfoCount { get; init; }
    public int WarningCount { get; init; }
    public int CriticalCount { get; init; }
    public int RoundRelatedCount { get; init; }
    public int BoardRelatedCount { get; init; }
    public int PlayerRelatedCount { get; init; }
    public DateTimeOffset? LatestCreatedAt { get; init; }
    public DateTimeOffset? OldestCreatedAt { get; init; }
}

public sealed record AuditJournalQueryResult
{
    public IReadOnlyList<AuditJournalEntry> Entries { get; init; } = Array.Empty<AuditJournalEntry>();
    public AuditJournalStatistics Statistics { get; init; } = new();
    public int TotalBeforePaging { get; init; }
    public int ReturnedCount => Entries.Count;
    public bool IsTruncated => ReturnedCount < TotalBeforePaging;
}

public sealed class AuditJournalQueryService
{
    private const int DefaultMaxResults = 50;
    private const int AbsoluteMaxResults = 500;

    public AuditJournalQueryResult Query(IEnumerable<AuditJournalEntry> entries, AuditJournalQuery? query = null)
    {
        ArgumentNullException.ThrowIfNull(entries);
        query ??= new AuditJournalQuery();

        var filtered = entries.Where(entry => Matches(entry, query));
        filtered = query.SortDirection == AuditJournalSortDirection.OldestFirst
            ? filtered.OrderBy(entry => entry.CreatedAt).ThenBy(entry => entry.Id)
            : filtered.OrderByDescending(entry => entry.CreatedAt).ThenBy(entry => entry.Id);

        var filteredList = filtered.ToList();
        var maxResults = NormalizeMaxResults(query.MaxResults);
        var page = filteredList.Take(maxResults).ToList();

        return new AuditJournalQueryResult
        {
            Entries = page,
            Statistics = BuildStatistics(filteredList),
            TotalBeforePaging = filteredList.Count
        };
    }

    public AuditJournalStatistics BuildStatistics(IEnumerable<AuditJournalEntry> entries)
    {
        ArgumentNullException.ThrowIfNull(entries);
        var list = entries.ToList();
        return new AuditJournalStatistics
        {
            TotalCount = list.Count,
            InfoCount = list.Count(entry => entry.Severity == AuditJournalSeverity.Info),
            WarningCount = list.Count(entry => entry.Severity == AuditJournalSeverity.Warning),
            CriticalCount = list.Count(entry => entry.Severity == AuditJournalSeverity.Critical),
            RoundRelatedCount = list.Count(entry => entry.RoundNumber is not null),
            BoardRelatedCount = list.Count(entry => entry.BoardNumber is not null),
            PlayerRelatedCount = list.Count(entry => entry.PlayerId is not null || !string.IsNullOrWhiteSpace(entry.PlayerName)),
            LatestCreatedAt = list.Count == 0 ? null : list.Max(entry => entry.CreatedAt),
            OldestCreatedAt = list.Count == 0 ? null : list.Min(entry => entry.CreatedAt)
        };
    }

    private static bool Matches(AuditJournalEntry entry, AuditJournalQuery query)
    {
        if (query.Severity is not null && entry.Severity != query.Severity)
        {
            return false;
        }

        if (query.Action is not null && entry.Action != query.Action)
        {
            return false;
        }

        if (query.RoundNumber is not null && entry.RoundNumber != query.RoundNumber)
        {
            return false;
        }

        if (query.BoardNumber is not null && entry.BoardNumber != query.BoardNumber)
        {
            return false;
        }

        if (query.PlayerId is not null && entry.PlayerId != query.PlayerId)
        {
            return false;
        }

        if (!string.IsNullOrWhiteSpace(query.SearchText) && !ContainsSearchText(entry, query.SearchText))
        {
            return false;
        }

        return true;
    }

    private static bool ContainsSearchText(AuditJournalEntry entry, string searchText)
    {
        var needle = searchText.Trim();
        if (needle.Length == 0)
        {
            return true;
        }

        return Contains(entry.Summary, needle)
            || Contains(entry.Details, needle)
            || Contains(entry.Reason, needle)
            || Contains(entry.Actor, needle)
            || Contains(entry.PlayerName, needle)
            || Contains(entry.Action.ToString(), needle)
            || Contains(entry.Severity.ToString(), needle)
            || (entry.RoundNumber is not null && Contains($"Runde {entry.RoundNumber}", needle))
            || (entry.BoardNumber is not null && Contains($"Brett {entry.BoardNumber}", needle));
    }

    private static bool Contains(string? value, string searchText)
    {
        return value?.IndexOf(searchText, StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static int NormalizeMaxResults(int? maxResults)
    {
        if (maxResults is null or <= 0)
        {
            return DefaultMaxResults;
        }

        return Math.Min(maxResults.Value, AbsoluteMaxResults);
    }
}
