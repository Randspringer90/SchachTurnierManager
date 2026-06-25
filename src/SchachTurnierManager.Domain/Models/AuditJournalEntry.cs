namespace SchachTurnierManager.Domain.Models;

public enum AuditJournalAction
{
    TournamentCreated = 0,
    SettingsUpdated = 1,
    TournamentImported = 2,
    ExternalPlayerApplied = 3,
    TournamentReset = 4,
    PlayerAdded = 10,
    PlayerUpdated = 11,
    PlayerStatusChanged = 12,
    PlayerRemoved = 13,
    PlayerWithdrawn = 14,
    TournamentDeleted = 5,
    RoundGenerated = 20,
    ResultRecorded = 21,
    PairingOverridden = 22,
    RoundLocked = 23,
    RoundUnlocked = 24,
    RoundVerified = 25,
    RoundUnverified = 26,
    Chess960StartPositionsRolled = 27,
    RoundPreviewGenerated = 28,
    PairingGenerationBlocked = 29,
    AuditJournalExported = 30,
    AuditJournalMirrorFailed = 31
}

public enum AuditJournalSeverity
{
    Info = 0,
    Warning = 1,
    Critical = 2
}

public sealed record AuditJournalEntry
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public DateTimeOffset CreatedAt { get; init; } = DateTimeOffset.UtcNow;
    public AuditJournalAction Action { get; init; }
    public AuditJournalSeverity Severity { get; init; } = AuditJournalSeverity.Info;
    public string Actor { get; init; } = "Turnierleitung";
    public string Summary { get; init; } = string.Empty;
    public string? Details { get; init; }
    public string? Reason { get; init; }
    public int? RoundNumber { get; init; }
    public int? BoardNumber { get; init; }
    public Guid? PlayerId { get; init; }
    public string? PlayerName { get; init; }
}
