using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public interface ITournamentStore
{
    IReadOnlyList<TournamentState> List();
    TournamentState? Get(Guid id);
    void Save(TournamentState tournament);
    bool Delete(Guid id);
}
