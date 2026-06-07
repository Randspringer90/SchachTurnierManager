namespace SchachTurnierManager.Domain.Models;

public sealed record GameResult(GameResultKind Kind)
{
    public static GameResult NotPlayed { get; } = new(GameResultKind.NotPlayed);
    public static GameResult Draw { get; } = new(GameResultKind.Draw);

    public bool IsPlayed => Kind != GameResultKind.NotPlayed;
    public bool IsBye => Kind == GameResultKind.Bye;
    public bool CountsForPerformance => Kind is GameResultKind.WhiteWin or GameResultKind.Draw or GameResultKind.BlackWin or GameResultKind.ArmageddonWhiteWin or GameResultKind.ArmageddonBlackWin;
}
