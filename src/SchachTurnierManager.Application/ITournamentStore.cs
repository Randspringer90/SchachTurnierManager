using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

public interface ITournamentStore
{
    IReadOnlyList<TournamentState> List();

    /// <summary>
    /// Lists tournaments without their content. Persistent stores answer from columns; this
    /// default exists only for simple in-memory decorators.
    /// </summary>
    IReadOnlyList<TournamentSummary> ListSummaries() =>
        List().Select(tournament => TournamentSummary.From(tournament, DateTimeOffset.MinValue)).ToList();

    TournamentState? Get(Guid id);

    /// <summary>Creates or replaces a tournament and assigns the next <see cref="TournamentState.Revision"/>.</summary>
    void Save(TournamentState tournament, bool overwriteExisting = true);

    /// <summary>
    /// Read-modify-write in one atomic step. The revision increases only when the content changed,
    /// so an idempotent retry leaves the stored tournament byte-identical.
    /// </summary>
    TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update);

    bool Delete(Guid id, Action<TournamentState>? beforeDelete = null);
}
