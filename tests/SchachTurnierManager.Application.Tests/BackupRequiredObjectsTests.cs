using System.Text.Json;
using System.Text.Json.Nodes;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class BackupRequiredObjectsTests
{
    private static readonly JsonSerializerOptions Json = new() { IgnoreReadOnlyProperties = true };

    public static IEnumerable<object[]> InvalidFields()
    {
        foreach (var path in new[]
        {
            "Players/0/Rating", "Rounds/0/Audit", "Rounds/0/Pairings/bye/Result",
            "Rounds/0/Audit/Algorithm", "Rounds/0/Audit/RulesetVersion",
            "AuditJournal/0", "AuditJournal/0/Actor", "AuditJournal/0/Summary",
            "Rounds/0/Forensics/Trigger", "Rounds/0/Forensics/Format",
            "Rounds/0/Forensics/Algorithm", "Rounds/0/Forensics/QualitySeverity",
            "Rounds/0/Forensics/ProposedPairings", "Rounds/0/Forensics/ProposedPairings/0",
            "Rounds/0/Forensics/ProposedPairings/0/White", "Rounds/0/Forensics/ProposedPairings/0/Black",
            "Rounds/0/Pairings/bye/Chess960StartPosition/WhiteBackRank",
            "Rounds/0/Pairings/bye/Chess960StartPosition/BlackBackRank"
        }) yield return new object[] { path, false };
        foreach (var list in new[] { "Messages", "ScoreGroups", "Floaters", "ColorNotes" })
        {
            yield return new object[] { $"Rounds/0/Audit/{list}", false };
            yield return new object[] { $"Rounds/0/Audit/{list}/0", false };
        }
        foreach (var list in new[] { "ByeDecisions", "RematchWarnings", "ScoreGroupDeviations", "ColorNotes", "EngineMessages", "Findings" })
        {
            yield return new object[] { $"Rounds/0/Forensics/{list}", false };
            yield return new object[] { $"Rounds/0/Forensics/{list}/0", false };
        }
        yield return new object[] { "Rounds/0/Pairings/bye/Result/Kind", true };
        yield return new object[] { "Rounds/0/Pairings/0/Result", false };
    }

    [Theory]
    [MemberData(nameof(InvalidFields))]
    public void InvalidNestedBackup_IsRejectedBeforeAnyMutation(string path, bool invalidEnum)
    {
        var sink = new CapturingSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = CreateWithBye(service);
        var storedBefore = JsonSerializer.Serialize(service.RequireTournament(tournament.Id), Json);
        var document = JsonNode.Parse(storedBefore)!;
        document["Name"] = "  Incoming replacement  ";
        var pairings = document["Rounds"]![0]!["Pairings"]!.AsArray();
        var byeIndex = pairings.Select((pairing, index) => (pairing, index))
            .Single(item => item.pairing!["BlackPlayerId"] is null).index;
        pairings[byeIndex]!["Chess960StartPosition"] = JsonSerializer.SerializeToNode(new Chess960StartPosition());
        var parts = path.Replace("/bye/", $"/{byeIndex}/").Split('/');
        JsonNode parent = document;
        foreach (var part in parts[..^1]) parent = parent is JsonArray array ? array[int.Parse(part)]! : parent[part]!;
        JsonNode? value = invalidEnum ? JsonValue.Create(9999) : null;
        if (parent is JsonArray finalArray)
        {
            var index = int.Parse(parts[^1]);
            while (finalArray.Count <= index) finalArray.Add("synthetic");
            finalArray[index] = value;
        }
        else parent[parts[^1]] = value;
        var incoming = document.Deserialize<TournamentState>()!;
        var incomingBefore = JsonSerializer.Serialize(incoming, Json);
        var writesBefore = sink.Writes;

        Assert.Throws<InvalidOperationException>(() => service.SaveImportedTournament(incoming, overwriteExisting: true));

        Assert.Equal(storedBefore, JsonSerializer.Serialize(service.RequireTournament(tournament.Id), Json));
        Assert.Equal(incomingBefore, JsonSerializer.Serialize(incoming, Json));
        Assert.Equal(writesBefore, sink.Writes);
    }

    [Fact]
    public void ValidLegacyBackup_WithOptionalNulls_RemainsUsable()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = CreateWithBye(service);
        var document = JsonNode.Parse(JsonSerializer.Serialize(tournament, Json))!;
        // Missing properties retain model defaults; nullable rating scalars and
        // optional forensic/Chess960 objects retain their documented meaning.
        foreach (var player in document["Players"]!.AsArray())
        {
            player!["Rating"] = new JsonObject { ["Elo"] = null, ["Dwz"] = null, ["ManualTwz"] = null };
        }
        var round = document["Rounds"]![0]!;
        round["Forensics"] = null;
        round.AsObject().Remove("Audit");
        foreach (var pairing in round["Pairings"]!.AsArray()) pairing!["Chess960StartPosition"] = null;
        document["Settings"]!["Tiebreaks"] = null;
        var incoming = document.Deserialize<TournamentState>()!;

        service.SaveImportedTournament(incoming, overwriteExisting: true);

        Assert.Equal(3, service.GetStandings(tournament.Id).Count);
        Assert.NotNull(service.ExportTournamentPackageJson(tournament.Id));
        Assert.NotNull(service.RequireTournament(tournament.Id).Rounds[0].Audit);
    }

    private static TournamentState CreateWithBye(TournamentService service)
    {
        var tournament = service.CreateTournament("Synthetic existing", new TournamentSettings { PlannedRounds = 3 });
        for (var index = 1; index <= 3; index++) service.AddPlayer(tournament.Id, new Player { Name = $"Synthetic {index}" });
        var round = service.GenerateNextRound(tournament.Id);
        Assert.Single(round.Pairings.Where(pairing => pairing.BlackPlayerId is null));
        return service.RequireTournament(tournament.Id);
    }

    private sealed class CapturingSink : IAuditJournalSink
    {
        public int Writes { get; private set; }
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry) => Writes++;
    }
}
