using SchachTurnierManager.Domain.Models;
using Xunit;

namespace SchachTurnierManager.Application.Tests;

/// <summary>
/// Szenario-Tests aus dem Bergfest-Postmortem 2026. Decken die im Einsatz aufgetretenen
/// Schwachstellen ab: Rundenlimit, Late Entry, Rückzug/Reaktivierung, manuelle Paarungen,
/// Jeder-gegen-jeden-Vollständigkeit und die Round-Robin-Late-Entry-Sperre.
/// Alle Spieler sind synthetisch ("Synth N") – keine echten Teilnehmerdaten.
/// </summary>
public sealed class PostmortemBergfestScenarioTests
{
    // ---------- Phase 2: Rundenlimit ----------

    [Fact]
    public void Swiss_12Players_5Rounds_BlocksSixthRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Bergfest Swiss", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 12);

        for (var round = 1; round <= 5; round++)
        {
            PlayOneRound(service, tournament.Id);
        }

        Assert.Equal(5, service.RequireTournament(tournament.Id).Rounds.Count);

        var generate = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
        Assert.Contains("maximale Rundenzahl", generate.Message, StringComparison.OrdinalIgnoreCase);

        var preview = Assert.Throws<InvalidOperationException>(() => service.PreviewNextRound(tournament.Id));
        Assert.Contains("maximale Rundenzahl", preview.Message, StringComparison.OrdinalIgnoreCase);

        // Es darf keine sechste Runde entstanden sein.
        Assert.Equal(5, service.RequireTournament(tournament.Id).Rounds.Count);
    }

    [Fact]
    public void Swiss_6Rounds_12Players_AllowsExactlySixRounds()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Bergfest Swiss 6", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 6
        });
        AddPlayers(service, tournament.Id, 12);

        for (var round = 1; round <= 6; round++)
        {
            PlayOneRound(service, tournament.Id);
        }

        Assert.Equal(6, service.RequireTournament(tournament.Id).Rounds.Count);
        Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
    }

    // ---------- Phase 3: Late Entry / Rückzug / Reaktivierung ----------

    [Fact]
    public void Swiss_LateEntryAfterRound2_PlaysFromNextRoundWithZeroPoints_AndPastRoundsUnchanged()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Late Entry", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 8);

        PlayOneRound(service, tournament.Id);
        PlayOneRound(service, tournament.Id);
        var roundsBefore = SnapshotPairings(service, tournament.Id);

        var late = service.AddPlayer(tournament.Id, new Player
        {
            Name = "Synth Nachzügler",
            Rating = new RatingProfile { ManualTwz = 1750 }
        });

        // Bestehende Runden bleiben unverändert.
        var roundsAfter = SnapshotPairings(service, tournament.Id);
        Assert.Equal(roundsBefore, roundsAfter);

        // Vor der Auslosung hat der Nachzügler 0 Punkte.
        var standings = service.GetStandings(tournament.Id);
        Assert.Equal(0m, standings.Single(row => row.PlayerId == late.Id).Points);

        var round3 = service.GenerateNextRound(tournament.Id);
        Assert.Contains(round3.Pairings, p => p.WhitePlayerId == late.Id || p.BlackPlayerId == late.Id);

        // Runde 1 und 2 enthalten den Nachzügler weiterhin nicht.
        var tournamentState = service.RequireTournament(tournament.Id);
        foreach (var played in tournamentState.Rounds.Where(r => r.RoundNumber <= 2))
        {
            Assert.DoesNotContain(played.Pairings, p => p.WhitePlayerId == late.Id || p.BlackPlayerId == late.Id);
        }
    }

    [Fact]
    public void Swiss_LateEntryAfterRound4_StillRespectsFiveRoundLimit()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Late Entry Limit", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 8);

        for (var round = 1; round <= 4; round++)
        {
            PlayOneRound(service, tournament.Id);
        }

        var late = service.AddPlayer(tournament.Id, new Player { Name = "Synth Spät", Rating = new RatingProfile { ManualTwz = 1600 } });

        var round5 = service.GenerateNextRound(tournament.Id);
        Assert.Equal(5, round5.RoundNumber);
        Assert.Contains(round5.Pairings, p => p.WhitePlayerId == late.Id || p.BlackPlayerId == late.Id);

        CompleteCurrentRound(service, tournament.Id);
        Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
    }

    [Fact]
    public void Swiss_WithdrawnPlayer_IsNotPaired()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Withdraw", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        var players = AddPlayers(service, tournament.Id, 8);

        PlayOneRound(service, tournament.Id);
        service.SetPlayerStatus(tournament.Id, players[0].Id, PlayerStatus.Withdrawn);

        var round2 = service.GenerateNextRound(tournament.Id);
        Assert.DoesNotContain(round2.Pairings, p => p.WhitePlayerId == players[0].Id || p.BlackPlayerId == players[0].Id);
    }

    [Fact]
    public void Swiss_ReactivatedPlayer_IsPairedAgainInFutureRoundsOnly()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Reactivate", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        var players = AddPlayers(service, tournament.Id, 8);

        PlayOneRound(service, tournament.Id);
        service.SetPlayerStatus(tournament.Id, players[0].Id, PlayerStatus.Paused);

        var round2 = service.GenerateNextRound(tournament.Id);
        Assert.DoesNotContain(round2.Pairings, p => p.WhitePlayerId == players[0].Id || p.BlackPlayerId == players[0].Id);
        CompleteCurrentRound(service, tournament.Id);

        service.SetPlayerStatus(tournament.Id, players[0].Id, PlayerStatus.Active);
        var round3 = service.GenerateNextRound(tournament.Id);
        Assert.Contains(round3.Pairings, p => p.WhitePlayerId == players[0].Id || p.BlackPlayerId == players[0].Id);

        // Runde 2 wurde nicht rückwirkend verändert.
        var round2After = service.RequireTournament(tournament.Id).Rounds.Single(r => r.RoundNumber == 2);
        Assert.DoesNotContain(round2After.Pairings, p => p.WhitePlayerId == players[0].Id || p.BlackPlayerId == players[0].Id);
    }

    [Fact]
    public void Swiss_DuplicateFideId_IsBlocked()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Dupe", new TournamentSettings { Format = TournamentFormat.Swiss });
        service.AddPlayer(tournament.Id, new Player { Name = "Synth A", FideId = "12345678" });

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.AddPlayer(tournament.Id, new Player { Name = "Synth B", FideId = "12345678" }));
        Assert.Contains("FIDE-ID", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ---------- Phase 6: Manuelle Paarungen ----------

    [Fact]
    public void ManualPairing_PersistsAndCountsAsPlayedForNextRound()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Manual", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 6);

        var round1 = service.GenerateNextRound(tournament.Id);
        var board1 = round1.Pairings.Single(p => p.BoardNumber == 1);
        var white = board1.WhitePlayerId!.Value;
        var black = board1.BlackPlayerId!.Value;

        service.OverridePairing(tournament.Id, 1, 1, white, black, "Manuell bestätigt");
        service.RecordResult(tournament.Id, 1, 1, GameResultKind.WhiteWin);
        CompleteCurrentRound(service, tournament.Id);

        // Manuelle Paarung bleibt persistiert und als Override markiert.
        var persistedBoard1 = service.RequireTournament(tournament.Id).Rounds.Single(r => r.RoundNumber == 1)
            .Pairings.Single(p => p.BoardNumber == 1);
        Assert.True(persistedBoard1.IsManualOverride);
        Assert.Equal(GameResultKind.WhiteWin, persistedBoard1.Result.Kind);

        // Folgerunde berücksichtigt die Begegnung als gespielt: kein Rematch bei 6 Spielern (vermeidbar).
        var round2 = service.GenerateNextRound(tournament.Id);
        Assert.DoesNotContain(round2.Pairings, p =>
            (p.WhitePlayerId == white && p.BlackPlayerId == black) ||
            (p.WhitePlayerId == black && p.BlackPlayerId == white));
    }

    [Fact]
    public void ManualPairing_RejectsSamePlayerOnTwoBoards()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Manual Guard", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 6);

        var round1 = service.GenerateNextRound(tournament.Id);
        var board1White = round1.Pairings.Single(p => p.BoardNumber == 1).WhitePlayerId!.Value;
        var board2 = round1.Pairings.Single(p => p.BoardNumber == 2);

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.OverridePairing(tournament.Id, 1, 2, board1White, board2.BlackPlayerId, null));
        Assert.Contains("mehrfach", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ManualPairing_RejectsInactivePlayer()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("Manual Inactive", new TournamentSettings
        {
            Format = TournamentFormat.Swiss,
            PlannedRounds = 5
        });
        var players = AddPlayers(service, tournament.Id, 6);

        var round1 = service.GenerateNextRound(tournament.Id);
        var board1 = round1.Pairings.Single(p => p.BoardNumber == 1);
        service.SetPlayerStatus(tournament.Id, players[5].Id, PlayerStatus.Withdrawn);

        var ex = Assert.Throws<InvalidOperationException>(() =>
            service.OverridePairing(tournament.Id, 1, 1, board1.WhitePlayerId, players[5].Id, null));
        Assert.Contains("nicht aktiv", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ---------- Phase 5: Jeder-gegen-jeden / Round-Robin ----------

    [Theory]
    [InlineData(4)]
    [InlineData(5)]
    [InlineData(6)]
    [InlineData(12)]
    [InlineData(13)]
    public void RoundRobin_EveryPairPlaysExactlyOnce_AndByesAreCorrect(int playerCount)
    {
        var expectedRounds = playerCount % 2 == 0 ? playerCount - 1 : playerCount;
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament($"RR {playerCount}", new TournamentSettings
        {
            Format = TournamentFormat.RoundRobin,
            PlannedRounds = expectedRounds
        });
        var players = AddPlayers(service, tournament.Id, playerCount);

        var matchups = new List<(Guid, Guid)>();
        var byeCountPerPlayer = players.ToDictionary(p => p.Id, _ => 0);

        for (var round = 1; round <= expectedRounds; round++)
        {
            var generated = service.GenerateNextRound(tournament.Id);
            foreach (var pairing in generated.Pairings)
            {
                if (pairing.IsBye)
                {
                    byeCountPerPlayer[pairing.WhitePlayerId!.Value]++;
                }
                else
                {
                    var a = pairing.WhitePlayerId!.Value;
                    var b = pairing.BlackPlayerId!.Value;
                    matchups.Add(a.CompareTo(b) < 0 ? (a, b) : (b, a));
                }
            }

            CompleteCurrentRound(service, tournament.Id);
        }

        Assert.Equal(expectedRounds, service.RequireTournament(tournament.Id).Rounds.Count);

        // Jede ungeordnete Paarung genau einmal.
        var distinct = matchups.Distinct().ToList();
        Assert.Equal(matchups.Count, distinct.Count);
        Assert.Equal(playerCount * (playerCount - 1) / 2, distinct.Count);

        // Byes: gerade Spielerzahl -> keine; ungerade -> jeder genau einmal.
        if (playerCount % 2 == 0)
        {
            Assert.All(byeCountPerPlayer.Values, count => Assert.Equal(0, count));
        }
        else
        {
            Assert.All(byeCountPerPlayer.Values, count => Assert.Equal(1, count));
        }

        // Über das Limit hinaus keine weitere Runde.
        Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
    }

    [Fact]
    public void RoundRobin_LateEntryAfterStart_IsBlockedWithClearMessage()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("RR Late", new TournamentSettings
        {
            Format = TournamentFormat.RoundRobin,
            PlannedRounds = 5
        });
        AddPlayers(service, tournament.Id, 6);

        service.GenerateNextRound(tournament.Id);
        CompleteCurrentRound(service, tournament.Id);

        service.AddPlayer(tournament.Id, new Player { Name = "Synth RR Spät", Rating = new RatingProfile { ManualTwz = 1500 } });

        var ex = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
        Assert.Contains("fixiert", ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Neuplanung", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void RoundRobin_WithdrawalAfterStart_IsBlockedWithClearMessage()
    {
        var service = new TournamentService(new InMemoryTournamentStore());
        var tournament = service.CreateTournament("RR Withdraw", new TournamentSettings
        {
            Format = TournamentFormat.RoundRobin,
            PlannedRounds = 5
        });
        var players = AddPlayers(service, tournament.Id, 6);

        service.GenerateNextRound(tournament.Id);
        CompleteCurrentRound(service, tournament.Id);

        service.SetPlayerStatus(tournament.Id, players[0].Id, PlayerStatus.Withdrawn);

        var ex = Assert.Throws<InvalidOperationException>(() => service.GenerateNextRound(tournament.Id));
        Assert.Contains("fixiert", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ---------- Helpers ----------

    private static List<Player> AddPlayers(TournamentService service, Guid tournamentId, int count)
    {
        var players = new List<Player>();
        for (var i = 1; i <= count; i++)
        {
            players.Add(service.AddPlayer(tournamentId, new Player
            {
                Name = $"Synth {i:00}",
                Rating = new RatingProfile { ManualTwz = 2000 - i * 7 }
            }));
        }

        return players;
    }

    private static void PlayOneRound(TournamentService service, Guid tournamentId)
    {
        service.GenerateNextRound(tournamentId);
        CompleteCurrentRound(service, tournamentId);
    }

    private static void CompleteCurrentRound(TournamentService service, Guid tournamentId)
    {
        var round = service.RequireTournament(tournamentId).Rounds.OrderByDescending(r => r.RoundNumber).First();
        foreach (var pairing in round.Pairings.Where(p => !p.IsBye))
        {
            service.RecordResult(tournamentId, round.RoundNumber, pairing.BoardNumber, GameResultKind.WhiteWin);
        }
    }

    private static List<List<(int, Guid?, Guid?)>> SnapshotPairings(TournamentService service, Guid tournamentId)
    {
        return service.RequireTournament(tournamentId).Rounds
            .OrderBy(r => r.RoundNumber)
            .Select(r => r.Pairings
                .OrderBy(p => p.BoardNumber)
                .Select(p => (p.BoardNumber, p.WhitePlayerId, p.BlackPlayerId))
                .ToList())
            .ToList();
    }
}
