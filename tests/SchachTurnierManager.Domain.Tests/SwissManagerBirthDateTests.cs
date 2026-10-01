using System.Globalization;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class SwissManagerBirthDateTests
{
    [Theory]
    [InlineData("1900", 1900)]
    [InlineData("2100", 2100)]
    [InlineData("2000", 2000)]
    [InlineData("2000/02/29", 2000)]
    [InlineData("29.02.2000", 2000)]
    [InlineData("2024/02/29", 2024)]
    [InlineData("29.02.2024", 2024)]
    [InlineData("1900/01/01", 1900)]
    [InlineData("31.12.2100", 2100)]
    [InlineData(" 15.06.1990 ", 1990)]
    [InlineData(" 1990 ", 1990)]
    // Calendar-valid dates without leading zeros were accepted before STM-IE-010 and must stay so.
    [InlineData("1990/6/15", 1990)]
    [InlineData("15.6.1990", 1990)]
    [InlineData("1990/12/1", 1990)]
    [InlineData("1.1.2000", 2000)]
    [InlineData("29.2.2000", 2000)]
    public void ValidYearsAndDates_AreReducedToYear(string birth, int expected)
    {
        var result = SwissManagerCsvCodec.ImportPlayers($"Name,Birth\nSynthetic Alpha,{birth}\n");
        Assert.Empty(result.Errors);
        Assert.Equal(expected, Assert.Single(result.Players).BirthYear);
    }

    [Theory]
    [InlineData("31.02.2000")]
    [InlineData("29.02.1900")]
    [InlineData("29.02.2100")]
    [InlineData("2023/02/29")]
    [InlineData("1990/99/99")]
    [InlineData("1990/garbage")]
    [InlineData("garbage.1990")]
    [InlineData("00.12.1990")]
    [InlineData("31.04.1990")]
    [InlineData("15.00.1990")]
    [InlineData("15.13.1990")]
    [InlineData("1899")]
    [InlineData("2101")]
    [InlineData("0000")]
    [InlineData("29.2.1900")]
    [InlineData("31.4.1990")]
    [InlineData("1990/2/30")]
    [InlineData("1990-06-15")]
    [InlineData("1990/06/15 trailing")]
    [InlineData("1990/06/15/extra")]
    [InlineData("1.2.3.1990")]
    [InlineData("+990")]
    [InlineData("-990")]
    [InlineData("19 0")]
    [InlineData("\uFF11\uFF19\uFF19\uFF10")]
    [InlineData("not-a-date")]
    public void InvalidBirth_DoesNotInventAYearOrLeakTheInput(string birth)
    {
        var result = SwissManagerCsvCodec.ImportPlayers($"Name,Birth,Rating int\nSynthetic Alpha,{birth},1500\n");
        var player = Assert.Single(result.Players);
        Assert.Null(player.BirthYear);
        Assert.Equal(1500, player.Rating.Elo);
        var error = Assert.Single(result.Errors);
        Assert.Contains("Zeile 2", error);
        Assert.Contains("'Birth'", error);
        Assert.DoesNotContain(birth, error);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("\t")]
    public void MissingOptionalBirth_IsNotAnError(string birth)
    {
        var result = SwissManagerCsvCodec.ImportPlayers($"Name,Birth\nSynthetic Alpha,{birth}\n");
        Assert.Empty(result.Errors);
        Assert.Null(Assert.Single(result.Players).BirthYear);
    }

    [Fact]
    public void BadBirth_DoesNotDropOtherRowsOrFields()
    {
        var result = SwissManagerCsvCodec.ImportPlayers("Club,Birth,Name\nFirst,31.02.2000,Synthetic Alpha\nSecond,2001,Synthetic Beta\n");
        Assert.Equal(2, result.Players.Count);
        Assert.Equal("First", result.Players[0].Club);
        Assert.Null(result.Players[0].BirthYear);
        Assert.Equal(2001, result.Players[1].BirthYear);
        Assert.Single(result.Errors);
    }

    [Theory]
    [InlineData("de-DE")]
    [InlineData("en-US")]
    [InlineData("ar-SA")]
    public void DateInterpretation_IsIndependentOfCurrentCulture(string culture)
    {
        var previous = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(culture);
            var result = SwissManagerCsvCodec.ImportPlayers("Name,Birth\nSynthetic Alpha,29.02.2000\n");
            Assert.Empty(result.Errors);
            Assert.Equal(2000, Assert.Single(result.Players).BirthYear);
        }
        finally
        {
            CultureInfo.CurrentCulture = previous;
        }
    }
}
