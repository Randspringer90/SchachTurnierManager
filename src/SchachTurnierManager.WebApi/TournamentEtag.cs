using Microsoft.Extensions.Primitives;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.WebApi;

/// <summary>
/// Entity tag of one stored tournament state. It changes with every stored change, so clients can
/// ask "anything new?" without downloading and comparing the whole tournament.
/// </summary>
public static class TournamentEtag
{
    public static string For(TournamentState tournament)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        return $"\"{tournament.Id:N}-{tournament.Revision}\"";
    }

    /// <summary>
    /// True only for exactly one matching tag. Revision 0 (state never written by a revision-aware
    /// store) is never treated as unchanged.
    /// </summary>
    public static bool IsUnchanged(StringValues ifNoneMatch, TournamentState tournament)
    {
        ArgumentNullException.ThrowIfNull(tournament);
        return tournament.Revision > 0 && ifNoneMatch.Count == 1 &&
               string.Equals(ifNoneMatch[0], For(tournament), StringComparison.Ordinal);
    }
}
