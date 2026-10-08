using System.Text;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-SEC-006 (PR #67) and STM-IE-009 (PR #79) together: exports are read back with an
/// independent RFC 4180 parser (not the production reader) and then re-imported.
/// </summary>
public sealed class CsvExportRoundTripTests
{
    private static Player Synthetic() => new()
    {
        Name = "=1+2",
        Club = "Club \"Quoted\"; with separators, both",
        Title = "@1+2",
        FideId = "=3+4",
        NationalId = "-1+2",
        Federation = "=5+6",
        Notes = "Line one\r\nLine two\n-3",
        StartingRank = 1,
        BirthYear = 1990,
        Rating = new RatingProfile { Dwz = 1234, Elo = 1400, DwzIndex = -5 }
    };

    private static Player Plain() => new()
    {
        Name = "Synthetic Beta",
        Club = "Plain Club",
        StartingRank = 2,
        Rating = new RatingProfile { Dwz = 1500 }
    };

    [Fact]
    public void ParticipantExport_ParsesToExactColumnsAndValues()
    {
        var rows = ParseRfc4180(PlayerCsvCodec.ExportPlayers(new[] { Synthetic(), Plain() }), ';');

        Assert.Equal(3, rows.Count);
        Assert.All(rows, row => Assert.Equal(13, row.Count));
        var row = rows[1];
        Assert.Equal("'=1+2", row[0]);
        Assert.Equal("Club \"Quoted\"; with separators, both", row[1]);
        Assert.Equal("1990", row[2]);
        Assert.Equal("1234", row[4]);
        Assert.Equal("-5", row[5]);      // plain negative numbers stay numeric
        Assert.Equal("1400", row[6]);
        Assert.Equal("'=3+4", row[8]);
        Assert.Equal("'-1+2", row[9]);
        Assert.Equal("'@1+2", row[10]);
        Assert.Equal("Line one\r\nLine two\n-3", row[12]); // CR/LF survive inside the quoted cell
        Assert.Equal("Synthetic Beta", rows[2][0]);
    }

    [Fact]
    public void SwissManagerExport_ParsesToExactColumnsAndValues()
    {
        var rows = ParseRfc4180(SwissManagerCsvCodec.ExportPlayers(new[] { Synthetic(), Plain() }), ',');

        Assert.Equal(3, rows.Count);
        Assert.All(rows, row => Assert.Equal(11, row.Count));
        var row = rows[1];
        Assert.Equal("1", row[0]);
        Assert.Equal("'=1+2", row[1]);
        Assert.Equal("'@1+2", row[2]);
        Assert.Equal("'=3+4", row[3]);
        Assert.Equal("'-1+2", row[4]);
        Assert.Equal("1234", row[5]);
        Assert.Equal("1400", row[6]);
        Assert.Equal("1990", row[7]);
        Assert.Equal("'=5+6", row[8]);
        Assert.Equal("Club \"Quoted\"; with separators, both", row[10]);
    }

    [Fact]
    public void Exports_AreDeterministicAndDoNotMutatePlayers()
    {
        var player = Synthetic();
        var snapshot = player with { };
        Assert.Equal(PlayerCsvCodec.ExportPlayers(new[] { player }), PlayerCsvCodec.ExportPlayers(new[] { player }));
        Assert.Equal(SwissManagerCsvCodec.ExportPlayers(new[] { player }), SwissManagerCsvCodec.ExportPlayers(new[] { player }));
        Assert.Equal(snapshot, player);
    }

    [Fact]
    public void ParticipantRoundTrip_KeepsRowCountAndShowsTheDocumentedTextMarker()
    {
        var csv = PlayerCsvCodec.ExportPlayers(new[] { Synthetic(), Plain() });
        var imported = PlayerCsvCodec.ImportPlayers(csv);

        // A multiline cell must not create extra players (STM-IE-009).
        Assert.Equal(2, imported.Count);
        // CSV re-import is not lossless: the protective apostrophe is part of the cell
        // (documented in CSV_EXPORT_SAFETY.md; JSON backups are the lossless path).
        Assert.Equal("'=1+2", imported[0].Name);
        Assert.Equal("Line one\r\nLine two\n-3", imported[0].Notes);
        Assert.Equal("Synthetic Beta", imported[1].Name);
        Assert.Equal(1500, imported[1].Rating.Dwz);
    }

    [Fact]
    public void SwissManagerRoundTrip_KeepsRowCountAndShowsTheDocumentedTextMarker()
    {
        var csv = SwissManagerCsvCodec.ExportPlayers(new[] { Synthetic(), Plain() });
        var result = SwissManagerCsvCodec.ImportPlayers("﻿" + csv);

        Assert.Empty(result.Errors);
        Assert.Equal(2, result.Players.Count);
        Assert.Equal("'=1+2", result.Players[0].Name);
        Assert.Equal(1990, result.Players[0].BirthYear);
        Assert.Equal("Club \"Quoted\"; with separators, both", result.Players[0].Club);
        Assert.Equal("Synthetic Beta", result.Players[1].Name);
    }

    /// <summary>Minimal, independent RFC 4180 reader used only to verify exports.</summary>
    private static List<List<string>> ParseRfc4180(string text, char separator)
    {
        var rows = new List<List<string>>();
        var row = new List<string>();
        var cell = new StringBuilder();
        var quoted = false;
        for (var i = 0; i < text.Length; i++)
        {
            var ch = text[i];
            if (quoted)
            {
                if (ch == '"' && i + 1 < text.Length && text[i + 1] == '"') { cell.Append('"'); i++; }
                else if (ch == '"') { quoted = false; }
                else { cell.Append(ch); }
                continue;
            }

            if (ch == '"' && cell.Length == 0) { quoted = true; }
            else if (ch == separator) { row.Add(cell.ToString()); cell.Clear(); }
            else if (ch == '\r' && i + 1 < text.Length && text[i + 1] == '\n') { /* CRLF record end, handled at \n */ }
            else if (ch == '\n') { row.Add(cell.ToString()); cell.Clear(); rows.Add(row); row = new List<string>(); }
            else { cell.Append(ch); }
        }

        Assert.False(quoted, "unterminated quoted cell");
        if (cell.Length > 0 || row.Count > 0) { row.Add(cell.ToString()); rows.Add(row); }
        return rows;
    }
}
