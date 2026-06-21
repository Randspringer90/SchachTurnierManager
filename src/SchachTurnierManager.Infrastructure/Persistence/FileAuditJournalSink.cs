using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.Persistence;

/// <summary>
/// Schreibt jedes Audit-Ereignis als eine JSON-Zeile in eine append-only Datei pro Turnier
/// (<c>{Verzeichnis}/{tournamentId}.jsonl</c>). Diese Dateien liegen lokal im AppData-Bereich,
/// niemals im Repository, und werden ausschließlich angehängt – nie überschrieben.
/// </summary>
public sealed class FileAuditJournalSink : IAuditJournalSink
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly string _directory;
    private readonly object _gate = new();

    public FileAuditJournalSink(string directory)
    {
        if (string.IsNullOrWhiteSpace(directory))
        {
            throw new ArgumentException("Audit-Verzeichnis darf nicht leer sein.", nameof(directory));
        }

        _directory = directory;
    }

    public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry)
    {
        ArgumentNullException.ThrowIfNull(entry);

        var line = JsonSerializer.Serialize(new
        {
            tournamentId,
            tournamentName,
            mirroredAt = DateTimeOffset.UtcNow,
            entry
        }, JsonOptions);

        lock (_gate)
        {
            Directory.CreateDirectory(_directory);
            var path = Path.Combine(_directory, $"{tournamentId:N}.jsonl");
            File.AppendAllText(path, line + "\n", Encoding.UTF8);
        }
    }
}
