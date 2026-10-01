using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public interface ITournamentStore
{
    IReadOnlyList<TournamentState> List();
    TournamentState? Get(Guid id);
    void Save(TournamentState tournament);
    TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update);
    bool Delete(Guid id);
}
