namespace SchachTurnierManager.Domain.Models;

public sealed class TournamentState
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public DateOnly CreatedOn { get; init; } = DateOnly.FromDateTime(DateTime.Today);
    public TournamentSettings Settings { get; set; } = new();
    public List<Player> Players { get; init; } = new();
    public List<TournamentRound> Rounds { get; init; } = new();
    public List<AuditJournalEntry> AuditJournal { get; init; } = new();
}
