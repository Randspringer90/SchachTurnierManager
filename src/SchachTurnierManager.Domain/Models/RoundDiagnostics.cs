namespace SchachTurnierManager.Domain.Models;

public sealed record RoundDiagnostics
{
    public int RoundNumber { get; init; }
    public RoundResultStatus ResultStatus { get; init; }
    public bool IsComplete { get; init; }
    public bool IsLocked { get; init; }
    public bool IsVerified { get; init; }
    public int OpenBoards { get; init; }
    public int ForfeitBoards { get; init; }
    public int ByeBoards { get; init; }
    public IReadOnlyList<string> Warnings { get; init; } = Array.Empty<string>();
    public IReadOnlyList<BoardDiagnostic> Boards { get; init; } = Array.Empty<BoardDiagnostic>();
}

public sealed record BoardDiagnostic
{
    public int BoardNumber { get; init; }
    public string White { get; init; } = string.Empty;
    public string Black { get; init; } = string.Empty;
    public GameResultKind Result { get; init; }
    public string ResultLabel { get; init; } = string.Empty;
    public bool IsOpen { get; init; }
    public bool IsForfeit { get; init; }
    public bool CountsForBuchholz { get; init; }
    public bool CountsForDirectAndSonneborn { get; init; }
    public bool CountsForPerformance { get; init; }
    public string Note { get; init; } = string.Empty;
}
