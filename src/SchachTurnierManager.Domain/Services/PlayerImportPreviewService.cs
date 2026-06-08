using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class PlayerImportPreviewService
{
    private readonly ExternalPlayerImportService _externalPlayerImport = new();

    public PlayerImportPreview Preview(TournamentState tournament, string csv, bool replaceExisting)
    {
        var importedPlayers = PlayerCsvCodec.ImportPlayers(csv);
        var rows = new List<PlayerImportPreviewRow>();
        var globalWarnings = new List<string>();
        var seenFideIds = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var seenNationalIds = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var seenNameBirthYears = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

        if (string.IsNullOrWhiteSpace(csv) || importedPlayers.Count == 0)
        {
            globalWarnings.Add("Die Importdatei enthält keine importierbaren Teilnehmerzeilen.");
        }

        if (replaceExisting && tournament.Rounds.Count > 0)
        {
            globalWarnings.Add("Bestehende Teilnehmer können nach ausgelosten Runden nicht ersetzt werden. Der Import wäre blockiert.");
        }

        for (var index = 0; index < importedPlayers.Count; index++)
        {
            var rowNumber = index + 1;
            var player = NormalizePreviewPlayer(importedPlayers[index], rowNumber);
            var profile = ToExternalProfile(player);
            var duplicateCheck = replaceExisting
                ? new ExternalPlayerDuplicateCheck { Profile = profile }
                : _externalPlayerImport.CheckDuplicates(tournament, profile);
            var warnings = new List<string>();
            var blockingIssues = new List<string>();

            if (string.IsNullOrWhiteSpace(player.Name))
            {
                blockingIssues.Add("Name fehlt.");
            }

            AddDuplicateWarning(seenFideIds, player.FideId, rowNumber, "FIDE-ID", warnings);
            AddDuplicateWarning(seenNationalIds, player.NationalId, rowNumber, "DSB-ID/National-ID", warnings);
            if (player.BirthYear is not null)
            {
                AddDuplicateWarning(seenNameBirthYears, NormalizeNameBirthYearKey(player.Name, player.BirthYear.Value), rowNumber, "Name + Geburtsjahr", warnings);
            }

            if (duplicateCheck.HasLikelyDuplicate)
            {
                warnings.Add("Mögliche Dublette mit bestehenden Teilnehmern gefunden.");
            }

            if (replaceExisting && tournament.Rounds.Count > 0)
            {
                blockingIssues.Add("Ersetzen vorhandener Teilnehmer ist nach ausgelosten Runden nicht erlaubt.");
            }

            rows.Add(new PlayerImportPreviewRow
            {
                RowNumber = rowNumber,
                Player = player,
                Profile = profile,
                DuplicateCheck = duplicateCheck,
                Warnings = warnings.Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
                BlockingIssues = blockingIssues.Distinct(StringComparer.OrdinalIgnoreCase).ToArray()
            });
        }

        return new PlayerImportPreview
        {
            ReplaceExisting = replaceExisting,
            Rows = rows,
            GlobalWarnings = globalWarnings
        };
    }

    private static Player NormalizePreviewPlayer(Player player, int rowNumber)
    {
        return player with
        {
            Id = player.Id == Guid.Empty ? Guid.NewGuid() : player.Id,
            StartingRank = player.StartingRank <= 0 ? rowNumber : player.StartingRank,
            Status = player.Status
        };
    }

    private static ExternalPlayerProfile ToExternalProfile(Player player)
    {
        var hasFideId = !string.IsNullOrWhiteSpace(player.FideId);
        return new ExternalPlayerProfile
        {
            Source = hasFideId ? ExternalPlayerSource.Fide : ExternalPlayerSource.Dsb,
            ExternalId = hasFideId ? player.FideId! : player.NationalId ?? player.Name,
            Name = player.Name,
            Club = player.Club,
            Federation = player.Federation,
            Country = player.Country,
            BirthYear = player.BirthYear,
            Gender = player.Gender,
            FideId = player.FideId,
            NationalId = player.NationalId,
            Title = player.Title,
            Elo = player.Rating.Elo,
            RapidElo = player.Rating.RapidElo,
            BlitzElo = player.Rating.BlitzElo,
            Dwz = player.Rating.Dwz,
            DwzIndex = player.Rating.DwzIndex,
            Notes = player.Notes,
            RetrievedAt = DateTimeOffset.UtcNow,
            Confidence = 0.70,
            Warnings = Array.Empty<string>()
        };
    }

    private static void AddDuplicateWarning(IDictionary<string, int> seenKeys, string? key, int rowNumber, string label, ICollection<string> warnings)
    {
        if (string.IsNullOrWhiteSpace(key))
        {
            return;
        }

        var normalized = NormalizeIdentifier(key);
        if (normalized.Length == 0)
        {
            return;
        }

        if (seenKeys.TryGetValue(normalized, out var firstRow))
        {
            warnings.Add($"{label} kommt bereits in Importzeile {firstRow} vor.");
            return;
        }

        seenKeys[normalized] = rowNumber;
    }

    private static string NormalizeIdentifier(string value) => new(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());

    private static string NormalizeNameBirthYearKey(string name, int birthYear)
    {
        var normalizedName = string.Join(' ', name.Replace(',', ' ')
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(part => part.Replace("ß", "ss", StringComparison.OrdinalIgnoreCase).ToUpperInvariant())
            .OrderBy(part => part, StringComparer.OrdinalIgnoreCase));
        return $"{normalizedName}|{birthYear}";
    }
}
