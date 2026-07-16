namespace SchachTurnierManager.Domain.Models;

public enum ChessColor
{
    None = 0,
    White = 1,
    Black = 2
}

public enum GenderCategory
{
    Unknown = 0,
    Open = 1,
    Female = 2,
    Male = 3,
    Diverse = 4
}

public enum PlayerStatus
{
    Active = 0,
    Paused = 1,
    Withdrawn = 2
}

public enum TournamentFormat
{
    RoundRobin = 0,
    Swiss = 1,
    Knockout = 2,
    DoubleElimination = 3,
    Rotation = 4
}

public enum ScoringSystem
{
    ClassicalOneHalfZero = 0,
    ThreeOneZero = 1,
    NorwayArmageddon = 2
}

/// <summary>
/// Auswaehlbare Auslosungsverfahren fuer das Schweizer System (STM-FACH-002).
/// Die Verfahren stehen nebeneinander und bleiben vergleichbar; ein Wechsel ist eine bewusste
/// Entscheidung des Turnierleiters und wird im Audit protokolliert.
/// </summary>
public enum SwissPairingStrategyKind
{
    /// <summary>
    /// Bisheriges Verfahren und weiterhin Standard: global optimiertes Minimum-Penalty-Matching
    /// (siehe docs/SWISS_PAIRING_ENGINE.md). Sehr gute Rematch-Vermeidung, aber bewusst kein
    /// vollstaendiges FIDE-Dutch.
    /// </summary>
    OptimalMatchingV2 = 0,

    /// <summary>
    /// FIDE (Dutch) System nach C.04.3 in der ab 01.02.2026 gueltigen Fassung
    /// (siehe docs/FIDE_DUTCH_REFERENCE.md).
    /// </summary>
    FideDutch = 1
}

public enum TwzSource
{
    ManualThenDwzThenElo = 0,
    ManualThenEloThenDwz = 1,
    ManualThenRapidThenBlitzThenDwzThenElo = 2
}

public enum ForfeitTiebreakPolicy
{
    ExcludeForfeitsFromTiebreaks = 0,
    CountForfeitOpponentForBuchholzOnly = 1,
    CountForfeitsAsNormalGames = 2
}

public enum UnplayedRoundBuchholzMode
{
    // Bisheriges Verhalten: eigene ungespielte Runden tragen nichts zum eigenen Buchholz bei.
    IgnoreUnplayedRounds = 0,
    // FIDE C.07 (03/2026) Art. 16: In Schweizer Turnieren werden ungespielte Runden
    // fuer Buchholz und seine Cut-/Median-Varianten nach dem Dummy-/VUR-Modell behandelt.
    FideVirtualOpponent = 1
}

public enum TiebreakType
{
    DirectEncounter = 0,
    NumberOfWins = 1,
    Buchholz = 2,
    BuchholzCutOne = 3,
    SonnebornBerger = 4,
    AverageOpponentRating = 5,
    TournamentPerformance = 6,
    BuchholzCutTwo = 7,
    MedianBuchholz = 8,
    ProgressiveScore = 9,
    KoyaScore = 10,
    NumberOfBlackWins = 11,
    StartingRank = 99
}

public enum RoundResultStatus
{
    Open = 0,
    Complete = 1,
    Verified = 2,
    Locked = 3
}

public enum GameResultKind
{
    NotPlayed = 0,
    WhiteWin = 1,
    Draw = 2,
    BlackWin = 3,
    WhiteForfeitWin = 4,
    BlackForfeitWin = 5,
    DoubleForfeit = 6,
    Bye = 7,
    ArmageddonWhiteWin = 8,
    ArmageddonBlackWin = 9
}
