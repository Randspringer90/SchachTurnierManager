using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Baut ein in sich geschlossenes, forensisches Audit-Bundle aus einem Turnier:
/// Manifest, vollständiger Turnier-Snapshot, Pairing-Forensik je Runde und alle
/// Audit-Journal-Ereignisse. Zwei Formate: append-only-freundliches JSONL (eine
/// JSON-Zeile pro Datensatz) und ein lesbares, strukturiertes JSON-Dokument.
/// </summary>
public sealed class AuditForensicExportBuilder
{
    public const string SchemaVersion = "stm-audit-bundle-1";

    private static readonly JsonSerializerOptions LineOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    private static readonly JsonSerializerOptions DocumentOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly PairingForensicsBuilder _forensics = new();

    public ExportDocument BuildJsonl(TournamentState tournament)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        var exportedAt = DateTimeOffset.UtcNow;
        var builder = new StringBuilder();

        AppendLine(builder, BuildManifest(tournament, exportedAt, "jsonl"));
        AppendLine(builder, new { type = "tournament-snapshot", tournament });

        foreach (var forensics in BuildForensicsRecords(tournament))
        {
            AppendLine(builder, new { type = "pairing-forensics", roundNumber = forensics.CurrentRound, forensics });
        }

        foreach (var entry in OrderedJournal(tournament))
        {
            AppendLine(builder, new { type = "audit-event", entry });
        }

        return new ExportDocument
        {
            FileName = BuildFileName(tournament, exportedAt, "jsonl"),
            ContentType = "application/jsonl; charset=utf-8",
            Content = builder.ToString()
        };
    }

    public ExportDocument BuildJson(TournamentState tournament)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        var exportedAt = DateTimeOffset.UtcNow;

        var document = new
        {
            manifest = BuildManifest(tournament, exportedAt, "json"),
            pairingForensics = BuildForensicsRecords(tournament),
            auditJournal = OrderedJournal(tournament),
            tournamentSnapshot = tournament
        };

        return new ExportDocument
        {
            FileName = BuildFileName(tournament, exportedAt, "json"),
            ContentType = "application/json; charset=utf-8",
            Content = JsonSerializer.Serialize(document, DocumentOptions)
        };
    }

    private object BuildManifest(TournamentState tournament, DateTimeOffset exportedAt, string format)
    {
        var activeCount = tournament.Players.Count(player => player.IsActive);
        return new
        {
            type = "manifest",
            schemaVersion = SchemaVersion,
            format,
            tournamentId = tournament.Id,
            tournamentName = tournament.Name,
            createdOn = tournament.CreatedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            exportedAt,
            tournamentFormat = tournament.Settings.Format.ToString(),
            plannedRounds = tournament.Settings.PlannedRounds,
            roundCount = tournament.Rounds.Count,
            latestRound = LatestRoundNumber(tournament),
            playerCount = tournament.Players.Count,
            activePlayerCount = activeCount,
            inactivePlayerCount = tournament.Players.Count - activeCount,
            auditEntryCount = tournament.AuditJournal.Count,
            settings = tournament.Settings
        };
    }

    private List<PairingForensics> BuildForensicsRecords(TournamentState tournament)
    {
        var records = new List<PairingForensics>();
        foreach (var round in tournament.Rounds.OrderBy(round => round.RoundNumber))
        {
            if (round.Forensics is not null)
            {
                records.Add(round.Forensics);
                continue;
            }

            // Ältere Runden ohne gespeicherte Forensik werden aus dem aktuellen Stand rekonstruiert.
            records.Add(_forensics.Build(tournament, round, "recomputed-at-export"));
        }

        return records;
    }

    private static List<AuditJournalEntry> OrderedJournal(TournamentState tournament)
    {
        return tournament.AuditJournal
            .OrderBy(entry => entry.CreatedAt)
            .ThenBy(entry => entry.Id)
            .ToList();
    }

    private static int LatestRoundNumber(TournamentState tournament)
    {
        return tournament.Rounds.Count == 0 ? 0 : tournament.Rounds.Max(round => round.RoundNumber);
    }

    private static void AppendLine(StringBuilder builder, object payload)
    {
        builder.Append(JsonSerializer.Serialize(payload, LineOptions));
        builder.Append('\n');
    }

    private static string BuildFileName(TournamentState tournament, DateTimeOffset exportedAt, string extension)
    {
        var round = LatestRoundNumber(tournament);
        var timestamp = exportedAt.ToLocalTime().ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        return $"{SafeFileName(tournament.Name)}_round{round}_{timestamp}_audit.{extension}";
    }

    private static string SafeFileName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars().ToHashSet();
        var safe = new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray()).Trim();
        return string.IsNullOrWhiteSpace(safe) ? "Turnier" : safe.Replace(' ', '_');
    }
}
