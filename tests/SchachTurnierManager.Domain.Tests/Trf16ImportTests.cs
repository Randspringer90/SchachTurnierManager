using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-IE-002: TRF16-Import liest ausschliesslich Spieler-Stammdaten aus "001"-Zeilen
/// zurueck (kein Turnierergebnis/keine Rundenlogik, wie im Issue gefordert). Spiegelbildlich
/// zu ExportTrf16 (STM-IE-001).
/// </summary>
public sealed class Trf16ImportTests
{
    [Fact]
    public void ImportTrf16Players_MissingName_CollectsErrorAndSkipsLine()
    {
        var line = "001    1                                                                          0.0    1";
        var formatter = new TournamentExportFormatter();

        var result = formatter.ImportTrf16Players(line);

        Assert.Empty(result.Players);
        Assert.Single(result.Errors);
    }

    [Fact]
    public void ImportTrf16Players_IgnoresTournamentHeaderLines()
    {
        var content = "012 Testturnier\n062 1\n";
        var formatter = new TournamentExportFormatter();

        var result = formatter.ImportTrf16Players(content);

        Assert.Empty(result.Players);
        Assert.Empty(result.Errors);
    }

    [Fact]
    public void ExportThenImportTrf16_RoundtripsPlayerMasterData()
    {
        var players = new List<Player>
        {
            new()
            {
                Id = Guid.Parse("00000000-0000-0000-0000-000000000001"),
                StartingRank = 1,
                Name = "Mustermann, Max",
                Gender = GenderCategory.Male,
                Title = "FM",
                FideId = "1234567",
                Federation = "GER",
                Rating = new RatingProfile { Elo = 2100 }
            },
            new()
            {
                Id = Guid.Parse("00000000-0000-0000-0000-000000000002"),
                StartingRank = 2,
                Name = "Musterfrau, Erika",
                Gender = GenderCategory.Female,
                Federation = "GER",
                Rating = new RatingProfile { Elo = 1950 }
            },
            new()
            {
                Id = Guid.Parse("00000000-0000-0000-0000-000000000003"),
                StartingRank = 3,
                Name = "Unbewertet, Otto",
                Rating = new RatingProfile()
            }
        };

        var tournament = new TournamentState
        {
            Name = "TRF16 Roundtrip Turnier",
            Settings = new TournamentSettings { Format = TournamentFormat.Swiss }
        };
        tournament.Players.AddRange(players);

        var formatter = new TournamentExportFormatter();
        var standings = new StandingsCalculator().Calculate(tournament, includeInactive: true);
        var exported = formatter.ExportTrf16(tournament, standings);

        var reimported = formatter.ImportTrf16Players(exported.Content);

        Assert.Empty(reimported.Errors);
        Assert.Equal(3, reimported.Players.Count);

        var max = Assert.Single(reimported.Players, p => p.StartingRank == 1);
        Assert.Equal("Mustermann, Max", max.Name);
        Assert.Equal(GenderCategory.Male, max.Gender);
        Assert.Equal("FM", max.Title);
        Assert.Equal("1234567", max.FideId);
        Assert.Equal("GER", max.Federation);
        Assert.Equal(2100, max.Rating.Elo);

        var erika = Assert.Single(reimported.Players, p => p.StartingRank == 2);
        Assert.Equal("Musterfrau, Erika", erika.Name);
        Assert.Equal(GenderCategory.Female, erika.Gender);
        Assert.Equal(1950, erika.Rating.Elo);

        var otto = Assert.Single(reimported.Players, p => p.StartingRank == 3);
        Assert.Equal("Unbewertet, Otto", otto.Name);
        Assert.Null(otto.Rating.Elo);
    }
}
