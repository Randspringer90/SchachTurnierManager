using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Application;

public sealed class TournamentService(ITournamentStore store)
{
    private readonly ITournamentStore _store = store;
    private readonly RoundRobinPairingEngine _roundRobin = new();
    private readonly SwissPairingEngine _swiss = new();
    private readonly StandingsCalculator _standings = new();
    private readonly CrossTableCalculator _crossTable = new();
    private readonly CategoryStandingsCalculator _categoryStandings = new();
    private readonly HeroCupCalculator _heroCup = new();

    public IReadOnlyList<TournamentState> ListTournaments() => _store.List();

    public TournamentState CreateTournament(string name, TournamentSettings? settings = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Turniername darf nicht leer sein.", nameof(name));
        }

        var tournament = new TournamentState
        {
            Name = name.Trim(),
            Settings = settings ?? new TournamentSettings()
        };
        _store.Save(tournament);
        return tournament;
    }

    public TournamentState SaveImportedTournament(TournamentState tournament, bool overwriteExisting)
    {
        if (string.IsNullOrWhiteSpace(tournament.Name))
        {
            throw new ArgumentException("Importiertes Turnier hat keinen Namen.", nameof(tournament));
        }

        if (!overwriteExisting && _store.Get(tournament.Id) is not null)
        {
            throw new InvalidOperationException($"Turnier {tournament.Id} existiert bereits.");
        }

        EnsureUniquePlayerNames(tournament);
        _store.Save(tournament);
        return tournament;
    }

    public Player AddPlayer(Guid tournamentId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players.Add(normalized);
        _store.Save(tournament);
        return normalized;
    }

    public IReadOnlyList<Player> ImportPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        var tournament = RequireTournament(tournamentId);
        var importedPlayers = PlayerCsvCodec.ImportPlayers(csv);
        if (importedPlayers.Count == 0)
        {
            return Array.Empty<Player>();
        }

        if (replaceExisting)
        {
            if (tournament.Rounds.Count > 0)
            {
                throw new InvalidOperationException("Teilnehmer können nach ausgelosten Runden nicht vollständig ersetzt werden. Nutze stattdessen Ergänzen oder lege ein neues Turnier an.");
            }

            tournament.Players.Clear();
        }

        var added = new List<Player>();
        foreach (var player in importedPlayers)
        {
            var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
            EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
            tournament.Players.Add(normalized);
            added.Add(normalized);
        }

        _store.Save(tournament);
        return added;
    }

    public string ExportPlayersCsv(Guid tournamentId)
    {
        return PlayerCsvCodec.ExportPlayers(RequireTournament(tournamentId).Players);
    }

    public Player UpdatePlayer(Guid tournamentId, Guid playerId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        var normalized = NormalizePlayerForSave(tournament, player with
        {
            Id = existing.Id,
            StartingRank = player.StartingRank <= 0 ? existing.StartingRank : player.StartingRank
        }, preserveExistingRank: true);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players[index] = normalized;
        _store.Save(tournament);
        return normalized;
    }

    public Player SetPlayerStatus(Guid tournamentId, Guid playerId, PlayerStatus status)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        tournament.Players[index] = existing with { Status = status };
        _store.Save(tournament);
        return tournament.Players[index];
    }

    public Player RemovePlayer(Guid tournamentId, Guid playerId)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        var hasPairings = tournament.Rounds
            .SelectMany(r => r.Pairings)
            .Any(p => p.WhitePlayerId == playerId || p.BlackPlayerId == playerId);

        if (!hasPairings)
        {
            tournament.Players.RemoveAt(index);
            _store.Save(tournament);
            return existing;
        }

        var withdrawn = existing with
        {
            Status = PlayerStatus.Withdrawn,
            Notes = AppendNote(existing.Notes, "Automatisch zurückgezogen statt gelöscht, weil bereits Paarungen existieren.")
        };
        tournament.Players[index] = withdrawn;
        _store.Save(tournament);
        return withdrawn;
    }

    public TournamentRound GenerateNextRound(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        if (tournament.Players.Count(p => p.IsActive) < 2)
        {
            throw new InvalidOperationException("Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.");
        }

        TournamentRound nextRound = tournament.Settings.Format switch
        {
            TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament),
            TournamentFormat.Swiss => _swiss.GenerateNextRound(tournament),
            _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
        };

        tournament.Rounds.Add(nextRound);
        _store.Save(tournament);
        return nextRound;
    }

    public TournamentRound RecordResult(Guid tournamentId, int roundNumber, int boardNumber, GameResultKind resultKind)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = tournament.Rounds.FindIndex(r => r.RoundNumber == roundNumber);
        if (roundIndex < 0)
        {
            throw new InvalidOperationException($"Runde {roundNumber} wurde nicht gefunden.");
        }

        var round = tournament.Rounds[roundIndex];
        var foundBoard = false;
        var updatedPairings = round.Pairings
            .Select(p =>
            {
                if (p.BoardNumber != boardNumber)
                {
                    return p;
                }

                foundBoard = true;
                return p with { Result = new GameResult(resultKind) };
            })
            .ToList();

        if (!foundBoard)
        {
            throw new InvalidOperationException($"Brett {boardNumber} wurde in Runde {roundNumber} nicht gefunden.");
        }

        var updated = round with { Pairings = updatedPairings };
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
    }

    public IReadOnlyList<StandingRow> GetStandings(Guid tournamentId)
    {
        return _standings.Calculate(RequireTournament(tournamentId));
    }

    public CrossTable GetCrossTable(Guid tournamentId)
    {
        return _crossTable.Calculate(RequireTournament(tournamentId));
    }

    public IReadOnlyList<CategoryStandingTable> GetCategoryStandings(Guid tournamentId)
    {
        return _categoryStandings.Calculate(RequireTournament(tournamentId));
    }

    public IReadOnlyList<HeroCupRow> GetHeroCup(Guid tournamentId)
    {
        return _heroCup.Calculate(RequireTournament(tournamentId));
    }

    public IReadOnlyList<PairingAudit> GetAudit(Guid tournamentId)
    {
        return RequireTournament(tournamentId).Rounds.Select(r => r.Audit).ToList();
    }

    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private TournamentRound GetNextRoundRobinRound(TournamentState tournament)
    {
        var all = _roundRobin.GenerateAllRounds(tournament.Players.Where(p => p.IsActive).ToList(), tournament.Settings.TwzSource);
        if (tournament.Rounds.Count >= all.Count)
        {
            throw new InvalidOperationException("Alle Rundenturnier-Runden wurden bereits erzeugt.");
        }

        return all[tournament.Rounds.Count];
    }

    private static Player NormalizePlayerForSave(TournamentState tournament, Player player, bool preserveExistingRank)
    {
        if (string.IsNullOrWhiteSpace(player.Name))
        {
            throw new ArgumentException("Spielername ist Pflicht.", nameof(player));
        }

        var startingRank = player.StartingRank;
        if (startingRank <= 0 && !preserveExistingRank)
        {
            startingRank = tournament.Players.Count + 1;
        }

        return player with
        {
            Name = player.Name.Trim(),
            Club = string.IsNullOrWhiteSpace(player.Club) ? null : player.Club.Trim(),
            Federation = string.IsNullOrWhiteSpace(player.Federation) ? null : player.Federation.Trim(),
            Country = string.IsNullOrWhiteSpace(player.Country) ? null : player.Country.Trim(),
            FideId = string.IsNullOrWhiteSpace(player.FideId) ? null : player.FideId.Trim(),
            NationalId = string.IsNullOrWhiteSpace(player.NationalId) ? null : player.NationalId.Trim(),
            Title = string.IsNullOrWhiteSpace(player.Title) ? null : player.Title.Trim(),
            Notes = string.IsNullOrWhiteSpace(player.Notes) ? null : player.Notes.Trim(),
            StartingRank = startingRank <= 0 ? tournament.Players.Count + 1 : startingRank
        };
    }

    private static void EnsureUniquePlayerName(TournamentState tournament, string name, Guid ownId)
    {
        if (tournament.Players.Any(p => p.Id != ownId && string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase)))
        {
            throw new InvalidOperationException($"Ein Spieler mit dem Namen '{name}' existiert bereits in diesem Turnier.");
        }
    }

    private static void EnsureUniquePlayerNames(TournamentState tournament)
    {
        var duplicate = tournament.Players
            .GroupBy(player => player.Name.Trim(), StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicate is not null)
        {
            throw new InvalidOperationException($"Der Spielername '{duplicate.Key}' kommt mehrfach vor.");
        }
    }

    private static string AppendNote(string? existing, string note)
    {
        return string.IsNullOrWhiteSpace(existing) ? note : existing.Trim() + Environment.NewLine + note;
    }
}
