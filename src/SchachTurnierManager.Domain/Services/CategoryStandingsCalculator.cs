using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class CategoryStandingsCalculator
{
    public static readonly IReadOnlyList<string> KnownCategories = new[]
    {
        "Frauen",
        "U10",
        "U12",
        "U14",
        "U16",
        "U18",
        "U25",
        "Senioren"
    };

    private readonly StandingsCalculator _standings = new();

    public IReadOnlyList<CategoryStandingTable> Calculate(TournamentState tournament)
    {
        var standings = _standings.Calculate(tournament);
        return KnownCategories
            .Select(category => new CategoryStandingTable
            {
                Category = category,
                Rows = standings
                    .Where(row => row.Categories.TryGetValue(category, out var isMember) && isMember)
                    .Select((row, index) => row with { Rank = index + 1 })
                    .ToList()
            })
            .Where(table => table.Rows.Count > 0)
            .ToList();
    }
}
