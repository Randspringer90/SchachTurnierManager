using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure.Persistence;
using Xunit;

namespace SchachTurnierManager.Infrastructure.Tests;

public sealed class FileAuditJournalSinkTests
{
    [Fact]
    public void Append_WritesOneAppendOnlyJsonLinePerEntry()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"stm-audit-sink-{Guid.NewGuid():N}");
        try
        {
            var sink = new FileAuditJournalSink(directory);
            var tournamentId = Guid.NewGuid();

            sink.Append(tournamentId, "Sink Test", new AuditJournalEntry { Action = AuditJournalAction.TournamentCreated, Summary = "Angelegt" });
            sink.Append(tournamentId, "Sink Test", new AuditJournalEntry { Action = AuditJournalAction.PlayerAdded, Summary = "Spieler" });

            var path = Path.Combine(directory, $"{tournamentId:N}.jsonl");
            Assert.True(File.Exists(path));

            var lines = File.ReadAllLines(path);
            Assert.Equal(2, lines.Length);

            using var first = JsonDocument.Parse(lines[0]);
            Assert.Equal(tournamentId, first.RootElement.GetProperty("tournamentId").GetGuid());
            Assert.Equal("TournamentCreated", first.RootElement.GetProperty("entry").GetProperty("action").GetString());
            Assert.Contains("PlayerAdded", lines[1]);
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }

    [Fact]
    public void Append_CreatesDirectoryWhenMissing()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"stm-audit-sink-{Guid.NewGuid():N}", "nested");
        try
        {
            var sink = new FileAuditJournalSink(directory);
            sink.Append(Guid.NewGuid(), "Auto Dir", new AuditJournalEntry { Action = AuditJournalAction.TournamentCreated });

            Assert.True(Directory.Exists(directory));
        }
        finally
        {
            var root = Directory.GetParent(directory)?.FullName;
            if (root is not null && Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }
}
