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
            return _tournaments.Values.OrderBy(t => t.CreatedOn).ThenBy(t => t.Name).ToList();
        }
    }

    public TournamentState? Get(Guid id)
    {
        lock (_sync)
        {
            return _tournaments.TryGetValue(id, out var tournament) ? tournament : null;
        }
    }

    public void Save(TournamentState tournament)
    {
        lock (_sync)
        {
            _tournaments[tournament.Id] = tournament;
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

            var json = JsonSerializer.Serialize(stored);
            var workingCopy = JsonSerializer.Deserialize<TournamentState>(json)
                ?? throw new InvalidOperationException($"Turnier {id} konnte nicht für eine atomare Änderung geladen werden.");
            var result = update(workingCopy);
            _tournaments[id] = workingCopy;
            return result;
        }
    }

    public bool Delete(Guid id)
    {
        lock (_sync)
        {
            return _tournaments.Remove(id);
        }
    }
}
