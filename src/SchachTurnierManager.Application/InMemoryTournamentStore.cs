using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public sealed class InMemoryTournamentStore : ITournamentStore
{
    private readonly Dictionary<Guid, TournamentState> _tournaments = new();

    public IReadOnlyList<TournamentState> List() => _tournaments.Values.OrderBy(t => t.CreatedOn).ThenBy(t => t.Name).ToList();

    public TournamentState? Get(Guid id) => _tournaments.TryGetValue(id, out var tournament) ? tournament : null;

    public void Save(TournamentState tournament) => _tournaments[tournament.Id] = tournament;
}
