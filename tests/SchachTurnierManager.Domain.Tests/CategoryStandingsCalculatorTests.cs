using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class CategoryStandingsCalculatorTests
{
    [Fact]
    public void Calculate_CreatesWomenAndYouthTablesWhenPlayersMatch()
    {
        var tournament = new TournamentState
        {
            Name = "Kategorien",
            Players =
            {
                new Player { Name = "Mila", BirthYear = DateTime.Today.Year - 8, Gender = GenderCategory.Female, StartingRank = 1 },
                new Player { Name = "Senior", BirthYear = 1950, Gender = GenderCategory.Male, StartingRank = 2 }
            },
            Settings = new TournamentSettings { SeniorBirthYearOrEarlier = 1966 }
        };

        var tables = new CategoryStandingsCalculator().Calculate(tournament);

        Assert.Contains(tables, table => table.Category == "Frauen" && table.Rows.Any(row => row.Name == "Mila"));
        Assert.Contains(tables, table => table.Category == "U10" && table.Rows.Any(row => row.Name == "Mila"));
        Assert.Contains(tables, table => table.Category == "Senioren" && table.Rows.Any(row => row.Name == "Senior"));
    }
}
