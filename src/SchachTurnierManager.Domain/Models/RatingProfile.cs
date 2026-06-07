namespace SchachTurnierManager.Domain.Models;

public sealed record RatingProfile
{
    public int? ManualTwz { get; init; }
    public int? Elo { get; init; }
    public int? RapidElo { get; init; }
    public int? BlitzElo { get; init; }
    public int? Dwz { get; init; }
    public int? DwzIndex { get; init; }

    public int TwzFor(TwzSource source)
    {
        return source switch
        {
            TwzSource.ManualThenEloThenDwz => FirstPositive(ManualTwz, Elo, Dwz),
            TwzSource.ManualThenRapidThenBlitzThenDwzThenElo => FirstPositive(ManualTwz, RapidElo, BlitzElo, Dwz, Elo),
            _ => FirstPositive(ManualTwz, Dwz, Elo)
        };
    }

    private static int FirstPositive(params int?[] values)
    {
        foreach (var value in values)
        {
            if (value is > 0)
            {
                return value.Value;
            }
        }

        return 0;
    }
}
