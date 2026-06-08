using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Application;

public sealed class TournamentService(ITournamentStore store)
{
    private readonly ITournamentStore _store = store;
    private readonly RoundRobinPairingEngine _roundRobin = new();
    private readonly SwissPairingEngine _swiss = new();
    private readonly StandingsCalculator _standings = new();
    private readonly CrossTableCalculator _crossTable = new();
    private readonly CategoryStandingsCalculator _categoryStandings = new();
    private readonly HeroCupCalculator _heroCup = new();
    private readonly RoundDiagnosticsCalculator _roundDiagnostics = new();
    private readonly TournamentExportFormatter _exports = new();
    private readonly ExternalPlayerImportService _externalPlayerImport = new();
    private readonly PlayerImportPreviewService _playerImportPreview = new();

    public IReadOnlyList<TournamentState> ListTournaments() => _store.List();

    public TournamentState CreateTournament(string name, TournamentSettings? settings = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Turniername darf nicht leer sein.", nameof(name));
        }

        var tournament = new TournamentState
        {
            Name = name.Trim(),
            Settings = settings ?? new TournamentSettings()
        };
        _store.Save(tournament);
        return tournament;
    }

    public TournamentState UpdateSettings(Guid tournamentId, TournamentSettings settings)
    {
        var tournament = RequireTournament(tournamentId);
        var normalized = NormalizeSettings(settings);

        if (tournament.Rounds.Count > 0 && normalized.Format != tournament.Settings.Format)
        {
            throw new InvalidOperationException("Das Turnierformat kann nach bereits ausgelosten Runden nicht mehr geändert werden.");
        }

        tournament.Settings = normalized;
        _store.Save(tournament);
        return tournament;
    }

    public TournamentState SaveImportedTournament(TournamentState tournament, bool overwriteExisting)
    {
        if (string.IsNullOrWhiteSpace(tournament.Name))
        {
            throw new ArgumentException("Importiertes Turnier hat keinen Namen.", nameof(tournament));
        }

        if (!overwriteExisting && _store.Get(tournament.Id) is not null)
        {
            throw new InvalidOperationException($"Turnier {tournament.Id} existiert bereits.");
        }

        EnsureUniquePlayerNames(tournament);
        _store.Save(tournament);
        return tournament;
    }


    public ExternalPlayerDuplicateCheck CheckExternalPlayerDuplicates(Guid tournamentId, ExternalPlayerProfile profile)
    {
        return _externalPlayerImport.CheckDuplicates(RequireTournament(tournamentId), profile);
    }

    public ExternalPlayerApplyResult ApplyExternalPlayer(Guid tournamentId, ExternalPlayerProfile profile, Guid? targetPlayerId, bool createIfNoTarget, bool overwriteExistingValues)
    {
        var tournament = RequireTournament(tournamentId);
        ExternalPlayerApplyResult result;

        if (targetPlayerId is not null)
        {
            result = _externalPlayerImport.UpdatePlayer(tournament, targetPlayerId.Value, profile, overwriteExistingValues);
            var index = tournament.Players.FindIndex(player => player.Id == targetPlayerId.Value);
            if (index < 0)
            {
                throw new InvalidOperationException($"Spieler {targetPlayerId} wurde nicht gefunden.");
            }

            var normalized = NormalizePlayerForSave(tournament, result.Player, preserveExistingRank: true);
            EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
            tournament.Players[index] = normalized;
            result = result with { Player = normalized };
        }
        else
        {
            if (!createIfNoTarget)
            {
                throw new InvalidOperationException("Kein Zielspieler angegeben. Wähle einen vorhandenen Teilnehmer oder erlaube das Neuanlegen.");
            }

            result = _externalPlayerImport.CreatePlayer(tournament, profile);
            var normalized = NormalizePlayerForSave(tournament, result.Player, preserveExistingRank: false);
            EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
            tournament.Players.Add(normalized);
            result = result with { Player = normalized };
        }

        _store.Save(tournament);
        return result;
    }

    public Player AddPlayer(Guid tournamentId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players.Add(normalized);
        _store.Save(tournament);
        return normalized;
    }

    public PlayerImportPreview PreviewPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        return _playerImportPreview.Preview(RequireTournament(tournamentId), csv, replaceExisting);
    }
    public IReadOnlyList<Player> ImportPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        var tournament = RequireTournament(tournamentId);
        var importedPlayers = PlayerCsvCodec.ImportPlayers(csv);
        if (importedPlayers.Count == 0)
        {
            return Array.Empty<Player>();
        }

        if (replaceExisting)
        {
            if (tournament.Rounds.Count > 0)
            {
                throw new InvalidOperationException("Teilnehmer können nach ausgelosten Runden nicht vollständig ersetzt werden. Nutze stattdessen Ergänzen oder lege ein neues Turnier an.");
            }

            tournament.Players.Clear();
        }

        var added = new List<Player>();
        foreach (var player in importedPlayers)
        {
            var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
            EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
            tournament.Players.Add(normalized);
            added.Add(normalized);
        }

        _store.Save(tournament);
        return added;
    }

    public string ExportPlayersCsv(Guid tournamentId)
    {
        return PlayerCsvCodec.ExportPlayers(RequireTournament(tournamentId).Players);
    }

    public Player UpdatePlayer(Guid tournamentId, Guid playerId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        var normalized = NormalizePlayerForSave(tournament, player with
        {
            Id = existing.Id,
            StartingRank = player.StartingRank <= 0 ? existing.StartingRank : player.StartingRank
        }, preserveExistingRank: true);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players[index] = normalized;
        _store.Save(tournament);
        return normalized;
    }

    public Player SetPlayerStatus(Guid tournamentId, Guid playerId, PlayerStatus status)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        tournament.Players[index] = existing with { Status = status };
        _store.Save(tournament);
        return tournament.Players[index];
    }

    public Player RemovePlayer(Guid tournamentId, Guid playerId)
    {
        var tournament = RequireTournament(tournamentId);
        var index = tournament.Players.FindIndex(p => p.Id == playerId);
        if (index < 0)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.");
        }

        var existing = tournament.Players[index];
        var hasPairings = tournament.Rounds
            .SelectMany(r => r.Pairings)
            .Any(p => p.WhitePlayerId == playerId || p.BlackPlayerId == playerId);

        if (!hasPairings)
        {
            tournament.Players.RemoveAt(index);
            _store.Save(tournament);
            return existing;
        }

        var withdrawn = existing with
        {
            Status = PlayerStatus.Withdrawn,
            Notes = AppendNote(existing.Notes, "Automatisch zurückgezogen statt gelöscht, weil bereits Paarungen existieren.")
        };
        tournament.Players[index] = withdrawn;
        _store.Save(tournament);
        return withdrawn;
    }

    public TournamentRound GenerateNextRound(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        if (tournament.Players.Count(p => p.IsActive) < 2)
        {
            throw new InvalidOperationException("Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.");
        }

        EnsurePreviousRoundComplete(tournament);

        TournamentRound nextRound = tournament.Settings.Format switch
        {
            TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament),
            TournamentFormat.Swiss => _swiss.GenerateNextRound(tournament),
            _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
        };

        tournament.Rounds.Add(nextRound);
        _store.Save(tournament);
        return nextRound;
    }

    public TournamentRound RecordResult(Guid tournamentId, int roundNumber, int boardNumber, GameResultKind resultKind)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        EnsureRoundEditable(round);

        var foundBoard = false;
        var updatedPairings = round.Pairings
            .Select(p =>
            {
                if (p.BoardNumber != boardNumber)
                {
                    return p;
                }

                foundBoard = true;
                return p with { Result = new GameResult(resultKind), LastChangedAt = DateTimeOffset.UtcNow };
            })
            .ToList();

        if (!foundBoard)
        {
            throw new InvalidOperationException($"Brett {boardNumber} wurde in Runde {roundNumber} nicht gefunden.");
        }

        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
    }

    public TournamentRound OverridePairing(Guid tournamentId, int roundNumber, int boardNumber, Guid? whitePlayerId, Guid? blackPlayerId, string? notes)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        EnsureRoundEditable(round);

        if (whitePlayerId is null && blackPlayerId is null)
        {
            throw new InvalidOperationException("Mindestens ein Spieler muss gesetzt sein.");
        }

        if (whitePlayerId is not null && blackPlayerId is not null && whitePlayerId == blackPlayerId)
        {
            throw new InvalidOperationException("Ein Spieler kann nicht gegen sich selbst spielen.");
        }

        ValidatePlayerCanBePaired(tournament, whitePlayerId, nameof(whitePlayerId));
        ValidatePlayerCanBePaired(tournament, blackPlayerId, nameof(blackPlayerId));

        var foundBoard = false;
        var normalizedNotes = string.IsNullOrWhiteSpace(notes) ? null : notes.Trim();
        var updatedPairings = round.Pairings
            .Select(pairing =>
            {
                if (pairing.BoardNumber != boardNumber)
                {
                    if (PlayerAppearsInPairing(pairing, whitePlayerId) || PlayerAppearsInPairing(pairing, blackPlayerId))
                    {
                        throw new InvalidOperationException("Ein Spieler darf in derselben Runde nicht mehrfach gepaart werden.");
                    }

                    return pairing;
                }

                foundBoard = true;
                if (whitePlayerId is null)
                {
                    throw new InvalidOperationException("Ein Brett benötigt mindestens einen Weißspieler. Für Bye bitte Spieler als Weiß und Schwarz leer lassen.");
                }

                var result = blackPlayerId is null ? new GameResult(GameResultKind.Bye) : GameResult.NotPlayed;
                return pairing with
                {
                    WhitePlayerId = whitePlayerId,
                    BlackPlayerId = blackPlayerId,
                    Result = result,
                    IsManualOverride = true,
                    LastChangedAt = DateTimeOffset.UtcNow,
                    Notes = AppendNote(pairing.Notes, normalizedNotes ?? "Manuell geänderte Paarung")
                };
            })
            .ToList();

        if (!foundBoard)
        {
            throw new InvalidOperationException($"Brett {boardNumber} wurde in Runde {roundNumber} nicht gefunden.");
        }

        var audit = round.Audit with
        {
            Messages = round.Audit.Messages
                .Concat(new[] { $"Manuelle Paarungsänderung in Runde {roundNumber}, Brett {boardNumber}." })
                .ToList()
        };
        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings, Audit = audit });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
    }

    public TournamentRound SetRoundLock(Guid tournamentId, int roundNumber, bool isLocked)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        var audit = round.Audit with
        {
            Messages = round.Audit.Messages
                .Concat(new[] { isLocked ? $"Runde {roundNumber} wurde gesperrt." : $"Runde {roundNumber} wurde entsperrt." })
                .ToList()
        };
        var updated = WithCalculatedStatus(round with
        {
            IsLocked = isLocked,
            LockedAt = isLocked ? DateTimeOffset.UtcNow : null,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
    }

    public TournamentRound SetRoundVerified(Guid tournamentId, int roundNumber, bool isVerified)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];

        if (isVerified && !IsRoundComplete(round))
        {
            throw new InvalidOperationException($"Runde {roundNumber} kann erst geprüft werden, wenn alle Ergebnisse eingetragen sind.");
        }

        var audit = round.Audit with
        {
            Messages = round.Audit.Messages
                .Concat(new[] { isVerified ? $"Runde {roundNumber} wurde als geprüft markiert." : $"Runde {roundNumber} wurde als ungeprüft markiert." })
                .ToList()
        };
        var updated = WithCalculatedStatus(round with
        {
            IsVerified = isVerified,
            VerifiedAt = isVerified ? DateTimeOffset.UtcNow : null,
            IsLocked = isVerified || round.IsLocked,
            LockedAt = isVerified ? (round.LockedAt ?? DateTimeOffset.UtcNow) : round.LockedAt,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
    }

    public IReadOnlyList<StandingRow> GetStandings(Guid tournamentId)
    {
        return _standings.Calculate(RequireTournament(tournamentId));
    }

    public CrossTable GetCrossTable(Guid tournamentId)
    {
        return _crossTable.Calculate(RequireTournament(tournamentId));
    }

    public IReadOnlyList<CategoryStandingTable> GetCategoryStandings(Guid tournamentId)
    {
        return _categoryStandings.Calculate(RequireTournament(tournamentId));
    }

    public IReadOnlyList<HeroCupRow> GetHeroCup(Guid tournamentId)
    {
        return _heroCup.Calculate(RequireTournament(tournamentId));
    }


    public ExportDocument ExportStandingsCsv(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportStandingsCsv(tournament, _standings.Calculate(tournament));
    }

    public ExportDocument ExportPairingsCsv(Guid tournamentId, int? roundNumber = null)
    {
        return _exports.ExportPairingsCsv(RequireTournament(tournamentId), roundNumber);
    }

    public ExportDocument ExportPrintableTournamentHtml(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportPrintableTournamentHtml(
            tournament,
            _standings.Calculate(tournament),
            _roundDiagnostics.Calculate(tournament));
    }

    public ExportDocument ExportPrintableRoundHtml(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        return _exports.ExportPrintableRoundHtml(tournament, round, _roundDiagnostics.Calculate(tournament, round));
    }

    public IReadOnlyList<PairingAudit> GetAudit(Guid tournamentId)
    {
        return RequireTournament(tournamentId).Rounds.Select(r => r.Audit).ToList();
    }

    public IReadOnlyList<RoundDiagnostics> GetRoundDiagnostics(Guid tournamentId)
    {
        return _roundDiagnostics.Calculate(RequireTournament(tournamentId));
    }

    public RoundDiagnostics GetRoundDiagnostics(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        return _roundDiagnostics.Calculate(tournament, tournament.Rounds[roundIndex]);
    }

    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private static TournamentSettings NormalizeSettings(TournamentSettings settings)
    {
        var tiebreaks = settings.Tiebreaks
            .Where(tiebreak => Enum.IsDefined(tiebreak))
            .Distinct()
            .ToList();

        if (tiebreaks.Count == 0)
        {
            tiebreaks.Add(TiebreakType.StartingRank);
        }

        if (!tiebreaks.Contains(TiebreakType.StartingRank))
        {
            tiebreaks.Add(TiebreakType.StartingRank);
        }

        return settings with
        {
            PlannedRounds = Math.Max(1, settings.PlannedRounds),
            HeroCupMinimumRatedGames = Math.Max(1, settings.HeroCupMinimumRatedGames),
            SeniorBirthYearOrEarlier = settings.SeniorBirthYearOrEarlier is <= 0 ? null : settings.SeniorBirthYearOrEarlier,
            Tiebreaks = tiebreaks
        };
    }

    private static int RequireRoundIndex(TournamentState tournament, int roundNumber)
    {
        var index = tournament.Rounds.FindIndex(r => r.RoundNumber == roundNumber);
        if (index < 0)
        {
            throw new InvalidOperationException($"Runde {roundNumber} wurde nicht gefunden.");
        }

        return index;
    }

    private static void EnsureRoundEditable(TournamentRound round)
    {
        if (round.IsLocked || round.IsVerified)
        {
            throw new InvalidOperationException($"Runde {round.RoundNumber} ist gesperrt oder geprüft und kann nicht mehr geändert werden.");
        }
    }

    private static void EnsurePreviousRoundComplete(TournamentState tournament)
    {
        var latestRound = tournament.Rounds.OrderByDescending(r => r.RoundNumber).FirstOrDefault();
        if (latestRound is not null && !IsRoundComplete(latestRound))
        {
            throw new InvalidOperationException($"Runde {latestRound.RoundNumber} hat noch offene Ergebnisse. Bitte erst abschließen oder korrigieren.");
        }
    }

    private static bool IsRoundComplete(TournamentRound round)
    {
        return round.Pairings.Count > 0 && round.Pairings.All(pairing => pairing.IsBye || pairing.Result.Kind != GameResultKind.NotPlayed);
    }

    private static TournamentRound WithCalculatedStatus(TournamentRound round)
    {
        var status = round.IsVerified
            ? RoundResultStatus.Verified
            : round.IsLocked
                ? RoundResultStatus.Locked
                : IsRoundComplete(round)
                    ? RoundResultStatus.Complete
                    : RoundResultStatus.Open;

        return round with { ResultStatus = status };
    }

    private static bool PlayerAppearsInPairing(Pairing pairing, Guid? whitePlayerId)
    {
        return whitePlayerId is not null && (pairing.WhitePlayerId == whitePlayerId || pairing.BlackPlayerId == whitePlayerId);
    }

    private static void ValidatePlayerCanBePaired(TournamentState tournament, Guid? playerId, string argumentName)
    {
        if (playerId is null)
        {
            return;
        }

        var player = tournament.Players.FirstOrDefault(p => p.Id == playerId);
        if (player is null)
        {
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden ({argumentName}).");
        }

        if (!player.IsActive)
        {
            throw new InvalidOperationException($"Spieler {player.Name} ist nicht aktiv und kann nicht gepaart werden.");
        }
    }

    private TournamentRound GetNextRoundRobinRound(TournamentState tournament)
    {
        var all = _roundRobin.GenerateAllRounds(tournament.Players.Where(p => p.IsActive).ToList(), tournament.Settings.TwzSource);
        if (tournament.Rounds.Count >= all.Count)
        {
            throw new InvalidOperationException("Alle Rundenturnier-Runden wurden bereits erzeugt.");
        }

        return all[tournament.Rounds.Count];
    }

    private static Player NormalizePlayerForSave(TournamentState tournament, Player player, bool preserveExistingRank)
    {
        if (string.IsNullOrWhiteSpace(player.Name))
        {
            throw new ArgumentException("Spielername ist Pflicht.", nameof(player));
        }

        var startingRank = player.StartingRank;
        if (startingRank <= 0 && !preserveExistingRank)
        {
            startingRank = tournament.Players.Count + 1;
        }

        return player with
        {
            Name = player.Name.Trim(),
            Club = string.IsNullOrWhiteSpace(player.Club) ? null : player.Club.Trim(),
            Federation = string.IsNullOrWhiteSpace(player.Federation) ? null : player.Federation.Trim(),
            Country = string.IsNullOrWhiteSpace(player.Country) ? null : player.Country.Trim(),
            FideId = string.IsNullOrWhiteSpace(player.FideId) ? null : player.FideId.Trim(),
            NationalId = string.IsNullOrWhiteSpace(player.NationalId) ? null : player.NationalId.Trim(),
            Title = string.IsNullOrWhiteSpace(player.Title) ? null : player.Title.Trim(),
            Notes = string.IsNullOrWhiteSpace(player.Notes) ? null : player.Notes.Trim(),
            StartingRank = startingRank <= 0 ? tournament.Players.Count + 1 : startingRank
        };
    }

    private static void EnsureUniquePlayerName(TournamentState tournament, string name, Guid ownId)
    {
        if (tournament.Players.Any(p => p.Id != ownId && string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase)))
        {
            throw new InvalidOperationException($"Ein Spieler mit dem Namen '{name}' existiert bereits in diesem Turnier.");
        }
    }

    private static void EnsureUniquePlayerNames(TournamentState tournament)
    {
        var duplicate = tournament.Players
            .GroupBy(player => player.Name.Trim(), StringComparer.OrdinalIgnoreCase)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicate is not null)
        {
            throw new InvalidOperationException($"Der Spielername '{duplicate.Key}' kommt mehrfach vor.");
        }
    }

    private static string AppendNote(string? existing, string note)
    {
        return string.IsNullOrWhiteSpace(existing) ? note : existing.Trim() + Environment.NewLine + note;
    }
}

