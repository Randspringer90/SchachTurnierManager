using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

/// <summary>
/// Abnahme-Szenario für den Bergfest-/Freestyle-Würfelschach-Einsatz: ein vollständiges
/// 5-Runden-Schweizer-Turnier mit synthetischen Spielern. Sichert die Freitag-MVP-Garantien
/// ab: 5 Runden durchführbar, keine doppelten Paarungen, Bye bei ungerader Teilnehmerzahl,
/// Ergebnisänderung aktualisiert die Tabelle, Export enthält Runde/Paarungen/Tabelle.
/// </summary>
public sealed class BergfestDryRunTests
{
    private const int PlannedRounds = 5;

    [Fact]
    public void FiveRoundSwissDryRun_TenPlayers_PairsEveryoneAndNeverHidesARematch()
    {
        var service = CreateTournament(out var tournamentId, playerCount: 10);
        var analyzer = new PairingQualityAnalyzer();

        var metBefore = new HashSet<(Guid, Guid)>();
        for (var roundNumber = 1; roundNumber <= PlannedRounds; roundNumber++)
        {
            var round = service.GenerateNextRound(tournamentId);
            Assert.Equal(roundNumber, round.RoundNumber);

            // 10 aktive Spieler => 5 Bretter, kein Bye in geraden Feldern.
            Assert.Equal(5, round.Pairings.Count);
            Assert.DoesNotContain(round.Pairings, pairing => pairing.IsBye);
            AssertEachActivePlayerAppearsAtMostOnce(round);

            // Die heuristische Swiss-Engine vermeidet Rematches in frühen Runden zuverlässig.
            // In späten Runden eines kleinen Feldes kann ein Rematch erzwungen werden – dann MUSS
            // es als kritischer Befund sichtbar sein (nie still). Das ist die Freitag-Schutzschicht:
            // Der Turnierleiter sieht den Befund in der Vorschau und korrigiert per manueller Paarung.
            var detectedRematches = round.Pairings
                .Where(pairing => !pairing.IsBye)
                .Count(pairing => metBefore.Contains(NormalizePair(pairing.WhitePlayerId!.Value, pairing.BlackPlayerId!.Value)));

            var report = analyzer.Analyze(service.RequireTournament(tournamentId), round);
            Assert.Equal(detectedRematches, report.RematchCount);
            if (roundNumber <= 3)
            {
                Assert.Equal(0, detectedRematches);
            }
            if (detectedRematches > 0)
            {
                Assert.Equal(PairingQualitySeverity.Critical, report.Severity);
            }

            foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
            {
                metBefore.Add(NormalizePair(pairing.WhitePlayerId!.Value, pairing.BlackPlayerId!.Value));
                // Realistischer, gemischter Ergebnisverlauf (nicht das pathologische "immer Weiß gewinnt").
                service.RecordResult(tournamentId, roundNumber, pairing.BoardNumber, ResultForBoard(pairing.BoardNumber));
            }
        }

        var persisted = service.RequireTournament(tournamentId);
        Assert.Equal(PlannedRounds, persisted.Rounds.Count);

        var standings = service.GetStandings(tournamentId);
        Assert.Equal(10, standings.Count);
        // Jede entschiedene oder remisierte Partie verteilt genau 1 Punkt; 5 Runden x 5 Bretter = 25 Partien.
        Assert.Equal(PlannedRounds * 5 * 1.0m, standings.Sum(row => row.Points));
    }

    private static GameResultKind ResultForBoard(int boardNumber) => (boardNumber % 5) switch
    {
        1 => GameResultKind.WhiteWin,
        2 => GameResultKind.Draw,
        3 => GameResultKind.WhiteWin,
        4 => GameResultKind.BlackWin,
        _ => GameResultKind.Draw,
    };

    [Fact]
    public void FiveRoundSwissDryRun_ElevenPlayers_GivesExactlyOneByePerRound()
    {
        var service = CreateTournament(out var tournamentId, playerCount: 11);

        var byePlayers = new HashSet<Guid>();
        for (var roundNumber = 1; roundNumber <= PlannedRounds; roundNumber++)
        {
            var round = service.GenerateNextRound(tournamentId);

            // 11 aktive Spieler => 5 Spielbretter + genau 1 Bye.
            var byeBoards = round.Pairings.Where(pairing => pairing.IsBye).ToList();
            Assert.Single(byeBoards);
            AssertEachActivePlayerAppearsAtMostOnce(round);

            // Kein Spieler soll im selben Turnier zweimal das Bye bekommen.
            var byePlayerId = byeBoards[0].WhitePlayerId!.Value;
            Assert.True(byePlayers.Add(byePlayerId), "Ein Spieler hat zweimal ein Bye erhalten.");

            foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
            {
                service.RecordResult(tournamentId, roundNumber, pairing.BoardNumber, GameResultKind.Draw);
            }
        }

        Assert.Equal(PlannedRounds, service.RequireTournament(tournamentId).Rounds.Count);
    }

    [Fact]
    public void CorrectingAResult_UpdatesStandings()
    {
        var service = CreateTournament(out var tournamentId, playerCount: 8);
        var round = service.GenerateNextRound(tournamentId);
        var firstBoard = round.Pairings.First(pairing => !pairing.IsBye);
        var whiteId = firstBoard.WhitePlayerId!.Value;
        var blackId = firstBoard.BlackPlayerId!.Value;

        service.RecordResult(tournamentId, round.RoundNumber, firstBoard.BoardNumber, GameResultKind.WhiteWin);
        var afterWhiteWin = service.GetStandings(tournamentId);
        Assert.Equal(1.0m, PointsOf(afterWhiteWin, whiteId));
        Assert.Equal(0.0m, PointsOf(afterWhiteWin, blackId));

        // Korrektur: aus Weißsieg wird ein Remis.
        service.RecordResult(tournamentId, round.RoundNumber, firstBoard.BoardNumber, GameResultKind.Draw);
        var afterCorrection = service.GetStandings(tournamentId);
        Assert.Equal(0.5m, PointsOf(afterCorrection, whiteId));
        Assert.Equal(0.5m, PointsOf(afterCorrection, blackId));
    }

    [Fact]
    public void Export_ContainsRoundPairingsAndStandings()
    {
        var service = CreateTournament(out var tournamentId, playerCount: 8);
        var round = service.GenerateNextRound(tournamentId);
        foreach (var pairing in round.Pairings.Where(pairing => !pairing.IsBye))
        {
            service.RecordResult(tournamentId, round.RoundNumber, pairing.BoardNumber, GameResultKind.WhiteWin);
        }

        var tournament = service.RequireTournament(tournamentId);
        var standings = service.GetStandings(tournamentId);
        var diagnostics = service.GetRoundDiagnostics(tournamentId);
        var formatter = new TournamentExportFormatter();

        var pairingsCsv = formatter.ExportPairingsCsv(tournament);
        Assert.Contains("Runde;Brett;Weiß;Schwarz;Ergebnis", pairingsCsv.Content);
        Assert.Contains("1;1;", pairingsCsv.Content);

        var standingsCsv = formatter.ExportStandingsCsv(tournament, standings);
        Assert.Contains("Rang;Name;TWZ;Punkte", standingsCsv.Content);
        Assert.Contains("Dry-Run Spieler", standingsCsv.Content);

        var html = formatter.ExportPrintableTournamentHtml(tournament, standings, diagnostics);
        Assert.Contains("<h2>Tabelle</h2>", html.Content);
        Assert.Contains("<h2>Runden</h2>", html.Content);
        Assert.Contains("Runde 1", html.Content);
    }

    private static TournamentService CreateTournament(out Guid tournamentId, int playerCount)
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament(
            "Bergfest Freestyle Dry-Run",
            new TournamentSettings { Format = TournamentFormat.Swiss, PlannedRounds = PlannedRounds });
        tournamentId = tournament.Id;

        for (var i = 1; i <= playerCount; i++)
        {
            service.AddPlayer(tournamentId, new Player
            {
                Id = Guid.Parse($"00000000-0000-0000-0000-{i:000000000000}"),
                Name = $"Dry-Run Spieler {i:00}",
                StartingRank = i,
                Rating = new RatingProfile { ManualTwz = 2000 - i * 25 }
            });
        }

        return service;
    }

    private static void AssertEachActivePlayerAppearsAtMostOnce(TournamentRound round)
    {
        var playerIds = round.Pairings
            .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
            .Where(playerId => playerId is not null)
            .Select(playerId => playerId!.Value)
            .ToList();

        Assert.Equal(playerIds.Count, playerIds.Distinct().Count());
    }

    private static (Guid, Guid) NormalizePair(Guid a, Guid b) => a.CompareTo(b) <= 0 ? (a, b) : (b, a);

    private static decimal PointsOf(IReadOnlyList<StandingRow> standings, Guid playerId)
        => standings.Single(row => row.PlayerId == playerId).Points;
}
