using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public static class CategoryClassifier
{
    public static IReadOnlyDictionary<string, bool> Classify(Player player, TournamentSettings settings, int referenceYear)
    {
        var categories = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase)
        {
            ["Frauen"] = player.Gender == GenderCategory.Female,
            ["U10"] = IsUnder(player, referenceYear, 10),
            ["U12"] = IsUnder(player, referenceYear, 12),
            ["U14"] = IsUnder(player, referenceYear, 14),
            ["U16"] = IsUnder(player, referenceYear, 16),
            ["U18"] = IsUnder(player, referenceYear, 18),
            ["U25"] = IsUnder(player, referenceYear, 25),
            ["Senioren"] = settings.SeniorBirthYearOrEarlier is not null && player.BirthYear is not null && player.BirthYear <= settings.SeniorBirthYearOrEarlier
        };
        return categories;
    }

    private static bool IsUnder(Player player, int referenceYear, int ageLimit)
    {
        return player.BirthYear is not null && referenceYear - player.BirthYear.Value < ageLimit;
    }
}
