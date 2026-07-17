using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-IE-002: Swiss-Manager-Importlayout nach Anhang C ("Using spreadsheets") des offiziellen
/// Swiss-Manager User's Guide - exakte Spaltenueberschriften, beliebige Reihenfolge, Komma als
/// Trennzeichen. Siehe Klassenkommentar in SwissManagerCsvCodec.cs fuer die Quellenangabe.
/// </summary>
public sealed class SwissManagerCsvCodecTests
{
    [Fact]
    public void ExportPlayers_UsesOfficialSwissManagerHeaderLabels()
    {
        var csv = SwissManagerCsvCodec.ExportPlayers(Array.Empty<Player>());
        var header = csv.Split('\n')[0];

        Assert.Equal("No,Name,Title,FIDE-No,ID no,Rating nat,Rating int,Birth,Fed,Sex,Club", header);
    }

    [Fact]
    public void ExportPlayers_WritesCombinedNameColumn_NotSeparateSurnameFirstName()
    {
        var player = new Player
        {
            StartingRank = 1,
            Name = "Mustermann Max",
            Title = "FM",
            FideId = "1234567",
            NationalId = "DE-9",
            Federation = "GER",
            Club = "SC Beispiel",
            Gender = GenderCategory.Male,
            BirthYear = 1990,
            Rating = new RatingProfile { Dwz = 1850, Elo = 1900 }
        };

        var csv = SwissManagerCsvCodec.ExportPlayers(new[] { player });
        var dataLine = csv.Split('\n')[1];

        Assert.Equal("1,Mustermann Max,FM,1234567,DE-9,1850,1900,1990,GER,m,SC Beispiel", dataLine);
    }

    [Fact]
    public void ImportPlayers_CombinedNameColumn_ParsesAllFields()
    {
        var csv = "No,Name,Title,FIDE-No,ID no,Rating nat,Rating int,Birth,Fed,Sex,Club\n" +
                   "1,Mustermann Max,FM,1234567,DE-9,1850,1900,1990,GER,m,SC Beispiel\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Empty(result.Errors);
        var player = Assert.Single(result.Players);
        Assert.Equal(1, player.StartingRank);
        Assert.Equal("Mustermann Max", player.Name);
        Assert.Equal("FM", player.Title);
        Assert.Equal("1234567", player.FideId);
        Assert.Equal("DE-9", player.NationalId);
        Assert.Equal(1850, player.Rating.Dwz);
        Assert.Equal(1900, player.Rating.Elo);
        Assert.Equal(1990, player.BirthYear);
        Assert.Equal("GER", player.Federation);
        Assert.Equal(GenderCategory.Male, player.Gender);
        Assert.Equal("SC Beispiel", player.Club);
    }

    [Fact]
    public void ImportPlayers_SeparateSurnameFirstNameColumns_CombinesIntoName()
    {
        // Reale Swiss-Manager-Exportdateien nutzen haeufig getrennte Spalten statt der
        // kombinierten "Name"-Spalte - das muss beim Import ebenfalls funktionieren.
        var csv = "No,surname,first name,Rating int\n1,Mustermann,Max,1900\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Empty(result.Errors);
        var player = Assert.Single(result.Players);
        Assert.Equal("Mustermann Max", player.Name);
        Assert.Equal(1900, player.Rating.Elo);
    }

    [Fact]
    public void ImportPlayers_ColumnsInAnyOrder_StillParsesCorrectly()
    {
        // Das Handbuch verlangt ausdruecklich beliebige Spaltenreihenfolge.
        var csv = "Rating int,Name,No\n1900,Mustermann Max,1\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Empty(result.Errors);
        var player = Assert.Single(result.Players);
        Assert.Equal("Mustermann Max", player.Name);
        Assert.Equal(1, player.StartingRank);
        Assert.Equal(1900, player.Rating.Elo);
    }

    [Theory]
    [InlineData("1990/06/15", 1990)] // TRF-Datumsformat JJJJ/MM/TT
    [InlineData("15.06.1990", 1990)] // deutsches Datumsformat TT.MM.JJJJ
    [InlineData("1990", 1990)]       // reines Jahr (unser eigener Export)
    public void ImportPlayers_BirthField_AcceptsAllRequiredDateFormatsAndReducesToYear(string birthValue, int expectedYear)
    {
        var csv = $"Name,Birth\nMustermann Max,{birthValue}\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Empty(result.Errors);
        Assert.Equal(expectedYear, Assert.Single(result.Players).BirthYear);
    }

    [Fact]
    public void ImportPlayers_MissingName_CollectsErrorAndSkipsRowButKeepsOthers()
    {
        var csv = "No,Name\n1,\n2,Mustermann Max\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Single(result.Players);
        Assert.Equal("Mustermann Max", result.Players[0].Name);
        var error = Assert.Single(result.Errors);
        Assert.Contains("Zeile 2", error);
    }

    [Fact]
    public void ImportPlayers_NonNumericRating_CollectsErrorButKeepsPlayerWithoutRating()
    {
        var csv = "Name,Rating int\nMustermann Max,nicht-numerisch\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        var player = Assert.Single(result.Players);
        Assert.Null(player.Rating.Elo);
        Assert.Contains(result.Errors, e => e.Contains("Rating int"));
    }

    [Fact]
    public void ImportPlayers_NoRecognizableNameColumn_ReturnsHeaderError()
    {
        var csv = "Club,Fed\nSC Beispiel,GER\n";

        var result = SwissManagerCsvCodec.ImportPlayers(csv);

        Assert.Empty(result.Players);
        Assert.Single(result.Errors);
    }

    [Fact]
    public void ExportThenImport_RoundtripsMasterDataUnchanged()
    {
        var original = new[]
        {
            new Player
            {
                StartingRank = 1,
                Name = "Mustermann Max",
                Title = "FM",
                FideId = "1234567",
                NationalId = "DE-9",
                Federation = "GER",
                Club = "SC Beispiel, e.V.", // Komma im Wert prueft das CSV-Quoting mit.
                Gender = GenderCategory.Male,
                BirthYear = 1990,
                Rating = new RatingProfile { Dwz = 1850, Elo = 1900 }
            },
            new Player
            {
                StartingRank = 2,
                Name = "Musterfrau Erika",
                Gender = GenderCategory.Female,
                Rating = new RatingProfile()
            }
        };

        var csv = SwissManagerCsvCodec.ExportPlayers(original);
        var reimported = SwissManagerCsvCodec.ImportPlayers(csv);
        var reexported = SwissManagerCsvCodec.ExportPlayers(reimported.Players);

        Assert.Empty(reimported.Errors);
        Assert.Equal(csv, reexported);
    }
}
