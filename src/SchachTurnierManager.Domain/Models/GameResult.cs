namespace SchachTurnierManager.Domain.Models;

public sealed record GameResult(GameResultKind Kind)
{
    public static GameResult NotPlayed { get; } = new(GameResultKind.NotPlayed);
    public static GameResult Draw { get; } = new(GameResultKind.Draw);

    public bool IsPlayed => Kind != GameResultKind.NotPlayed;
    public bool IsBye => Kind == GameResultKind.Bye;
    public bool IsForfeit => Kind is GameResultKind.WhiteForfeitWin or GameResultKind.BlackForfeitWin or GameResultKind.DoubleForfeit;
    public bool IsDoubleForfeit => Kind == GameResultKind.DoubleForfeit;
    public bool IsOverTheBoard => Kind is GameResultKind.WhiteWin or GameResultKind.Draw or GameResultKind.BlackWin or GameResultKind.ArmageddonWhiteWin or GameResultKind.ArmageddonBlackWin;
    public bool CountsForPerformance => IsOverTheBoard;
    public bool HasBoardResult => Kind is not GameResultKind.NotPlayed and not GameResultKind.Bye;
}
