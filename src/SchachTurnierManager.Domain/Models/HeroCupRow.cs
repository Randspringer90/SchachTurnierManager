namespace SchachTurnierManager.Domain.Models;

public sealed record HeroCupRow
{
    public int Rank { get; init; }
    public Guid PlayerId { get; init; }
    public string Name { get; init; } = string.Empty;
    public int Twz { get; init; }
    public int RatedGames { get; init; }
    public decimal ActualScore { get; init; }
    public decimal ExpectedScore { get; init; }
    public decimal OverPerformance { get; init; }
    public decimal AverageOpponentRating { get; init; }
    public int? TournamentPerformance { get; init; }
    public string Reason { get; init; } = string.Empty;
}
