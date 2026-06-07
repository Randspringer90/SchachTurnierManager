using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public static class ScoringRules
{
    public static decimal ScoreFor(GameResult result, bool isWhite, ScoringSystem scoringSystem)
    {
        return scoringSystem switch
        {
            ScoringSystem.ThreeOneZero => ScoreThreeOneZero(result.Kind, isWhite),
            ScoringSystem.NorwayArmageddon => ScoreNorway(result.Kind, isWhite),
            _ => ScoreClassical(result.Kind, isWhite)
        };
    }

    public static bool IsWinFor(GameResult result, bool isWhite, bool countForfeitWins = true, bool countByeAsWin = false)
    {
        return result.Kind switch
        {
            GameResultKind.WhiteWin or GameResultKind.ArmageddonWhiteWin => isWhite,
            GameResultKind.BlackWin or GameResultKind.ArmageddonBlackWin => !isWhite,
            GameResultKind.WhiteForfeitWin => countForfeitWins && isWhite,
            GameResultKind.BlackForfeitWin => countForfeitWins && !isWhite,
            GameResultKind.Bye => countByeAsWin,
            _ => false
        };
    }

    public static bool IsForfeit(GameResultKind kind)
    {
        return kind is GameResultKind.WhiteForfeitWin or GameResultKind.BlackForfeitWin or GameResultKind.DoubleForfeit;
    }

    public static bool IsOverTheBoard(GameResultKind kind)
    {
        return kind is GameResultKind.WhiteWin or GameResultKind.Draw or GameResultKind.BlackWin or GameResultKind.ArmageddonWhiteWin or GameResultKind.ArmageddonBlackWin;
    }

    public static decimal NormalizedClassicalScore(GameResultKind kind, bool isWhite)
    {
        return ScoreClassical(kind, isWhite);
    }

    private static decimal ScoreClassical(GameResultKind kind, bool isWhite)
    {
        return kind switch
        {
            GameResultKind.WhiteWin or GameResultKind.WhiteForfeitWin or GameResultKind.ArmageddonWhiteWin => isWhite ? 1m : 0m,
            GameResultKind.BlackWin or GameResultKind.BlackForfeitWin or GameResultKind.ArmageddonBlackWin => isWhite ? 0m : 1m,
            GameResultKind.Draw => 0.5m,
            GameResultKind.Bye => 1m,
            _ => 0m
        };
    }

    private static decimal ScoreThreeOneZero(GameResultKind kind, bool isWhite)
    {
        return kind switch
        {
            GameResultKind.WhiteWin or GameResultKind.WhiteForfeitWin => isWhite ? 3m : 0m,
            GameResultKind.BlackWin or GameResultKind.BlackForfeitWin => isWhite ? 0m : 3m,
            GameResultKind.Draw => 1m,
            GameResultKind.Bye => 3m,
            GameResultKind.ArmageddonWhiteWin => isWhite ? 3m : 0m,
            GameResultKind.ArmageddonBlackWin => isWhite ? 0m : 3m,
            _ => 0m
        };
    }

    private static decimal ScoreNorway(GameResultKind kind, bool isWhite)
    {
        return kind switch
        {
            GameResultKind.WhiteWin or GameResultKind.WhiteForfeitWin => isWhite ? 3m : 0m,
            GameResultKind.BlackWin or GameResultKind.BlackForfeitWin => isWhite ? 0m : 3m,
            GameResultKind.ArmageddonWhiteWin => isWhite ? 1.5m : 1m,
            GameResultKind.ArmageddonBlackWin => isWhite ? 1m : 1.5m,
            GameResultKind.Draw => 1m,
            GameResultKind.Bye => 3m,
            _ => 0m
        };
    }
}
