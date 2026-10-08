using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class CsvRecordReaderTests
{
    [Theory]
    [InlineData('\n')]
    [InlineData('|')]
    [InlineData('"')]
    public void UnsupportedSeparator_IsRejected(char separator)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => CsvRecordReader.Read("Alpha", separator));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("\uFEFF")]
    [InlineData(" \t\r\n\n\r")]
    public void EmptyDocuments_ContainNoRecords(string? csv)
    {
        Assert.Empty(CsvRecordReader.Read(csv, ';'));
    }

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    [InlineData("\r")]
    public void QuotedLineBreaks_ArePreservedInsideOneField(string newline)
    {
        var rows = CsvRecordReader.Read($"Name;Club{newline}\"Alpha{newline}Beta\";Gamma{newline}Delta;Epsilon", ';');
        Assert.Equal(3, rows.Count);
        Assert.Equal($"Alpha{newline}Beta", rows[1].Fields[0]);
        Assert.Equal(new[] { "Delta", "Epsilon" }, rows[2].Fields);
        Assert.Equal(4, rows[2].LineNumber);
    }

    [Theory]
    [InlineData(';')]
    [InlineData(',')]
    public void EscapedQuotesAndDelimiters_AreFieldContent(char separator)
    {
        var row = Assert.Single(CsvRecordReader.Read($"\"A{separator}B\"{separator}\"C\"\"D\"{separator}", separator));
        Assert.Equal(new[] { $"A{separator}B", "C\"D", "" }, row.Fields);
    }

    [Fact]
    public void PhysicalLineNumbers_IncludeEmptyAndQuotedLines()
    {
        var rows = CsvRecordReader.Read("\uFEFFName,Club\r\n\"Alpha\r\nBeta\",Gamma\r\n\r\nDelta,Epsilon", ',');
        Assert.Equal(new[] { 1, 2, 5 }, rows.Select(row => row.LineNumber));
        Assert.Equal("Name", rows[0].Fields[0]);
    }

    [Fact]
    public void OnlyInitialBom_IsRemoved()
    {
        var row = Assert.Single(CsvRecordReader.Read("\uFEFFAlpha;\uFEFFBeta", ';'));
        Assert.Equal(new[] { "Alpha", "\uFEFFBeta" }, row.Fields);
    }

    [Fact]
    public void HorizontalPaddingOutsideQuotes_IsAccepted()
    {
        var row = Assert.Single(CsvRecordReader.Read("  \" A \" \t; \"B\";  C  ", ';'));
        Assert.Equal(new[] { " A ", "B", "  C  " }, row.Fields);
    }

    [Theory]
    [InlineData(";", 2)]
    [InlineData(";;", 3)]
    [InlineData("\"\"", 1)]
    [InlineData("\"\";\"\"", 2)]
    public void EmptyFields_AreNotDropped(string csv, int count)
    {
        var row = Assert.Single(CsvRecordReader.Read(csv, ';'));
        Assert.Equal(count, row.Fields.Count);
        Assert.All(row.Fields, field => Assert.Equal(string.Empty, field));
    }

    [Theory]
    [InlineData("\"Alpha")]
    [InlineData("Alpha\"Beta")]
    [InlineData("\"Alpha\"Beta")]
    [InlineData("\"Alpha\" \"Beta\"")]
    [InlineData("\"Alpha\r\nBeta")]
    [InlineData("\"\"\"")]
    public void InvalidQuotes_RejectTheWholeDocument(string invalidRow)
    {
        var ex = Assert.Throws<ArgumentException>(() => CsvRecordReader.Read("Name;Club\nValid;Club\n" + invalidRow, ';'));
        Assert.Contains("CSV-Zeile", ex.Message);
        Assert.DoesNotContain("Alpha", ex.Message);
    }

    [Fact]
    public void TrailingRecordSeparator_DoesNotCreateAPlayer()
    {
        Assert.Single(CsvRecordReader.Read("Alpha;Beta\r\n", ';'));
    }

    [Theory]
    [InlineData("\n")]
    [InlineData("\r\n")]
    [InlineData("\r")]
    public void ParticipantExport_RoundtripsMultilineNotes(string newline)
    {
        var player = new Player { Name = "Synthetic Alpha", Club = "Club; One", Notes = $"First{newline}Second \"quoted\"", BirthYear = 2000 };
        var csv = PlayerCsvCodec.ExportPlayers(new[] { player });
        var imported = Assert.Single(PlayerCsvCodec.ImportPlayers(csv));
        Assert.Equal(player.Name, imported.Name);
        Assert.Equal(player.Club, imported.Club);
        Assert.Equal(player.Notes, imported.Notes);
        Assert.Equal(player.BirthYear, imported.BirthYear);
        Assert.Equal(csv, PlayerCsvCodec.ExportPlayers(new[] { imported }));
    }

    [Fact]
    public void ParticipantImport_AcceptsBomHeaderAndHeaderlessInput()
    {
        Assert.Equal("Synthetic Alpha", Assert.Single(PlayerCsvCodec.ImportPlayers("\uFEFF  Name ;Verein\nSynthetic Alpha;Club")).Name);
        Assert.Equal("Synthetic Beta", Assert.Single(PlayerCsvCodec.ImportPlayers("Synthetic Beta;Club")).Name);
    }

    [Fact]
    public void ParticipantImport_ThrowsAnApiRecognizedArgumentError()
    {
        Assert.Throws<ArgumentException>(() => PlayerCsvCodec.ImportPlayers("Name;Verein\nValid;Club\n\"Broken"));
    }

    [Fact]
    public void SwissImport_AcceptsMultilineFieldsAndBomHeader()
    {
        var result = SwissManagerCsvCodec.ImportPlayers("\uFEFFName,Club,Rating int\n\"Synthetic\nAlpha\",\"Club, One\",1500\n");
        Assert.Empty(result.Errors);
        var player = Assert.Single(result.Players);
        Assert.Equal("Synthetic\nAlpha", player.Name);
        Assert.Equal("Club, One", player.Club);
        Assert.Equal(1500, player.Rating.Elo);
    }

    [Fact]
    public void SwissImport_StructuralErrorReturnsNoPartialPlayers()
    {
        var result = SwissManagerCsvCodec.ImportPlayers("Name,Club\nValid,Club\n\"Broken");
        Assert.Empty(result.Players);
        Assert.Contains("CSV-Zeile", Assert.Single(result.Errors));
    }

    [Fact]
    public void SwissImport_FieldErrorsUsePhysicalRecordStartLine()
    {
        var result = SwissManagerCsvCodec.ImportPlayers("Name,Rating int\n\"Alpha\nBeta\",1500\n\nGamma,not-a-number\n");
        Assert.Equal(2, result.Players.Count);
        Assert.Contains("Zeile 5", Assert.Single(result.Errors));
    }

    [Fact]
    public void SyntheticValidCells_RoundtripAcrossBothSeparators()
    {
        var cells = new[] { "", "Alpha", "A,B", "A;B", "A\"B", "A\nB", "A\rB", "A\r\nB", " leading ", "=1+2", "'literal" };
        foreach (var separator in new[] { ';', ',' })
        {
            var csv = string.Join(separator, cells.Select(cell => "\"" + cell.Replace("\"", "\"\"") + "\""));
            Assert.Equal(cells, Assert.Single(CsvRecordReader.Read(csv, separator)).Fields);
        }
    }
}
