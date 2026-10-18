using System.Text.Json;
using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

public sealed class PairingOverridePolicyTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void DisabledManualOverrides_RejectChangesBeforeMutationOrAudit(bool disableAfterPairing)
    {
        var sink = new CapturingSink();
        var service = new TournamentService(new InMemoryTournamentStore(), sink);
        var tournament = service.CreateTournament("Synthetic override policy", new TournamentSettings
        {
            AllowManualPairingOverrides = disableAfterPairing
        });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic One" });
        service.AddPlayer(tournament.Id, new Player { Name = "Synthetic Two" });
        var round = service.GenerateNextRound(tournament.Id);
        var board = Assert.Single(round.Pairings);
        if (disableAfterPairing)
        {
            service.UpdateSettings(tournament.Id, tournament.Settings with { AllowManualPairingOverrides = false });
        }
        var before = JsonSerializer.Serialize(service.RequireTournament(tournament.Id));
        var writes = sink.Writes;

        var exception = Assert.Throws<InvalidOperationException>(() => service.OverridePairing(
            tournament.Id, round.RoundNumber, board.BoardNumber, board.BlackPlayerId, board.WhitePlayerId, "Synthetic change"));

        Assert.Contains("deaktiviert", exception.Message);
        Assert.Equal(before, JsonSerializer.Serialize(service.RequireTournament(tournament.Id)));
        Assert.Equal(writes, sink.Writes);
    }

    private sealed class CapturingSink : IAuditJournalSink
    {
        public int Writes { get; private set; }
        public void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry) => Writes++;
    }
}
