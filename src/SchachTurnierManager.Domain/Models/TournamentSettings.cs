namespace SchachTurnierManager.Domain.Models;

public sealed record TournamentSettings
{
    public TournamentFormat Format { get; init; } = TournamentFormat.Swiss;
    public ScoringSystem ScoringSystem { get; init; } = ScoringSystem.ClassicalOneHalfZero;
    public TwzSource TwzSource { get; init; } = TwzSource.ManualThenDwzThenElo;
    public int PlannedRounds { get; init; } = 5;
    public IReadOnlyList<TiebreakType> Tiebreaks { get; init; } = new[]
    {
        TiebreakType.DirectEncounter,
        TiebreakType.NumberOfWins,
        TiebreakType.Buchholz,
        TiebreakType.SonnebornBerger,
        TiebreakType.TournamentPerformance,
        TiebreakType.StartingRank
    };
    public bool AllowManualPairingOverrides { get; init; } = true;
    public ForfeitTiebreakPolicy ForfeitTiebreakPolicy { get; init; } = ForfeitTiebreakPolicy.ExcludeForfeitsFromTiebreaks;
    public bool CountByeAsWin { get; init; }
    public int? SeniorBirthYearOrEarlier { get; init; }
    public int HeroCupMinimumRatedGames { get; init; } = 1;
}
