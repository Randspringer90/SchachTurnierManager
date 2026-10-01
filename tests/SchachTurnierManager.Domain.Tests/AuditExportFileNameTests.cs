using System.Text;
using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Domain.Tests;

public sealed class AuditExportFileNameTests
{
    public static IEnumerable<object[]> Names()
    {
        var cases = new (string Name, string Stem)[]
        {
            ("Synthetic Cup", "Synthetic_Cup"),
            ("Synthetic_U21-2026", "Synthetic_U21-2026"),
            ("A:B", "A_B"), ("A/B", "A_B"), ("A\\B", "A_B"),
            ("A\"B", "A_B"), ("A<B>C|D?E*F", "A_B_C_D_E_F"),
            ("A\r\nB", "A__B"), ("A\0B", "A_B"),
            ("A\u202EB", "A_B"), ("A\u200BB", "A_B"),
            ("A\u00A0B", "A_B"), ("  Cup  ", "Cup"),
            ("...Cup...", "Cup"), ("...", "Turnier"), ("", "Turnier"),
            ("  \t", "Turnier"), ("CON", "CON"),
            ("\u00DC\u00F1\u4E2D\U0001F600", "\u00DC\u00F1\u4E2D\U0001F600")
        };
        foreach (var jsonl in new[] { false, true })
        {
            foreach (var item in cases)
            {
                yield return new object[] { jsonl, item.Name, item.Stem };
            }
        }
    }

    [Theory]
    [MemberData(nameof(Names))]
    public void Export_UsesPortableBoundedStemWithoutChangingSnapshot(bool jsonl, string name, string stem)
    {
        var tournament = new TournamentState { Name = name };
        var document = Export(tournament, jsonl);

        Assert.StartsWith(stem + "_round0_", document.FileName);
        Assert.EndsWith(jsonl ? "_audit.jsonl" : "_audit.json", document.FileName);
        Assert.DoesNotContain(document.FileName, ch => "<>:\"/\\|?*".Contains(ch) || char.IsControl(ch));
        Assert.True(Encoding.UTF8.GetByteCount(document.FileName) <= 180);
        Assert.Equal(name, tournament.Name);
        Assert.Empty(tournament.Rounds);
        Assert.Empty(tournament.AuditJournal);

        using var parsed = JsonDocument.Parse(jsonl ? document.Content.Split('\n')[0] : document.Content);
        var manifest = jsonl ? parsed.RootElement : parsed.RootElement.GetProperty("manifest");
        Assert.Equal(name, manifest.GetProperty("tournamentName").GetString());
        Assert.Equal("stm-audit-bundle-1", manifest.GetProperty("schemaVersion").GetString());
    }

    [Theory]
    [InlineData(false, "a")]
    [InlineData(true, "a")]
    [InlineData(false, "\u4E2D")]
    [InlineData(true, "\u4E2D")]
    [InlineData(false, "\U0001F600")]
    [InlineData(true, "\U0001F600")]
    public void Export_LongUnicodeNames_DoNotSplitScalars(bool jsonl, string unit)
    {
        var name = string.Concat(Enumerable.Repeat(unit, 1000));
        var document = Export(new TournamentState { Name = name }, jsonl);
        var stem = document.FileName.Split("_round0_", StringSplitOptions.None)[0];
        var strict = new UTF8Encoding(false, true);
        Assert.Equal(120, strict.GetByteCount(stem));
        Assert.Equal(string.Concat(Enumerable.Repeat(unit, 120 / strict.GetByteCount(unit))), stem);
        Assert.Equal(stem, strict.GetString(strict.GetBytes(stem)));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Export_TruncationDoesNotSplitASupplementaryCharacter(bool jsonl)
    {
        var prefix = new string('x', 119);
        var document = Export(new TournamentState { Name = prefix + "\U0001F600last" }, jsonl);
        Assert.StartsWith(prefix + "_round0_", document.FileName);
    }

    private static ExportDocument Export(TournamentState tournament, bool jsonl)
    {
        var builder = new AuditForensicExportBuilder();
        return jsonl ? builder.BuildJsonl(tournament) : builder.BuildJson(tournament);
    }
}
