using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application.External;

internal static class ExternalPlayerFieldSelection
{
    private static readonly HashSet<string> Allowed = new(StringComparer.Ordinal)
    {
        "name", "club", "federation", "country", "birthYear", "gender", "fideId", "nationalId", "title",
        "elo", "rapidElo", "blitzElo", "dwz", "dwzIndex"
    };

    public static ExternalPlayerProfile Prepare(ExternalPlayerProfile profile, Player? target, IReadOnlyList<string> selected)
    {
        if (selected.Count is < 1 or > 14 || selected.Any(field => field is null || !Allowed.Contains(field)) ||
            selected.Distinct(StringComparer.Ordinal).Count() != selected.Count || (target is null && !selected.Contains("name")))
            throw new InvalidOperationException("Nur ausdruecklich bestaetigte bekannte Felder uebernehmen; neue Teilnehmer benoetigen den Namen.");
        var fields = selected.ToHashSet(StringComparer.Ordinal);
        return profile with
        {
            Name = fields.Contains("name") ? profile.Name : target!.Name,
            Club = fields.Contains("club") ? profile.Club : null,
            Federation = fields.Contains("federation") ? profile.Federation : null,
            Country = fields.Contains("country") ? profile.Country : null,
            BirthYear = fields.Contains("birthYear") ? profile.BirthYear : null,
            Gender = fields.Contains("gender") ? profile.Gender : GenderCategory.Unknown,
            FideId = fields.Contains("fideId") ? profile.FideId : null,
            NationalId = fields.Contains("nationalId") ? profile.NationalId : null,
            Title = fields.Contains("title") ? profile.Title : null,
            Elo = fields.Contains("elo") ? profile.Elo : null,
            RapidElo = fields.Contains("rapidElo") ? profile.RapidElo : null,
            BlitzElo = fields.Contains("blitzElo") ? profile.BlitzElo : null,
            Dwz = fields.Contains("dwz") ? profile.Dwz : null,
            DwzIndex = fields.Contains("dwzIndex") ? profile.DwzIndex : null
        };
    }
}
