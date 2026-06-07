using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Application;

public sealed class TournamentService(ITournamentStore store)
{
    private readonly ITournamentStore _store = store;
    private readonly RoundRobinPairingEngine _roundRobin = new();
    private readonly SwissPairingEngine _swiss = new();
    private readonly StandingsCalculator _standings = new();

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

    public Player AddPlayer(Guid tournamentId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        if (string.IsNullOrWhiteSpace(player.Name))
        {
            throw new ArgumentException("Spielername ist Pflicht.", nameof(player));
        }

        var startingRank = player.StartingRank <= 0 ? tournament.Players.Count + 1 : player.StartingRank;
        var normalized = player with
        {
            Name = player.Name.Trim(),
            StartingRank = startingRank
        };
        tournament.Players.Add(normalized);
        _store.Save(tournament);
        return normalized;
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
        var updatedPairings = round.Pairings
            .Select(p => p.BoardNumber == boardNumber ? p with { Result = new GameResult(resultKind) } : p)
            .ToList();

        if (updatedPairings.All(p => p.BoardNumber != boardNumber))
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

    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private TournamentRound GetNextRoundRobinRound(TournamentState tournament)
    {
        var all = _roundRobin.GenerateAllRounds(tournament.Players, tournament.Settings.TwzSource);
        if (tournament.Rounds.Count >= all.Count)
        {
            throw new InvalidOperationException("Alle Rundenturnier-Runden wurden bereits erzeugt.");
        }

        return all[tournament.Rounds.Count];
    }
}
