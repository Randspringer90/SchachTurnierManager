using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class CsvFieldEncoderTests
{
    [Theory]
    [InlineData("=1+2")]
    [InlineData("+SUM(1,2)")]
    [InlineData("-1+2")]
    [InlineData("@SUM(1,2)")]
    [InlineData("\t=1+2")]
    [InlineData("\r=1+2")]
    [InlineData("\n=1+2")]
    [InlineData("  =1+2")]
    [InlineData("\u00A0@SUM(1,2)")]
    [InlineData("\uFEFF=1+2")]
    [InlineData("\u200B+1+2")]
    [InlineData("\uFF1D1+2")]
    [InlineData("\uFF0B1+2")]
    [InlineData("\uFF0D1+2")]
    [InlineData("\uFF201+2")]
    [InlineData("=1+2\";=3+4")]
    [InlineData("=1+2\",=3+4")]
    [InlineData("\tSynthetic")]
    [InlineData("\0=1+2")]
    public void FormulaLikeValues_AreQuotedAndPrefixed(string value)
    {
        foreach (var separator in new[] { ';', ',' })
        {
            var encoded = CsvFieldEncoder.Encode(value, separator);
            Assert.Equal("\"'" + value.Replace("\"", "\"\"") + "\"", encoded);
        }
    }

    [Theory]
    [InlineData(null, "")]
    [InlineData("", "")]
    [InlineData("Synthetic Alpha", "Synthetic Alpha")]
    [InlineData("O'Example", "O'Example")]
    [InlineData("'=1+2", "'=1+2")]
    [InlineData("001234", "001234")]
    [InlineData("-3.5", "-3.5")]
    [InlineData("0", "0")]
    [InlineData("1.5", "1.5")]
    [InlineData("-12", "-12")]
    [InlineData("  Synthetic", "  Synthetic")]
    public void OrdinaryValues_ArePreserved(string? value, string expected)
    {
        Assert.Equal(expected, CsvFieldEncoder.Encode(value));
    }

    [Theory]
    [InlineData("A;B", ';', "\"A;B\"")]
    [InlineData("A,B", ',', "\"A,B\"")]
    [InlineData("A,B", ';', "A,B")]
    [InlineData("A\"B", ';', "\"A\"\"B\"")]
    [InlineData("A\r\nB", ';', "\"A\r\nB\"")]
    public void CsvStructure_IsEscaped(string value, char separator, string expected)
    {
        Assert.Equal(expected, CsvFieldEncoder.Encode(value, separator));
    }

    [Theory]
    [InlineData('|')]
    [InlineData('"')]
    [InlineData('\n')]
    public void UnsupportedSeparators_AreRejected(char separator)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CsvFieldEncoder.Encode("Synthetic", separator));
    }

    [Fact]
    public void ParticipantAndSwissManagerExports_ProtectTextWithoutMutatingPlayers()
    {
        var player = new Player
        {
            Name = "=1+2", Club = "+1+2", Title = "@1+2", FideId = "=3+4",
            NationalId = "-1+2", Federation = "=5+6", Notes = "\t=7+8",
            StartingRank = 1, Rating = new RatingProfile { Dwz = 1234, Elo = 1400 }
        };
        var snapshot = player with { };
        var participant = PlayerCsvCodec.ExportPlayers(new[] { player });
        var swiss = SwissManagerCsvCodec.ExportPlayers(new[] { player });
        foreach (var csv in new[] { participant, swiss })
        {
            Assert.Contains("\"'=1+2\"", csv);
            Assert.Contains("\"'+1+2\"", csv);
            Assert.Contains("\"'@1+2\"", csv);
            Assert.Contains("\"'=3+4\"", csv);
            Assert.Contains("\"'-1+2\"", csv);
            Assert.Contains("1234", csv);
            Assert.Contains("1400", csv);
        }
        Assert.Contains("\"'=5+6\"", swiss);
        Assert.Contains("\"'\t=7+8\"", participant);
        Assert.Equal(snapshot, player);
        Assert.Equal(participant, PlayerCsvCodec.ExportPlayers(new[] { player }));
        Assert.Equal(swiss, SwissManagerCsvCodec.ExportPlayers(new[] { player }));
    }
}
