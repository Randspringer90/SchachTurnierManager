using System;
using System.Collections.Generic;
using System.Text;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

/// <summary>
/// STM-SEC-006: spreadsheet CSV is an output channel, not a lossless backup.
/// A deliberately independent CSV reader tests column boundaries, including multiline cells.
/// </summary>
public sealed class TournamentCsvFormulaSafetyTests
{
    [Theory]
    [InlineData("=1+2")]
    [InlineData("+SUM(1;2)")]
    [InlineData("-1+2")]
    [InlineData("@SUM(1;2)")]
    [InlineData("\t=1+2")]
    [InlineData("  =1+2")]
    [InlineData("\uFEFF=1+2")]
    [InlineData("\uFF1D1+2")]
    [InlineData("=1+2\";=3+4")]
    public void StandingsCsv_FormulaLikeNames_AreNeutralizedWithoutChangingNumericCells(string name)
    {
        var tournament = new TournamentState { Name = "Synthetic tournament" };
        var standings = new[]
        {
            new StandingRow { Rank = 1, Name = name, Twz = 1700, Points = -1.5m }
        };

        var document = new TournamentExportFormatter().ExportStandingsCsv(tournament, standings);
        var rows = ReadSemicolonCsv(document.Content);

        Assert.Equal("text/csv; charset=utf-8", document.ContentType);
        Assert.Equal(2, rows.Count);
        Assert.Equal(17, rows[0].Length);
        Assert.Equal(17, rows[1].Length);
        Assert.Equal("Name", rows[0][1]);
        Assert.Equal("'" + name, rows[1][1]);
        Assert.Equal("1", rows[1][0]);
        Assert.Equal("1700", rows[1][2]);
        Assert.Equal("-1.5", rows[1][3]);
        Assert.Equal(name, standings[0].Name);
    }

    [Fact]
    public void StandingsCsv_OrdinaryNamesAndSignedNumbers_KeepTheOriginalValues()
    {
        var tournament = new TournamentState { Name = "Synthetic tournament" };
        var standings = new[]
        {
            new StandingRow { Rank = 1, Name = "Synthetic; \"Player\"", Twz = 1600, Points = -2.5m },
            new StandingRow { Rank = 2, Name = "-3.5", Twz = 1234, Points = 0.5m }
        };

        var document = new TournamentExportFormatter().ExportStandingsCsv(tournament, standings);
        var rows = ReadSemicolonCsv(document.Content);
        Assert.Equal(3, rows.Count);
        Assert.Equal("Synthetic; \"Player\"", rows[1][1]);
        Assert.Equal("-3.5", rows[2][1]);
        Assert.Equal("-2.5", rows[1][3]);
        Assert.Equal("0.5", rows[2][3]);
        Assert.Equal(document.Content, new TournamentExportFormatter().ExportStandingsCsv(tournament, standings).Content);
    }

    [Fact]
    public void PairingsCsv_ProtectsBothNamesAndMultilineNotes_ForAllAndSingleRound()
    {
        var white = new Player { Id = Guid.NewGuid(), Name = "+SUM(1;2)" };
        var black = new Player { Id = Guid.NewGuid(), Name = "\uFEFF=1+2" };
        var notes = "@SUM(1;2)\r\n=4+5\";=6+7";
        var tournament = new TournamentState { Name = "Synthetic tournament" };
        tournament.Players.Add(white);
        tournament.Players.Add(black);
        tournament.Rounds.Add(new TournamentRound
        {
            RoundNumber = 1,
            Pairings = new[] { Pairing.Game(1, white.Id, black.Id, notes) }
        });

        var formatter = new TournamentExportFormatter();
        foreach (var document in new[] { formatter.ExportPairingsCsv(tournament), formatter.ExportPairingsCsv(tournament, 1) })
        {
            var rows = ReadSemicolonCsv(document.Content);
            Assert.Equal(2, rows.Count);
            Assert.Equal(9, rows[0].Length);
            Assert.Equal(9, rows[1].Length);
            Assert.Equal("'" + white.Name, rows[1][2]);
            Assert.Equal("'" + black.Name, rows[1][3]);
            Assert.Equal("'" + notes, rows[1][8]);
            Assert.Equal("1", rows[1][0]);
            Assert.Equal("1", rows[1][1]);
        }

        Assert.Equal("+SUM(1;2)", white.Name);
        Assert.Equal(notes, tournament.Rounds[0].Pairings[0].Notes);
    }

    [Fact]
    public void PreviewCsv_ProtectsUntrustedNamesAndJoinedFindings_WithoutChangingScores()
    {
        var tournament = new TournamentState { Name = "Synthetic tournament" };
        var preview = new NextRoundPreview
        {
            RoundNumber = 2,
            PairingQuality = new PairingQualityReport
            {
                Boards = new[]
                {
                    new PairingQualityBoard
                    {
                        BoardNumber = 1,
                        WhiteName = "=1+2",
                        BlackName = "\t@SUM(1;2)",
                        WhiteScoreBeforeRound = -1.5m,
                        BlackScoreBeforeRound = 0.5m,
                        ScoreDifference = -2m,
                        Findings = new[] { "=HYPERLINK(1;2)", "+SYNTHETIC" }
                    }
                }
            }
        };

        var document = new TournamentExportFormatter().ExportNextRoundPreviewCsv(tournament, preview);
        var rows = ReadSemicolonCsv(document.Content);
        Assert.EndsWith("_Vorschau_Runde_02.csv", document.FileName);
        Assert.Equal(2, rows.Count);
        Assert.Equal(12, rows[0].Length);
        Assert.Equal(12, rows[1].Length);
        Assert.Equal("'=1+2", rows[1][2]);
        Assert.Equal("'\t@SUM(1;2)", rows[1][3]);
        Assert.Equal("-1.5", rows[1][4]);
        Assert.Equal("0.5", rows[1][5]);
        Assert.Equal("-2", rows[1][6]);
        Assert.Equal("'=HYPERLINK(1;2) | +SYNTHETIC", rows[1][11]);
        Assert.Equal("=HYPERLINK(1;2)", preview.PairingQuality.Boards[0].Findings[0]);
    }

    // Independent minimal RFC-style reader for the delimiter and quote subset
    // emitted by TournamentExportFormatter; not the production CSV reader.
    private static IReadOnlyList<string[]> ReadSemicolonCsv(string csv)
    {
        var rows = new List<string[]>();
        var fields = new List<string>();
        var field = new StringBuilder();
        var quoted = false;

        void CompleteRecord()
        {
            fields.Add(field.ToString());
            field.Clear();
            rows.Add(fields.ToArray());
            fields.Clear();
        }

        for (var i = 0; i < csv.Length; i++)
        {
            var ch = csv[i];
            if (ch == '"')
            {
                if (quoted && i + 1 < csv.Length && csv[i + 1] == '"')
                {
                    field.Append('"');
                    i++;
                }
                else
                {
                    quoted = !quoted;
                }
            }
            else if (ch == ';' && !quoted)
            {
                fields.Add(field.ToString());
                field.Clear();
            }
            else if ((ch == '\n' || ch == '\r') && !quoted)
            {
                if (ch == '\r' && i + 1 < csv.Length && csv[i + 1] == '\n') i++;
                CompleteRecord();
            }
            else
            {
                field.Append(ch);
            }
        }
        Assert.False(quoted, "CSV must not end inside a quoted field.");
        if (field.Length > 0 || fields.Count > 0) CompleteRecord();
        return rows;
    }
}
