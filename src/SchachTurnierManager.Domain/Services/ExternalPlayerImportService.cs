using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class ExternalPlayerImportService
{
    public ExternalPlayerDuplicateCheck CheckDuplicates(TournamentState tournament, ExternalPlayerProfile profile, Guid? ignorePlayerId = null)
    {
        var matches = tournament.Players
            .Where(player => ignorePlayerId is null || player.Id != ignorePlayerId.Value)
            .SelectMany(player => FindMatches(player, profile))
            .GroupBy(match => match.PlayerId)
            .Select(group => group.OrderByDescending(match => match.Score).First())
            .OrderByDescending(match => match.Score)
            .ThenBy(match => match.PlayerName, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var likelyMatchIds = matches
            .Where(match => match.Score >= 80)
            .Select(match => match.PlayerId)
            .ToHashSet();

        var conflicts = tournament.Players
            .Where(player => likelyMatchIds.Contains(player.Id))
            .SelectMany(player => BuildConflicts(player, profile, overwriteExistingValues: false))
            .OrderByDescending(conflict => conflict.Severity)
            .ThenBy(conflict => conflict.PlayerName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(conflict => conflict.FieldName, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new ExternalPlayerDuplicateCheck
        {
            Profile = profile,
            Matches = matches,
            Conflicts = conflicts
        };
    }

    public ExternalPlayerApplyResult CreatePlayer(TournamentState tournament, ExternalPlayerProfile profile)
    {
        ValidateProfile(profile);
        var duplicateCheck = CheckDuplicates(tournament, profile);
        var player = profile.ToPlayer() with
        {
            Id = Guid.NewGuid(),
            Status = PlayerStatus.Active,
            StartingRank = tournament.Players.Count + 1,
            Notes = BuildImportNote(null, profile)
        };

        return new ExternalPlayerApplyResult
        {
            Player = player,
            Created = true,
            Updated = false,
            DuplicateCheck = duplicateCheck,
            Conflicts = duplicateCheck.Conflicts,
            ChangedFields = ChangedFieldsForCreate(player),
            Message = duplicateCheck.HasLikelyDuplicate
                ? $"{profile.Name} wurde als neuer Teilnehmer vorbereitet; mögliche Dublette bitte prüfen."
                : $"{profile.Name} wurde als neuer Teilnehmer vorbereitet."
        };
    }

    public ExternalPlayerApplyResult UpdatePlayer(TournamentState tournament, Guid playerId, ExternalPlayerProfile profile, bool overwriteExistingValues)
    {
        ValidateProfile(profile);
        var existing = tournament.Players.FirstOrDefault(player => player.Id == playerId)
            ?? throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");

        var conflicts = BuildConflicts(existing, profile, overwriteExistingValues)
            .OrderByDescending(conflict => conflict.Severity)
            .ThenBy(conflict => conflict.FieldName, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var changedFields = new List<string>();
        var rating = existing.Rating;
        var updatedRating = rating with
        {
            Elo = MergeValue(rating.Elo, profile.Elo, overwriteExistingValues, changedFields, "Elo"),
            RapidElo = MergeValue(rating.RapidElo, profile.RapidElo, overwriteExistingValues, changedFields, "Rapid-Elo"),
            BlitzElo = MergeValue(rating.BlitzElo, profile.BlitzElo, overwriteExistingValues, changedFields, "Blitz-Elo"),
            Dwz = MergeValue(rating.Dwz, profile.Dwz, overwriteExistingValues, changedFields, "DWZ"),
            DwzIndex = MergeValue(rating.DwzIndex, profile.DwzIndex, overwriteExistingValues, changedFields, "DWZ-Index")
        };

        var updated = existing with
        {
            Name = MergeValue(existing.Name, profile.Name, overwriteExistingValues, changedFields, "Name") ?? existing.Name,
            Club = MergeValue(existing.Club, profile.Club, overwriteExistingValues, changedFields, "Verein"),
            Federation = MergeValue(existing.Federation, profile.Federation, overwriteExistingValues, changedFields, "Verband/Federation"),
            Country = MergeValue(existing.Country, profile.Country, overwriteExistingValues, changedFields, "Land"),
            BirthYear = MergeValue(existing.BirthYear, profile.BirthYear, overwriteExistingValues, changedFields, "Geburtsjahr"),
            Gender = MergeGender(existing.Gender, profile.Gender, overwriteExistingValues, changedFields),
            FideId = MergeValue(existing.FideId, profile.FideId, overwriteExistingValues, changedFields, "FIDE-ID"),
            NationalId = MergeValue(existing.NationalId, profile.NationalId, overwriteExistingValues, changedFields, "DSB-ID/National-ID"),
            Title = MergeValue(existing.Title, profile.Title, overwriteExistingValues, changedFields, "Titel"),
            Rating = updatedRating,
            Notes = BuildImportNote(existing.Notes, profile)
        };

        return new ExternalPlayerApplyResult
        {
            Player = updated,
            Created = false,
            Updated = true,
            DuplicateCheck = CheckDuplicates(tournament, profile, playerId),
            Conflicts = conflicts,
            ChangedFields = changedFields.Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
            Message = changedFields.Count == 0
                ? $"{existing.Name} war bereits aktuell; Quellenhinweis wurde ergänzt."
                : $"{existing.Name} wurde mit externen Daten aktualisiert."
        };
    }

    private static IEnumerable<ExternalPlayerDuplicateMatch> FindMatches(Player player, ExternalPlayerProfile profile)
    {
        if (!string.IsNullOrWhiteSpace(player.FideId) && !string.IsNullOrWhiteSpace(profile.FideId)
            && string.Equals(NormalizeIdentifier(player.FideId), NormalizeIdentifier(profile.FideId), StringComparison.OrdinalIgnoreCase))
        {
            yield return new ExternalPlayerDuplicateMatch
            {
                PlayerId = player.Id,
                PlayerName = player.Name,
                Kind = ExternalPlayerDuplicateKind.FideId,
                Score = 100,
                Reason = $"FIDE-ID stimmt überein ({profile.FideId})."
            };
        }

        if (!string.IsNullOrWhiteSpace(player.NationalId) && !string.IsNullOrWhiteSpace(profile.NationalId)
            && string.Equals(NormalizeIdentifier(player.NationalId), NormalizeIdentifier(profile.NationalId), StringComparison.OrdinalIgnoreCase))
        {
            yield return new ExternalPlayerDuplicateMatch
            {
                PlayerId = player.Id,
                PlayerName = player.Name,
                Kind = ExternalPlayerDuplicateKind.NationalId,
                Score = 95,
                Reason = $"Nationale ID/DSB-ID stimmt überein ({profile.NationalId})."
            };
        }

        if (profile.BirthYear is not null && player.BirthYear == profile.BirthYear
            && NamesLikelyEqual(player.Name, profile.Name))
        {
            yield return new ExternalPlayerDuplicateMatch
            {
                PlayerId = player.Id,
                PlayerName = player.Name,
                Kind = ExternalPlayerDuplicateKind.NameAndBirthYear,
                Score = 85,
                Reason = $"Name und Geburtsjahr stimmen wahrscheinlich überein ({profile.BirthYear})."
            };
        }
        else if (NamesLikelyEqual(player.Name, profile.Name))
        {
            yield return new ExternalPlayerDuplicateMatch
            {
                PlayerId = player.Id,
                PlayerName = player.Name,
                Kind = ExternalPlayerDuplicateKind.NameOnly,
                Score = 60,
                Reason = "Name ist sehr ähnlich; Geburtsjahr oder externe ID fehlen für sichere Zuordnung."
            };
        }
    }

    private static IReadOnlyList<ExternalPlayerDataConflict> BuildConflicts(Player player, ExternalPlayerProfile profile, bool overwriteExistingValues)
    {
        var conflicts = new List<ExternalPlayerDataConflict>();

        AddConflict(conflicts, player, "Name", player.Name, profile.Name, ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "Verein", player.Club, profile.Club, ExternalPlayerConflictSeverity.Information, overwriteExistingValues);
        AddConflict(conflicts, player, "Verband/Federation", player.Federation, profile.Federation, ExternalPlayerConflictSeverity.Information, overwriteExistingValues);
        AddConflict(conflicts, player, "Land", player.Country, profile.Country, ExternalPlayerConflictSeverity.Information, overwriteExistingValues);
        AddConflict(conflicts, player, "Geburtsjahr", Format(player.BirthYear), Format(profile.BirthYear), ExternalPlayerConflictSeverity.Critical, overwriteExistingValues);
        AddConflict(conflicts, player, "Geschlecht", Format(player.Gender), Format(profile.Gender), ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "FIDE-ID", player.FideId, profile.FideId, ExternalPlayerConflictSeverity.Critical, overwriteExistingValues);
        AddConflict(conflicts, player, "DSB-ID/National-ID", player.NationalId, profile.NationalId, ExternalPlayerConflictSeverity.Critical, overwriteExistingValues);
        AddConflict(conflicts, player, "Titel", player.Title, profile.Title, ExternalPlayerConflictSeverity.Information, overwriteExistingValues);
        AddConflict(conflicts, player, "Elo", Format(player.Rating.Elo), Format(profile.Elo), ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "Rapid-Elo", Format(player.Rating.RapidElo), Format(profile.RapidElo), ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "Blitz-Elo", Format(player.Rating.BlitzElo), Format(profile.BlitzElo), ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "DWZ", Format(player.Rating.Dwz), Format(profile.Dwz), ExternalPlayerConflictSeverity.Warning, overwriteExistingValues);
        AddConflict(conflicts, player, "DWZ-Index", Format(player.Rating.DwzIndex), Format(profile.DwzIndex), ExternalPlayerConflictSeverity.Information, overwriteExistingValues);

        return conflicts;
    }

    private static void AddConflict(
        ICollection<ExternalPlayerDataConflict> conflicts,
        Player player,
        string fieldName,
        string? localValue,
        string? externalValue,
        ExternalPlayerConflictSeverity severity,
        bool overwriteExistingValues)
    {
        var local = NormalizeDisplayValue(localValue);
        var external = NormalizeDisplayValue(externalValue);
        if (local is null || external is null || string.Equals(local, external, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        conflicts.Add(new ExternalPlayerDataConflict
        {
            PlayerId = player.Id,
            PlayerName = player.Name,
            FieldName = fieldName,
            LocalValue = local,
            ExternalValue = external,
            Severity = severity,
            WillOverwrite = overwriteExistingValues,
            Recommendation = overwriteExistingValues
                ? "Überschreiben ist aktiviert: externer Wert wird beim Anwenden übernommen. Vorher prüfen."
                : "Lokaler Wert bleibt erhalten. Zum Übernehmen externer Daten Überschreiben aktivieren."
        });
    }

    private static string? MergeValue(string? current, string? incoming, bool overwriteExistingValues, ICollection<string> changedFields, string fieldName)
    {
        var normalizedIncoming = string.IsNullOrWhiteSpace(incoming) ? null : incoming.Trim();
        var normalizedCurrent = string.IsNullOrWhiteSpace(current) ? null : current.Trim();
        if (normalizedIncoming is null)
        {
            return normalizedCurrent;
        }

        if (normalizedCurrent is null || overwriteExistingValues && !string.Equals(normalizedCurrent, normalizedIncoming, StringComparison.Ordinal))
        {
            changedFields.Add(fieldName);
            return normalizedIncoming;
        }

        return normalizedCurrent;
    }

    private static int? MergeValue(int? current, int? incoming, bool overwriteExistingValues, ICollection<string> changedFields, string fieldName)
    {
        if (incoming is null or <= 0)
        {
            return current;
        }

        if (current is null or <= 0 || overwriteExistingValues && current != incoming)
        {
            changedFields.Add(fieldName);
            return incoming;
        }

        return current;
    }

    private static GenderCategory MergeGender(GenderCategory current, GenderCategory incoming, bool overwriteExistingValues, ICollection<string> changedFields)
    {
        if (incoming == GenderCategory.Unknown)
        {
            return current;
        }

        if (current == GenderCategory.Unknown || overwriteExistingValues && current != incoming)
        {
            changedFields.Add("Geschlecht");
            return incoming;
        }

        return current;
    }

    private static IReadOnlyList<string> ChangedFieldsForCreate(Player player)
    {
        var fields = new List<string> { "Name" };
        if (!string.IsNullOrWhiteSpace(player.Club)) fields.Add("Verein");
        if (!string.IsNullOrWhiteSpace(player.Federation)) fields.Add("Verband/Federation");
        if (!string.IsNullOrWhiteSpace(player.Country)) fields.Add("Land");
        if (player.BirthYear is not null) fields.Add("Geburtsjahr");
        if (player.Gender != GenderCategory.Unknown) fields.Add("Geschlecht");
        if (!string.IsNullOrWhiteSpace(player.FideId)) fields.Add("FIDE-ID");
        if (!string.IsNullOrWhiteSpace(player.NationalId)) fields.Add("DSB-ID/National-ID");
        if (!string.IsNullOrWhiteSpace(player.Title)) fields.Add("Titel");
        if (player.Rating.Elo is not null) fields.Add("Elo");
        if (player.Rating.RapidElo is not null) fields.Add("Rapid-Elo");
        if (player.Rating.BlitzElo is not null) fields.Add("Blitz-Elo");
        if (player.Rating.Dwz is not null) fields.Add("DWZ");
        if (player.Rating.DwzIndex is not null) fields.Add("DWZ-Index");
        return fields;
    }

    private static void ValidateProfile(ExternalPlayerProfile profile)
    {
        if (string.IsNullOrWhiteSpace(profile.Name))
        {
            throw new ArgumentException("Externes Spielerprofil enthält keinen Namen.", nameof(profile));
        }
    }

    private static string BuildImportNote(string? existingNotes, ExternalPlayerProfile profile)
    {
        var source = profile.Source.ToString();
        var id = string.IsNullOrWhiteSpace(profile.ExternalId) ? profile.FideId ?? profile.NationalId ?? "ohne ID" : profile.ExternalId;
        var sourceNote = $"Externe Spielerdaten übernommen aus {source} ({id}) am {DateTimeOffset.Now:yyyy-MM-dd HH:mm}. Bitte vor Turnierstart prüfen.";
        if (!string.IsNullOrWhiteSpace(profile.ProfileUrl))
        {
            sourceNote += $" Profil: {profile.ProfileUrl}";
        }

        return string.IsNullOrWhiteSpace(existingNotes) ? sourceNote : existingNotes.Trim() + Environment.NewLine + sourceNote;
    }

    private static string NormalizeIdentifier(string value) => new(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());

    private static bool NamesLikelyEqual(string left, string right)
    {
        var leftTokens = NormalizeName(left);
        var rightTokens = NormalizeName(right);
        return leftTokens.Count > 0 && leftTokens.SetEquals(rightTokens);
    }

    private static HashSet<string> NormalizeName(string name)
    {
        var normalized = name.Replace(',', ' ').Replace("ß", "ss", StringComparison.OrdinalIgnoreCase);
        return normalized.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(token => token.ToUpperInvariant())
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
    }

    private static string? NormalizeDisplayValue(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static string? Format(int? value) => value is null or <= 0 ? null : value.Value.ToString(System.Globalization.CultureInfo.InvariantCulture);

    private static string? Format(GenderCategory gender) => gender == GenderCategory.Unknown ? null : gender.ToString();
}
