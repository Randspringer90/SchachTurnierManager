using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class AuditForensicsWorkflowTests
{
    [Fact]
    public void Audit_CoversFullForensicWorkflow_FromCreateToReset()
    {
        var sink = new CapturingAuditJournalSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = service.CreateTournament("Forensik Workflow", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 });
        AddPlayers(service, tournament.Id, 4);

        var preview = service.PreviewNextRound(tournament.Id);
        var round = service.GenerateNextRound(tournament.Id);
        var nonByeBoard = round.Pairings.First(pairing => !pairing.IsBye);
        service.OverridePairing(tournament.Id, round.RoundNumber, nonByeBoard.BoardNumber, nonByeBoard.WhitePlayerId, nonByeBoard.BlackPlayerId, "Korrektur Turnierleitung");
        service.RecordResult(tournament.Id, round.RoundNumber, nonByeBoard.BoardNumber, GameResultKind.WhiteWin);
        service.RollChess960StartPositions(tournament.Id, round.RoundNumber, overwriteExisting: true, seed: 518);
        service.ResetTournament(tournament.Id);

        // Der Reset entfernt rundenbezogene Einträge bewusst aus der DB; der append-only Spiegel
        // bewahrt den gesamten Verlauf dauerhaft (genau das schließt die Forensik-Lücke).
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.TournamentCreated);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.PlayerAdded);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.RoundPreviewGenerated && e.RoundNumber == preview.RoundNumber);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.RoundGenerated);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.PairingOverridden);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.ResultRecorded);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.Chess960StartPositionsRolled);
        Assert.Contains(sink.Entries, e => e.Action == AuditJournalAction.TournamentReset);

        // In der DB überleben die nicht-rundenbezogenen Einträge plus der Reset-Eintrag.
        var journal = service.GetAuditJournal(tournament.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.TournamentCreated);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.PlayerAdded);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.TournamentReset);
        Assert.DoesNotContain(journal, e => e.Action == AuditJournalAction.RoundGenerated);
    }

    [Fact]
    public void RoundPreview_CapturesPairingForensics()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Vorschau Forensik", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 5 });
        AddPlayers(service, tournament.Id, 5);

        var preview = service.PreviewNextRound(tournament.Id);
        var forensics = preview.Round.Forensics;

        Assert.NotNull(forensics);
        Assert.Equal("preview", forensics!.Trigger);
        Assert.Equal("Swiss", forensics.Format);
        Assert.Equal(5, forensics.PlannedRounds);
        Assert.Equal(1, forensics.CurrentRound);
        Assert.Equal(5, forensics.ActivePlayerCount);
        Assert.Equal(0, forensics.OpenResultsBeforeRound);
        Assert.Equal(1, forensics.ByeCount); // 5 aktive Spieler -> ein Bye
        Assert.NotEmpty(forensics.ProposedPairings);
    }

    [Fact]
    public void GenerateNextRound_BeyondPlannedRounds_IsBlockedAndAudited()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Rundenlimit", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 1 });
        AddPlayers(service, tournament.Id, 4);

        service.GenerateNextRound(tournament.Id);
        Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));

        var journal = service.GetAuditJournal(tournament.Id);
        var blocked = Assert.Single(journal, e => e.Action == AuditJournalAction.PairingGenerationBlocked);
        Assert.Equal(AuditJournalSeverity.Warning, blocked.Severity);
        Assert.Contains("Rundenzahl", (blocked.Reason ?? blocked.Details) ?? string.Empty, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void LateEntrySwiss_IsAuditable_AndReflectedInForensics()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Late Entry Swiss", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 5 });
        AddPlayers(service, tournament.Id, 4);

        var round1 = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in service.RequireTournament(tournament.Id).Rounds.Single().Pairings.Where(p => !p.IsBye))
        {
            service.RecordResult(tournament.Id, round1.RoundNumber, pairing.BoardNumber, GameResultKind.Draw);
        }

        var late = service.AddPlayer(tournament.Id, new Player { Name = "Late Entry", Rating = new RatingProfile { ManualTwz = 2000 } });
        var round2 = service.GenerateNextRound(tournament.Id);

        var journal = service.GetAuditJournal(tournament.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.PlayerAdded && e.PlayerId == late.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.RoundGenerated && e.RoundNumber == round2.RoundNumber);
        Assert.NotNull(round2.Forensics);
        Assert.Equal(5, round2.Forensics!.ActivePlayerCount);
    }

    [Fact]
    public void RoundRobinLateEntry_IsBlockedAndAuditable()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Late Entry RR", new TournamentSettings { Format = TournamentFormat.RoundRobin, PlannedRounds = 5 });
        AddPlayers(service, tournament.Id, 4);

        var round1 = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in service.RequireTournament(tournament.Id).Rounds.Single().Pairings.Where(p => !p.IsBye))
        {
            service.RecordResult(tournament.Id, round1.RoundNumber, pairing.BoardNumber, GameResultKind.Draw);
        }

        service.AddPlayer(tournament.Id, new Player { Name = "RR Nachzügler" });
        Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));

        var journal = service.GetAuditJournal(tournament.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.PairingGenerationBlocked
            && ((e.Reason ?? e.Details) ?? string.Empty).Contains("fixiert", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ManualPairing_IsAuditable_WithReason()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Manuelle Paarung", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);
        var board = round.Pairings.First(pairing => !pairing.IsBye);

        service.OverridePairing(tournament.Id, round.RoundNumber, board.BoardNumber, board.WhitePlayerId, board.BlackPlayerId, "Brettwechsel laut Schiedsrichter");

        var journal = service.GetAuditJournal(tournament.Id);
        var overridden = Assert.Single(journal, e => e.Action == AuditJournalAction.PairingOverridden);
        Assert.Equal(AuditJournalSeverity.Warning, overridden.Severity);
        Assert.Equal(round.RoundNumber, overridden.RoundNumber);
        Assert.Equal(board.BoardNumber, overridden.BoardNumber);
        Assert.Contains("Schiedsrichter", (overridden.Reason ?? overridden.Details) ?? string.Empty);
    }

    [Fact]
    public void DeleteTournament_IsAuditableViaMirror()
    {
        var sink = new CapturingAuditJournalSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = service.CreateTournament("Zu löschen", new TournamentSettings { Format = TournamentFormat.Swiss });
        AddPlayers(service, tournament.Id, 2);

        Assert.True(service.DeleteTournament(tournament.Id));
        Assert.Null(service.ListTournaments().FirstOrDefault(t => t.Id == tournament.Id));

        var deleted = Assert.Single(sink.Entries, e => e.Action == AuditJournalAction.TournamentDeleted);
        Assert.Equal(AuditJournalSeverity.Critical, deleted.Severity);
    }

    [Fact]
    public void AuditMirror_WriteFailure_DoesNotThrow_AndRecordsWarning()
    {
        var service = new TournamentService(new InMemoryTournamentStore(), new ThrowingAuditJournalSink());

        // Der Schreibfehler im Spiegel darf den Turnierschritt nicht abbrechen.
        var tournament = service.CreateTournament("Spiegelfehler", new TournamentSettings { Format = TournamentFormat.Swiss });

        var journal = service.GetAuditJournal(tournament.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.TournamentCreated);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.AuditJournalMirrorFailed && e.Severity == AuditJournalSeverity.Warning);
    }

    [Fact]
    public void ExportAuditJournalJsonl_ProducesSelfContainedBundle_AndRecordsExport()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Export Bundle", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 3 });
        AddPlayers(service, tournament.Id, 4);
        var round = service.GenerateNextRound(tournament.Id);
        service.RecordResult(tournament.Id, round.RoundNumber, round.Pairings.First(p => !p.IsBye).BoardNumber, GameResultKind.WhiteWin);

        var document = service.ExportAuditJournalJsonl(tournament.Id);

        Assert.EndsWith("_audit.jsonl", document.FileName);
        Assert.Contains("Export_Bundle_round1_", document.FileName);
        var lines = document.Content.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        Assert.Contains(lines, line => line.Contains("\"type\":\"manifest\""));
        Assert.Contains(lines, line => line.Contains("\"type\":\"tournament-snapshot\""));
        Assert.Contains(lines, line => line.Contains("\"type\":\"pairing-forensics\""));
        Assert.Contains(lines, line => line.Contains("\"type\":\"audit-event\""));

        var journal = service.GetAuditJournal(tournament.Id);
        Assert.Contains(journal, e => e.Action == AuditJournalAction.AuditJournalExported);
    }

    [Fact]
    public void ExportAuditJournalJson_HasManifestAndSnapshot()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Export JSON", new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = 2 });
        AddPlayers(service, tournament.Id, 4);
        service.GenerateNextRound(tournament.Id);

        var document = service.ExportAuditJournalJson(tournament.Id);

        Assert.EndsWith("_audit.json", document.FileName);
        Assert.Contains("\"schemaVersion\"", document.Content);
        Assert.Contains("\"tournamentSnapshot\"", document.Content);
        Assert.Contains("\"pairingForensics\"", document.Content);
        Assert.Contains("\"auditJournal\"", document.Content);
    }

    private static void AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        for (var i = 1; i <= count; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Name = $"Forensik Spieler {i}",
                Rating = new RatingProfile { ManualTwz = 2200 - i * 25 }
            });
        }
    }

    private sealed class CapturingAuditJournalSink : IAuditJournalSink
    {
        public List<AuditJournalEntry> Entries { get; } = new();

        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry)
        {
            Entries.Add(entry);
        }
    }

    private sealed class ThrowingAuditJournalSink : IAuditJournalSink
    {
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry)
        {
            throw new IOException("Audit-Verzeichnis ist im Test nicht beschreibbar.");
        }
    }
}
