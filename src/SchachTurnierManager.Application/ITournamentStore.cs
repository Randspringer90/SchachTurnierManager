using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public interface ITournamentStore
{
    IReadOnlyList<TournamentState> List();
    TournamentState? Get(Guid id);
    void Save(TournamentState tournament, bool overwriteExisting = true);
    TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update);
    bool Delete(Guid id, Action<TournamentState>? beforeDelete = null);
}
