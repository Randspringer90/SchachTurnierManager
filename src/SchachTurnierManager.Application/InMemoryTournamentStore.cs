using System.Text.Json;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public sealed class InMemoryTournamentStore : ITournamentStore
{
    private readonly object _sync = new();
    private readonly Dictionary<Guid, TournamentState> _tournaments = new();

    public IReadOnlyList<TournamentState> List()
    {
        lock (_sync)
        {
            return _tournaments.Values.OrderBy(t => t.CreatedOn).ThenBy(t => t.Name).Select(Clone).ToList();
        }
    }

    public TournamentState? Get(Guid id)
    {
        lock (_sync)
        {
            return _tournaments.TryGetValue(id, out var tournament) ? Clone(tournament) : null;
        }
    }

    public void Save(TournamentState tournament, bool overwriteExisting = true)
    {
        lock (_sync)
        {
            if (!overwriteExisting && _tournaments.ContainsKey(tournament.Id))
                throw new InvalidOperationException($"Turnier {tournament.Id} existiert bereits.");
            _tournaments[tournament.Id] = Clone(tournament);
        }
    }

    public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update)
    {
        ArgumentNullException.ThrowIfNull(update);
        lock (_sync)
        {
            if (!_tournaments.TryGetValue(id, out var stored))
            {
                throw new InvalidOperationException($"Turnier {id} wurde nicht gefunden.");
            }

            var workingCopy = Clone(stored);
            var result = update(workingCopy);
            _tournaments[id] = Clone(workingCopy);
            return result;
        }
    }

    public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null)
    {
        lock (_sync)
        {
            if (!_tournaments.TryGetValue(id, out var stored)) return false;
            beforeDelete?.Invoke(Clone(stored));
            return _tournaments.Remove(id);
        }
    }
    private static TournamentState Clone(TournamentState state) =>
        JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(state))
        ?? throw new InvalidOperationException("Turniersnapshot konnte nicht kopiert werden.");
}
