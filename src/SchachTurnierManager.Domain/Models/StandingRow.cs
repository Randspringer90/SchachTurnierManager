namespace SchachTurnierManager.Domain.Models;

public sealed record StandingRow
{
    public int Rank { get; init; }
    public Guid PlayerId { get; init; }
    public string Name { get; init; } = string.Empty;
    public int StartingRank { get; init; }
    public int Twz { get; init; }
    public decimal Points { get; init; }
    public int Wins { get; init; }
    public int BlackWins { get; init; }
    public decimal DirectEncounter { get; init; }
    public decimal Buchholz { get; init; }
    public decimal BuchholzCutOne { get; init; }
    public decimal BuchholzCutTwo { get; init; }
    public decimal MedianBuchholz { get; init; }
    public decimal SonnebornBerger { get; init; }
    public decimal KoyaScore { get; init; }
    public decimal ProgressiveScore { get; init; }
    public decimal AverageOpponentRating { get; init; }
    public int? TournamentPerformance { get; init; }
    public decimal HeroScore { get; init; }
    public IReadOnlyDictionary<string, bool> Categories { get; init; } = new Dictionary<string, bool>();
}
