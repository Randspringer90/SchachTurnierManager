using System.Text.Json;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public sealed class InMemoryTournamentStore : ITournamentStore
{
    private readonly object _sync = new();
    private readonly Dictionary<Guid, TournamentState> _tournaments = new();
    private readonly Dictionary<Guid, DateTimeOffset> _updatedAt = new();

    public IReadOnlyList<TournamentState> List()
    {
        lock (_sync)
        {
            return _tournaments.Values.OrderBy(t => t.CreatedOn).ThenBy(t => t.Name).Select(Clone).ToList();
        }
    }

    public IReadOnlyList<TournamentSummary> ListSummaries()
    {
        lock (_sync)
        {
            return _tournaments.Values.OrderBy(t => t.CreatedOn).ThenBy(t => t.Name)
                .Select(t => TournamentSummary.From(t, _updatedAt[t.Id])).ToList();
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
            var exists = _tournaments.TryGetValue(tournament.Id, out var existing);
            if (!overwriteExisting && exists)
                throw new InvalidOperationException($"Turnier {tournament.Id} existiert bereits.");
            // The revision belongs to this store, never to the caller or to an imported backup.
            tournament.Revision = (existing?.Revision ?? 0) + 1;
            _tournaments[tournament.Id] = Clone(tournament);
            _updatedAt[tournament.Id] = DateTimeOffset.UtcNow;
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
            workingCopy.Revision = stored.Revision;
            if (JsonSerializer.Serialize(workingCopy) == JsonSerializer.Serialize(stored))
            {
                return result;
            }

            workingCopy.Revision = stored.Revision + 1;
            _tournaments[id] = Clone(workingCopy);
            _updatedAt[id] = DateTimeOffset.UtcNow;
            return result;
        }
    }

    public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null)
    {
        lock (_sync)
        {
            if (!_tournaments.TryGetValue(id, out var stored)) return false;
            beforeDelete?.Invoke(Clone(stored));
            _updatedAt.Remove(id);
            return _tournaments.Remove(id);
        }
    }

    private static TournamentState Clone(TournamentState state) =>
        JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(state))
        ?? throw new InvalidOperationException("Turniersnapshot konnte nicht kopiert werden.");
}
