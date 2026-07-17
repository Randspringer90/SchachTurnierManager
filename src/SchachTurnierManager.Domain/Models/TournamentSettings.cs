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
    /// <summary>
    /// Auslosungsverfahren fuer <see cref="TournamentFormat.Swiss"/>. Standard bleibt die
    /// bestehende Optimal-V2-Engine; FIDE-Dutch wird bewusst ausgewaehlt (STM-FACH-002).
    /// </summary>
    public SwissPairingStrategyKind PairingStrategy { get; init; } = SwissPairingStrategyKind.OptimalMatchingV2;

    /// <summary>
    /// Die vor der ersten Runde ausgeloste Anfangsfarbe (FIDE C.04.3 Art. 5.1). Das ist ein
    /// Losentscheid des Turnierleiters, keine Berechnung: Die Engine wuerfelt nie selbst, sonst
    /// waere die Auslosung nicht reproduzierbar (C.04.2 Art. 1.4). Wirkt nur bei
    /// <see cref="SwissPairingStrategyKind.FideDutch"/> und entscheidet ueber Art. 5.2.5, welche
    /// Farbe der hoeher gesetzte Spieler bei ungerader Startnummer erhaelt.
    /// </summary>
    public ChessColor SwissInitialColour { get; init; } = ChessColor.White;

    public bool AllowManualPairingOverrides { get; init; } = true;
    public ForfeitTiebreakPolicy ForfeitTiebreakPolicy { get; init; } = ForfeitTiebreakPolicy.ExcludeForfeitsFromTiebreaks;
    public UnplayedRoundBuchholzMode UnplayedRoundBuchholzMode { get; init; } = UnplayedRoundBuchholzMode.IgnoreUnplayedRounds;
    public bool CountByeAsWin { get; init; }
    public int? SeniorBirthYearOrEarlier { get; init; }
    public int HeroCupMinimumRatedGames { get; init; } = 1;
}
