using System.Text.Json;
using System.Text.Json.Serialization;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

/// <summary>
/// STM-FACH-007: a correction of an already entered result is one explicit audit event that binds the
/// previous and the new result, an optional operator reason and the later rounds already paired with
/// the old result. Later pairings are never changed; standings are recalculated from the new result.
/// </summary>
public sealed class ResultCorrectionAuditTests
{
    [Fact]
    public void FirstResultEntry_IsRecordedNotCorrected()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);

        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);

        var journal = service.GetAuditJournal(id);
        Assert.Contains(journal, entry => entry.Action == AuditJournalAction.ResultRecorded && entry.RoundNumber == 1 && entry.BoardNumber == 1);
        Assert.DoesNotContain(journal, entry => entry.Action == AuditJournalAction.ResultCorrected);
    }

    [Fact]
    public void Correction_BindsPreviousNewAndReasonInOneEvent()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);

        service.RecordResult(id, 1, 1, GameResultKind.BlackWin, GameResultKind.WhiteWin, "  Partieformular vertauscht  ");

        var correction = Assert.Single(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
        Assert.Equal(1, correction.RoundNumber);
        Assert.Equal(1, correction.BoardNumber);
        Assert.Equal("Partieformular vertauscht", correction.Reason);
        Assert.Equal("previous=WhiteWin; new=BlackWin", correction.Details);
        Assert.Equal(AuditJournalSeverity.Info, correction.Severity);
    }

    [Fact]
    public void Correction_WithoutReason_IsStillExplicit()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 2, GameResultKind.Draw);

        service.RecordResult(id, 1, 2, GameResultKind.WhiteWin);

        var correction = Assert.Single(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
        Assert.Null(correction.Reason);
        Assert.Equal("previous=Draw; new=WhiteWin", correction.Details);
    }

    [Fact]
    public void RepeatingTheSameResult_IsNoCorrection()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.Draw);

        service.RecordResult(id, 1, 1, GameResultKind.Draw, GameResultKind.Draw);

        Assert.DoesNotContain(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
    }

    [Fact]
    public void Correction_AfterLaterRoundWasPaired_WarnsKeepsPairingsAndRecalculatesStandings()
    {
        var (service, id) = CreateSwiss(4);
        var first = service.GenerateNextRound(id);
        foreach (var pairing in first.Pairings.Where(pairing => !pairing.IsBye))
            service.RecordResult(id, 1, pairing.BoardNumber, GameResultKind.WhiteWin);
        var second = service.GenerateNextRound(id);
        var secondPairingsBefore = second.Pairings.Select(p => (p.BoardNumber, p.WhitePlayerId, p.BlackPlayerId)).ToArray();
        var board1 = first.Pairings.Single(p => p.BoardNumber == 1);

        service.RecordResult(id, 1, 1, GameResultKind.BlackWin, GameResultKind.WhiteWin, "Schiedsrichterentscheidung");

        var tournament = service.RequireTournament(id);
        var secondAfter = tournament.Rounds.Single(r => r.RoundNumber == 2)
            .Pairings.Select(p => (p.BoardNumber, p.WhitePlayerId, p.BlackPlayerId)).ToArray();
        Assert.Equal(secondPairingsBefore, secondAfter);

        var correction = Assert.Single(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
        Assert.Equal(AuditJournalSeverity.Warning, correction.Severity);
        Assert.Contains("Runde 2", correction.Summary, StringComparison.Ordinal);

        var standings = service.GetStandings(id);
        Assert.Equal(1m, standings.Single(row => row.PlayerId == board1.BlackPlayerId).Points);
        Assert.Equal(0m, standings.Single(row => row.PlayerId == board1.WhitePlayerId).Points);
    }

    [Fact]
    public void Correction_InRoundRobin_DoesNotWarnAboutLaterRounds()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Rundenturnier", new TournamentSettings { Format = TournamentFormat.RoundRobin });
        for (var index = 0; index < 4; index++)
            service.AddPlayer(tournament.Id, new Player { Name = $"Spieler {index + 1}", Rating = new RatingProfile { ManualTwz = 2000 - index * 50 } });
        var first = service.GenerateNextRound(tournament.Id);
        foreach (var pairing in first.Pairings.Where(pairing => !pairing.IsBye))
            service.RecordResult(tournament.Id, 1, pairing.BoardNumber, GameResultKind.Draw);
        service.GenerateNextRound(tournament.Id);

        service.RecordResult(tournament.Id, 1, 1, GameResultKind.WhiteWin, GameResultKind.Draw);

        var correction = Assert.Single(service.GetAuditJournal(tournament.Id), entry => entry.Action == AuditJournalAction.ResultCorrected);
        Assert.Equal(AuditJournalSeverity.Info, correction.Severity);
        Assert.DoesNotContain("gepaart", correction.Summary, StringComparison.Ordinal);
    }

    [Fact]
    public void Correction_ReasonLongerThanLimit_IsRejectedWithoutChange()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);

        var error = Assert.Throws<InvalidOperationException>(() =>
            service.RecordResult(id, 1, 1, GameResultKind.BlackWin, GameResultKind.WhiteWin, new string('x', 501)));

        Assert.Equal("RESULT_REASON_TOO_LONG", RuleErrorMetadata.GetErrorCode(error));
        Assert.Equal(GameResultKind.WhiteWin, service.RequireTournament(id).Rounds[0].Pairings.Single(p => p.BoardNumber == 1).Result.Kind);
        Assert.DoesNotContain(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
    }

    [Fact]
    public void Correction_ThroughTheOfflineQueue_IsAlsoOneExplicitEventWithoutFreeText()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);
        var tournament = service.RequireTournament(id);
        var board = tournament.Rounds[0].Pairings.Single(p => p.BoardNumber == 1);
        var mutation = new QueuedResultMutation(Guid.NewGuid(), tournament.ResultQueueEpoch, 1, 1,
            GameResultKind.Draw, GameResultKind.WhiteWin, board.WhitePlayerId!.Value, board.BlackPlayerId!.Value, board.LastChangedAt);

        service.RecordQueuedResult(id, mutation);

        var correction = Assert.Single(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
        Assert.Equal("previous=WhiteWin; new=Draw", correction.Details);
        Assert.Null(correction.Reason);
    }

    [Fact]
    public void Correction_DetectsAnIntermediateChangeThatWasReverted()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);
        var loadedAt = service.RequireTournament(id).Rounds[0].Pairings.Single(p => p.BoardNumber == 1).LastChangedAt;
        service.RecordResult(id, 1, 1, GameResultKind.Draw);      // another device changes the board ...
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);  // ... and changes it back
        var journalBefore = service.GetAuditJournal(id).Count;

        var error = Assert.Throws<InvalidOperationException>(() => service.RecordResult(
            id, 1, 1, GameResultKind.BlackWin, GameResultKind.WhiteWin, "veralteter Stand", loadedAt));

        Assert.Equal("RESULT_CHANGED", RuleErrorMetadata.GetErrorCode(error));
        Assert.Equal(GameResultKind.WhiteWin, service.RequireTournament(id).Rounds[0].Pairings.Single(p => p.BoardNumber == 1).Result.Kind);
        Assert.Equal(journalBefore, service.GetAuditJournal(id).Count);
    }

    [Fact]
    public void Correction_WithCurrentTimestamp_IsAccepted()
    {
        var (service, id) = CreateSwiss(4);
        service.GenerateNextRound(id);
        service.RecordResult(id, 1, 1, GameResultKind.WhiteWin);
        var current = service.RequireTournament(id).Rounds[0].Pairings.Single(p => p.BoardNumber == 1).LastChangedAt;

        service.RecordResult(id, 1, 1, GameResultKind.BlackWin, GameResultKind.WhiteWin, "Meldefehler", current);

        Assert.Single(service.GetAuditJournal(id), entry => entry.Action == AuditJournalAction.ResultCorrected);
    }

    [Fact]
    public void CorrectionEvent_SurvivesJsonRoundtripAsStableName()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web) { Converters = { new JsonStringEnumConverter() } };
        var entry = new AuditJournalEntry { Action = AuditJournalAction.ResultCorrected, Details = "previous=Draw; new=WhiteWin" };

        var json = JsonSerializer.Serialize(entry, options);
        var restored = JsonSerializer.Deserialize<AuditJournalEntry>(json, options);

        Assert.Contains("\"ResultCorrected\"", json, StringComparison.Ordinal);
        Assert.Equal(AuditJournalAction.ResultCorrected, restored!.Action);
        Assert.Equal(entry.Details, restored.Details);
    }

    private static (TournamentService Service, Guid Id) CreateSwiss(int players)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Korrektur", new TournamentSettings { Format = TournamentFormat.Swiss });
        for (var index = 0; index < players; index++)
            service.AddPlayer(tournament.Id, new Player { Name = $"Spieler {index + 1}", Rating = new RatingProfile { ManualTwz = 2000 - index * 50 } });
        return (service, tournament.Id);
    }
}
