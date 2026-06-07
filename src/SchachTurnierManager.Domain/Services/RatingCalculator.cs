namespace SchachTurnierManager.Domain.Services;

public static class RatingCalculator
{
    public static double ExpectedScore(int playerRating, int opponentRating)
    {
        return 1.0 / (1.0 + Math.Pow(10.0, (opponentRating - playerRating) / 400.0));
    }

    public static double EloDelta(int playerRating, int opponentRating, double actualScore, int kFactor)
    {
        var expected = ExpectedScore(playerRating, opponentRating);
        return kFactor * (actualScore - expected);
    }

    public static int ApproximatePerformanceRating(int averageOpponentRating, double scorePercentage)
    {
        if (scorePercentage <= 0)
        {
            return averageOpponentRating - 800;
        }

        if (scorePercentage >= 1)
        {
            return averageOpponentRating + 800;
        }

        var diff = -400.0 * Math.Log10((1.0 / scorePercentage) - 1.0);
        diff = Math.Clamp(diff, -800.0, 800.0);
        return (int)Math.Round(averageOpponentRating + diff, MidpointRounding.AwayFromZero);
    }
}
