using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

/// <summary>
/// Read model for tournament lists. It is served from indexed columns and never requires
/// deserializing a whole tournament, and it carries no participant data.
/// </summary>
public sealed record TournamentSummary(
    Guid Id,
    string Name,
    DateOnly CreatedOn,
    DateTimeOffset UpdatedAt,
    long Revision,
    TournamentFormat Format,
    int PlayerCount,
    int RoundCount)
{
    public static TournamentSummary From(TournamentState tournament, DateTimeOffset updatedAt)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        return new TournamentSummary(tournament.Id, tournament.Name, tournament.CreatedOn, updatedAt,
            tournament.Revision, tournament.Settings.Format, tournament.Players.Count, tournament.Rounds.Count);
    }
}
