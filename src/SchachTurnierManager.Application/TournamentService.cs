using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Application;

public sealed class TournamentService(ITournamentStore store, IAuditJournalSink? auditSink = null)
{
    private readonly ITournamentStore _store = store;
    private readonly IAuditJournalSink? _auditSink = auditSink;
    private readonly RoundRobinPairingEngine _roundRobin = new();
    private readonly SwissPairingEngine _swiss = new();
    private readonly StandingsCalculator _standings = new();
    private readonly CrossTableCalculator _crossTable = new();
    private readonly CategoryStandingsCalculator _categoryStandings = new();
    private readonly HeroCupCalculator _heroCup = new();
    private readonly RoundDiagnosticsCalculator _roundDiagnostics = new();
    private readonly PairingQualityAnalyzer _pairingQuality = new();
    private readonly TournamentExportFormatter _exports = new();
    private readonly ExternalPlayerImportService _externalPlayerImport = new();
    private readonly PlayerImportPreviewService _playerImportPreview = new();
    private readonly Chess960PositionService _chess960 = new();
    private readonly PairingForensicsBuilder _forensics = new();
    private readonly AuditForensicExportBuilder _auditExport = new();

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
        AddAuditEntry(tournament, AuditJournalAction.TournamentCreated, AuditJournalSeverity.Info, "Turnier angelegt.", $"Name: {tournament.Name}");
        _store.Save(tournament);
        return tournament;
    }


    public bool DeleteTournament(Guid tournamentId)
    {
        var tournament = _store.Get(tournamentId);
        if (tournament is null)
        {
            return false;
        }

        // Den Löschvorgang noch festhalten, bevor das Turnier verschwindet. Der append-only
        // Audit-Spiegel (Datei) behält den Eintrag dauerhaft, auch nachdem die DB-Zeile weg ist.
        AddAuditEntry(
            tournament,
            AuditJournalAction.TournamentDeleted,
            AuditJournalSeverity.Critical,
            $"Turnier gelöscht: {tournament.Name}.",
            $"Runden: {tournament.Rounds.Count}, Spieler: {tournament.Players.Count}, Audit-Einträge: {tournament.AuditJournal.Count}.");
        _store.Save(tournament);
        return _store.Delete(tournamentId);
    }

    public TournamentState ResetTournament(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var removedRoundCount = tournament.Rounds.Count;
        var removedAuditEntryCount = tournament.AuditJournal.RemoveAll(IsRoundRelatedAuditEntry);
        tournament.Rounds.Clear();
        AddAuditEntry(
            tournament,
            AuditJournalAction.TournamentReset,
            AuditJournalSeverity.Warning,
            "Turnier auf Start zurückgesetzt.",
            $"Alle Runden, Ergebnisse, rundenbezogenen Audit-Einträge und Chess960-Startstellungen wurden entfernt. Entfernte Runden: {removedRoundCount}, entfernte Audit-Einträge: {removedAuditEntryCount}.");
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
        AddAuditEntry(tournament, AuditJournalAction.SettingsUpdated, AuditJournalSeverity.Info, "Turniereinstellungen aktualisiert.", $"Format: {normalized.Format}, Runden: {normalized.PlannedRounds}");
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
        AddAuditEntry(tournament, AuditJournalAction.TournamentImported, AuditJournalSeverity.Warning, "Turnier importiert.", $"OverwriteExisting: {overwriteExisting}");
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
            EnsureUniqueExternalIds(tournament, normalized.FideId, normalized.NationalId, normalized.Id);
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

        AddAuditEntry(tournament, AuditJournalAction.ExternalPlayerApplied, AuditJournalSeverity.Info, $"Externe Spielerdaten übernommen: {result.Player.Name}.", null, playerId: result.Player.Id, playerName: result.Player.Name);
        _store.Save(tournament);
        return result;
    }

    public Player AddPlayer(Guid tournamentId, Player player)
    {
        var tournament = RequireTournament(tournamentId);
        var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
        EnsureUniqueExternalIds(tournament, normalized.FideId, normalized.NationalId, normalized.Id);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players.Add(normalized);
        AddAuditEntry(tournament, AuditJournalAction.PlayerAdded, AuditJournalSeverity.Info, $"Spieler hinzugefügt: {normalized.Name}.", null, playerId: normalized.Id, playerName: normalized.Name);
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

            // Dedupe statt Abbruch: gleiche FIDE-/DSB-ID nicht doppelt importieren.
            // Gleiche Namen ohne ID werden ebenfalls übersprungen (gewarnt, nicht blind gelöscht).
            if (HasExternalIdClash(tournament, normalized.FideId, normalized.NationalId, normalized.Id)
                || tournament.Players.Any(existing => existing.Id != normalized.Id
                    && string.Equals(existing.Name, normalized.Name, StringComparison.OrdinalIgnoreCase)))
            {
                continue;
            }

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
        EnsureUniqueExternalIds(tournament, normalized.FideId, normalized.NationalId, normalized.Id);
        EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
        tournament.Players[index] = normalized;
        AddAuditEntry(tournament, AuditJournalAction.PlayerUpdated, AuditJournalSeverity.Info, $"Spieler aktualisiert: {normalized.Name}.", null, playerId: normalized.Id, playerName: normalized.Name);
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
        AddAuditEntry(tournament, AuditJournalAction.PlayerStatusChanged, AuditJournalSeverity.Warning, $"Spielerstatus geändert: {existing.Name} -> {status}.", null, playerId: existing.Id, playerName: existing.Name);
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
            AddAuditEntry(tournament, AuditJournalAction.PlayerRemoved, AuditJournalSeverity.Warning, $"Spieler entfernt: {existing.Name}.", "Spieler hatte noch keine Paarungen.", playerId: existing.Id, playerName: existing.Name);
            _store.Save(tournament);
            return existing;
        }

        var withdrawn = existing with
        {
            Status = PlayerStatus.Withdrawn,
            Notes = AppendNote(existing.Notes, "Automatisch zurückgezogen statt gelöscht, weil bereits Paarungen existieren.")
        };
        tournament.Players[index] = withdrawn;
        AddAuditEntry(tournament, AuditJournalAction.PlayerWithdrawn, AuditJournalSeverity.Warning, $"Spieler zurückgezogen: {withdrawn.Name}.", "Entfernen war nicht möglich, weil bereits Paarungen existieren.", playerId: withdrawn.Id, playerName: withdrawn.Name);
        _store.Save(tournament);
        return withdrawn;
    }

    public NextRoundPreview PreviewNextRound(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        NextRoundPreview preview;
        try
        {
            preview = BuildNextRoundPreview(tournament, "preview");
        }
        catch (InvalidOperationException ex)
        {
            AuditBlockedPairingAttempt(tournament, "Runde-Vorschau blockiert.", ex.Message);
            throw;
        }

        // Die Vorschau selbst wird nicht als Runde gespeichert; dass eine Vorschau erzeugt wurde,
        // inklusive Forensik-Kennzahlen, gehört aber ins Audit-Journal.
        AddAuditEntry(
            tournament,
            AuditJournalAction.RoundPreviewGenerated,
            AuditJournalSeverity.Info,
            $"Runde-Vorschau erzeugt: Runde {preview.RoundNumber}.",
            preview.Round.Forensics?.ToSummaryLine(),
            roundNumber: preview.RoundNumber);
        _store.Save(tournament);
        return preview;
    }

    private NextRoundPreview BuildNextRoundPreview(TournamentState tournament, string trigger)
    {
        EnsureCanCreateNextRound(tournament);

        TournamentRound previewRound = tournament.Settings.Format switch
        {
            TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament),
            TournamentFormat.Swiss => _swiss.GenerateNextRound(tournament),
            _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
        };

        var quality = _pairingQuality.Analyze(tournament, previewRound);
        previewRound = previewRound with { Forensics = _forensics.Build(tournament, previewRound, trigger) };
        var messages = new List<string>
        {
            $"Vorschau für Runde {previewRound.RoundNumber}: {previewRound.Pairings.Count} Brett(er), Qualitätswert {quality.QualityScore}/100, Status {quality.Severity}.",
            "Diese Vorschau wurde nicht gespeichert. Erst 'Nächste Runde auslosen' übernimmt die Paarungen ins Turnier."
        };
        messages.AddRange(quality.Findings);

        return new NextRoundPreview
        {
            RoundNumber = previewRound.RoundNumber,
            BoardCount = previewRound.Pairings.Count,
            IsSavable = true,
            Summary = $"Runde {previewRound.RoundNumber}: {previewRound.Pairings.Count} Brett(er), Qualität {quality.QualityScore}/100 ({quality.Severity}).",
            Round = previewRound,
            PairingQuality = quality,
            Messages = messages
        };
    }
    public ExportDocument ExportNextRoundPreviewCsv(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var preview = BuildNextRoundPreview(tournament, "preview-export");
        return _exports.ExportNextRoundPreviewCsv(tournament, preview);
    }

    public ExportDocument ExportPrintableNextRoundPreviewHtml(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var preview = BuildNextRoundPreview(tournament, "preview-export");
        return _exports.ExportPrintableNextRoundPreviewHtml(tournament, preview);
    }

    public TournamentRound GenerateNextRound(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);

        TournamentRound nextRound;
        try
        {
            EnsureCanCreateNextRound(tournament);
            nextRound = tournament.Settings.Format switch
            {
                TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament),
                TournamentFormat.Swiss => _swiss.GenerateNextRound(tournament),
                _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
            };
        }
        catch (InvalidOperationException ex)
        {
            // Blockierte Auslosungen (Rundenlimit, Round-Robin-Roster-Sperre, offene Vorrunde,
            // zu wenige Spieler) forensisch festhalten, dann den ursprünglichen Fehler weiterreichen.
            AuditBlockedPairingAttempt(tournament, "Auslosung blockiert.", ex.Message);
            throw;
        }

        // Forensik aus dem Stand VOR Hinzufügen der neuen Runde (prior rounds = bisherige Runden).
        var forensics = _forensics.Build(tournament, nextRound, "generated");
        nextRound = WithPairingQualityAudit(tournament, nextRound) with { Forensics = forensics };

        tournament.Rounds.Add(nextRound);
        AddAuditEntry(
            tournament,
            AuditJournalAction.RoundGenerated,
            AuditJournalSeverity.Info,
            $"Runde {nextRound.RoundNumber} ausgelost.",
            $"{nextRound.Pairings.Count} Brett(er). {forensics.ToSummaryLine()}",
            roundNumber: nextRound.RoundNumber);
        _store.Save(tournament);
        return nextRound;
    }

    public TournamentRound RollChess960StartPositions(Guid tournamentId, int roundNumber, bool overwriteExisting, int? seed = null)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        if (round.IsLocked || round.IsVerified)
        {
            throw new InvalidOperationException($"Runde {roundNumber} ist gesperrt oder geprüft. Startstellungen können nicht mehr geändert werden.");
        }

        var existingCount = round.Pairings.Count(pairing => pairing.Chess960StartPosition is not null);
        if (existingCount > 0 && !overwriteExisting)
        {
            throw new InvalidOperationException("Für diese Runde existieren bereits Chess960-Startstellungen. Zum Überschreiben muss overwriteExisting=true gesetzt werden.");
        }

        var baseSeed = seed ?? Random.Shared.Next(1, int.MaxValue);
        var generatedCount = 0;
        var updatedPairings = round.Pairings
            .OrderBy(pairing => pairing.BoardNumber)
            .Select(pairing =>
            {
                if (pairing.IsBye)
                {
                    return overwriteExisting ? pairing with { Chess960StartPosition = null } : pairing;
                }

                generatedCount++;
                var boardSeed = DeriveChess960Seed(baseSeed, roundNumber, pairing.BoardNumber);
                return pairing with
                {
                    Chess960StartPosition = _chess960.GenerateRandomPosition(boardSeed),
                    Notes = AppendNote(pairing.Notes, $"Chess960-Startstellung gewürfelt: Seed {boardSeed}.")
                };
            })
            .ToList();

        if (generatedCount == 0)
        {
            throw new InvalidOperationException($"Runde {roundNumber} enthält kein reguläres Brett für eine Chess960-Startstellung.");
        }

        var audit = round.Audit with
        {
            Messages = round.Audit.Messages
                .Concat(new[]
                {
                    $"Chess960-Startstellungen für Runde {roundNumber} gewürfelt: {generatedCount} Brett(er), Basis-Seed {baseSeed}, Überschreiben: {(overwriteExisting ? "ja" : "nein")}."
                })
                .ToList()
        };
        var updated = round with { Pairings = updatedPairings, Audit = audit };
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(
            tournament,
            AuditJournalAction.Chess960StartPositionsRolled,
            overwriteExisting && existingCount > 0 ? AuditJournalSeverity.Warning : AuditJournalSeverity.Info,
            $"Chess960-Startstellungen gewürfelt: Runde {roundNumber}.",
            $"Bretter: {generatedCount}, Basis-Seed: {baseSeed}, vorhandene überschrieben: {(overwriteExisting && existingCount > 0 ? "ja" : "nein")}.",
            roundNumber: roundNumber);
        _store.Save(tournament);
        return updated;
    }

    public TournamentRound RollChess960StartPositionForBoard(
        Guid tournamentId,
        int roundNumber,
        int boardNumber,
        bool overwriteExisting,
        int? seed = null,
        int? positionNumber = null)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        var round = tournament.Rounds[roundIndex];
        if (round.IsLocked || round.IsVerified)
        {
            throw new InvalidOperationException($"Runde {roundNumber} ist gesperrt oder geprüft. Startstellungen können nicht mehr geändert werden.");
        }

        var pairing = round.Pairings.FirstOrDefault(item => item.BoardNumber == boardNumber);
        if (pairing is null)
        {
            throw new InvalidOperationException($"Brett {boardNumber} existiert in Runde {roundNumber} nicht.");
        }

        if (pairing.IsBye)
        {
            throw new InvalidOperationException($"Brett {boardNumber} ist spielfrei und erhält keine Chess960-Startstellung.");
        }

        var hadExisting = pairing.Chess960StartPosition is not null;
        if (hadExisting && !overwriteExisting)
        {
            throw new InvalidOperationException($"Für Brett {boardNumber} existiert bereits eine Chess960-Startstellung. Zum Überschreiben muss overwriteExisting=true gesetzt werden.");
        }

        Chess960StartPosition position;
        int? appliedSeed = null;
        if (positionNumber.HasValue)
        {
            // Vom Browser/Handy vorab gewürfelte Stellung exakt übernehmen – der Service validiert den Bereich.
            position = _chess960.FromPositionNumber(positionNumber.Value);
        }
        else
        {
            var baseSeed = seed ?? Random.Shared.Next(1, int.MaxValue);
            appliedSeed = DeriveChess960Seed(baseSeed, roundNumber, boardNumber);
            position = _chess960.GenerateRandomPosition(appliedSeed);
        }

        var noteDetail = positionNumber.HasValue
            ? $"Chess960-Startstellung für Brett {boardNumber} gesetzt: SP {position.PositionNumber}."
            : $"Chess960-Startstellung für Brett {boardNumber} gewürfelt: Seed {appliedSeed}.";

        var updatedPairings = round.Pairings
            .Select(item => item.BoardNumber == boardNumber
                ? item with { Chess960StartPosition = position, Notes = AppendNote(item.Notes, noteDetail) }
                : item)
            .ToList();

        var audit = round.Audit with
        {
            Messages = round.Audit.Messages
                .Concat(new[] { $"{noteDetail} Vorhandene überschrieben: {(hadExisting ? "ja" : "nein")}." })
                .ToList()
        };
        var updated = round with { Pairings = updatedPairings, Audit = audit };
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(
            tournament,
            AuditJournalAction.Chess960StartPositionsRolled,
            hadExisting ? AuditJournalSeverity.Warning : AuditJournalSeverity.Info,
            $"Chess960-Startstellung gewürfelt: Runde {roundNumber}, Brett {boardNumber}.",
            $"SP {position.PositionNumber}{(appliedSeed.HasValue ? $", Seed {appliedSeed}" : string.Empty)}, vorhandene überschrieben: {(hadExisting ? "ja" : "nein")}.",
            roundNumber: roundNumber,
            boardNumber: boardNumber);
        _store.Save(tournament);
        return updated;
    }

    private TournamentRound WithPairingQualityAudit(TournamentState tournament, TournamentRound round)
    {
        var quality = _pairingQuality.Analyze(tournament, round);
        var qualityMessages = new List<string>
        {
            $"Paarungsqualität: {quality.QualityScore}/100 ({PairingQualitySeverityLabel(quality.Severity)}). Rematches: {quality.RematchCount}, Scoregruppenabweichungen: {quality.CrossScoreGroupPairingCount}, Farbfolgenrisiken: {quality.ThirdSameColorRiskCount}, Byes: {quality.ByeCount}."
        };

        qualityMessages.AddRange(quality.Findings.Select(finding => $"Qualitätsprüfung: {finding}"));
        qualityMessages.AddRange(quality.Boards
            .SelectMany(board => board.Findings.Select(finding => $"Qualitätsprüfung Brett {board.BoardNumber}: {finding}")));

        return round with
        {
            Audit = round.Audit with
            {
                Messages = round.Audit.Messages
                    .Concat(qualityMessages)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList()
            }
        };
    }

    private static string PairingQualitySeverityLabel(PairingQualitySeverity severity)
    {
        return severity switch
        {
            PairingQualitySeverity.Critical => "kritisch",
            PairingQualitySeverity.Warning => "Warnung",
            PairingQualitySeverity.Notice => "Hinweis",
            _ => "gut"
        };
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
        AddAuditEntry(tournament, AuditJournalAction.ResultRecorded, AuditJournalSeverity.Info, $"Ergebnis eingetragen: Runde {roundNumber}, Brett {boardNumber}.", resultKind.ToString(), roundNumber: roundNumber, boardNumber: boardNumber);
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
        AddAuditEntry(tournament, AuditJournalAction.PairingOverridden, AuditJournalSeverity.Warning, $"Paarung manuell geändert: Runde {roundNumber}, Brett {boardNumber}.", normalizedNotes, roundNumber: roundNumber, boardNumber: boardNumber, reason: normalizedNotes);
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
        AddAuditEntry(tournament, isLocked ? AuditJournalAction.RoundLocked : AuditJournalAction.RoundUnlocked, AuditJournalSeverity.Warning, isLocked ? $"Runde {roundNumber} gesperrt." : $"Runde {roundNumber} entsperrt.", null, roundNumber: roundNumber);
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
        AddAuditEntry(tournament, isVerified ? AuditJournalAction.RoundVerified : AuditJournalAction.RoundUnverified, AuditJournalSeverity.Warning, isVerified ? $"Runde {roundNumber} geprüft." : $"Runde {roundNumber} als ungeprüft markiert.", null, roundNumber: roundNumber);
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



    public ExportDocument ExportDownloadManifestJson(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportDownloadManifestJson(tournament, _standings.Calculate(tournament));
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

    public IReadOnlyList<AuditJournalEntry> GetAuditJournal(Guid tournamentId)
    {
        return RequireTournament(tournamentId).AuditJournal
            .OrderByDescending(entry => entry.CreatedAt)
            .ThenByDescending(entry => entry.Id)
            .ToList();
    }

    public ExportDocument ExportAuditJournalJsonl(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var document = _auditExport.BuildJsonl(tournament);
        RecordAuditExport(tournament, document.FileName, "jsonl");
        return document;
    }

    public ExportDocument ExportAuditJournalJson(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var document = _auditExport.BuildJson(tournament);
        RecordAuditExport(tournament, document.FileName, "json");
        return document;
    }

    private void RecordAuditExport(TournamentState tournament, string fileName, string format)
    {
        // Das exportierte Bundle wird vor diesem Eintrag erzeugt; der Export-Vorgang selbst ist
        // ein eigenes, forensisch relevantes Ereignis ("welcher Snapshot wurde wann gezogen").
        AddAuditEntry(
            tournament,
            AuditJournalAction.AuditJournalExported,
            AuditJournalSeverity.Info,
            $"Audit-Bundle exportiert ({format}).",
            $"Datei: {fileName}, Einträge: {tournament.AuditJournal.Count}.");
        _store.Save(tournament);
    }

    private void AuditBlockedPairingAttempt(TournamentState tournament, string summary, string reason)
    {
        AddAuditEntry(
            tournament,
            AuditJournalAction.PairingGenerationBlocked,
            AuditJournalSeverity.Warning,
            summary,
            reason,
            reason: reason);
        try
        {
            _store.Save(tournament);
        }
        catch
        {
            // Der Blockierungs-Audit darf den ursprünglichen Auslösefehler nie verschlucken oder
            // durch einen Speicherfehler ersetzen. Der Aufrufer wirft die Ursache ohnehin weiter.
        }
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

    public PairingQualityReport GetPairingQuality(Guid tournamentId, int roundNumber)
    {
        var tournament = RequireTournament(tournamentId);
        var roundIndex = RequireRoundIndex(tournament, roundNumber);
        return _pairingQuality.Analyze(tournament, tournament.Rounds[roundIndex]);
    }

    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private void AddAuditEntry(
        TournamentState tournament,
        AuditJournalAction action,
        AuditJournalSeverity severity,
        string summary,
        string? details = null,
        int? roundNumber = null,
        int? boardNumber = null,
        Guid? playerId = null,
        string? playerName = null,
        string? reason = null)
    {
        var entry = new AuditJournalEntry
        {
            Action = action,
            Severity = severity,
            Summary = summary,
            Details = string.IsNullOrWhiteSpace(details) ? null : details.Trim(),
            Reason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim(),
            RoundNumber = roundNumber,
            BoardNumber = boardNumber,
            PlayerId = playerId,
            PlayerName = string.IsNullOrWhiteSpace(playerName) ? null : playerName.Trim()
        };
        tournament.AuditJournal.Add(entry);
        MirrorAuditEntry(tournament, entry);
    }

    private void MirrorAuditEntry(TournamentState tournament, AuditJournalEntry entry)
    {
        if (_auditSink is null)
        {
            return;
        }

        try
        {
            _auditSink.Append(tournament.Id, tournament.Name, entry);
        }
        catch (Exception ex)
        {
            // Ein Schreibfehler im append-only Spiegel darf den Turnierschritt nie abbrechen.
            // Stattdessen eine Warnung ins (in der DB persistierte) Journal schreiben, damit UI/API
            // den Fehler sichtbar machen. Nicht erneut spiegeln, sonst Endlosschleife bei Dauerfehler.
            if (entry.Action != AuditJournalAction.AuditJournalMirrorFailed)
            {
                tournament.AuditJournal.Add(new AuditJournalEntry
                {
                    Action = AuditJournalAction.AuditJournalMirrorFailed,
                    Severity = AuditJournalSeverity.Warning,
                    Actor = "System",
                    Summary = "Audit-Spiegel konnte nicht geschrieben werden.",
                    Details = ex.Message
                });
            }
        }
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

    private static void EnsureCanCreateNextRound(TournamentState tournament)
    {
        if (tournament.Players.Count(p => p.IsActive) < 2)
        {
            throw new InvalidOperationException("Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.");
        }

        if (tournament.Rounds.Count >= tournament.Settings.PlannedRounds)
        {
            throw new InvalidOperationException($"Die geplante maximale Rundenzahl ({tournament.Settings.PlannedRounds}) ist bereits erreicht.");
        }

        EnsurePreviousRoundComplete(tournament);
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
        var activePlayers = tournament.Players.Where(p => p.IsActive).ToList();

        // Jeder-gegen-jeden fixiert den kompletten Spielplan beim Start (Runde 1). Würde sich der
        // aktive Teilnehmerkreis danach ändern, berechnet die Circle-Methode den Plan still neu und
        // macht bereits gespielte Runden inkonsistent (falsche Farben, Rematches, falsche Byes,
        // andere Rundenanzahl). Deshalb harte Sperre statt rückwirkender Stillschweigen-Änderung.
        if (tournament.Rounds.Count > 0)
        {
            var scheduledParticipants = tournament.Rounds
                .SelectMany(round => round.Pairings)
                .SelectMany(pairing => new[] { pairing.WhitePlayerId, pairing.BlackPlayerId })
                .Where(id => id is not null)
                .Select(id => id!.Value)
                .ToHashSet();
            var currentActive = activePlayers.Select(p => p.Id).ToHashSet();

            if (!currentActive.SetEquals(scheduledParticipants))
            {
                var added = currentActive.Except(scheduledParticipants).Count();
                var removed = scheduledParticipants.Except(currentActive).Count();
                throw new InvalidOperationException(
                    "Im Jeder-gegen-jeden ist der Spielplan ab Runde 1 fixiert. " +
                    $"Der aktive Teilnehmerkreis hat sich seit dem Start geändert (zusätzlich aktiv: {added}, nicht mehr aktiv: {removed}). " +
                    "Ein nachträglicher Spieler oder Rückzug erfordert eine bewusste Neuplanung (Turnier zurücksetzen oder neu anlegen), " +
                    "damit bereits gespielte Runden nicht rückwirkend verändert werden.");
            }
        }

        var all = _roundRobin.GenerateAllRounds(activePlayers, tournament.Settings.TwzSource);
        if (tournament.Rounds.Count >= all.Count)
        {
            throw new InvalidOperationException("Alle Runden des Jeder-gegen-jeden-Turniers wurden bereits erzeugt.");
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

    private static void EnsureUniqueExternalIds(TournamentState tournament, string? fideId, string? nationalId, Guid ownId)
    {
        var normalizedFide = NormalizeExternalId(fideId);
        if (normalizedFide is not null)
        {
            var clash = tournament.Players.FirstOrDefault(p => p.Id != ownId && NormalizeExternalId(p.FideId) == normalizedFide);
            if (clash is not null)
            {
                throw new InvalidOperationException(
                    $"Ein Teilnehmer mit FIDE-ID {fideId} ist bereits im Turnier vorhanden: {clash.Name}. Bitte den vorhandenen Teilnehmer bearbeiten statt eine Dublette anzulegen.");
            }
        }

        var normalizedNational = NormalizeExternalId(nationalId);
        if (normalizedNational is not null)
        {
            var clash = tournament.Players.FirstOrDefault(p => p.Id != ownId && NormalizeExternalId(p.NationalId) == normalizedNational);
            if (clash is not null)
            {
                throw new InvalidOperationException(
                    $"Ein Teilnehmer mit DSB-ID {nationalId} ist bereits im Turnier vorhanden: {clash.Name}. Bitte den vorhandenen Teilnehmer bearbeiten statt eine Dublette anzulegen.");
            }
        }
    }

    private static bool HasExternalIdClash(TournamentState tournament, string? fideId, string? nationalId, Guid ownId)
    {
        var normalizedFide = NormalizeExternalId(fideId);
        var normalizedNational = NormalizeExternalId(nationalId);
        return tournament.Players.Any(p => p.Id != ownId
            && ((normalizedFide is not null && NormalizeExternalId(p.FideId) == normalizedFide)
                || (normalizedNational is not null && NormalizeExternalId(p.NationalId) == normalizedNational)));
    }

    private static string? NormalizeExternalId(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = new string(value.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray());
        return normalized.Length == 0 ? null : normalized;
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

    private static bool IsRoundRelatedAuditEntry(AuditJournalEntry entry)
    {
        return entry.RoundNumber is not null
               || entry.BoardNumber is not null
               || entry.Action is AuditJournalAction.RoundGenerated
                   or AuditJournalAction.ResultRecorded
                   or AuditJournalAction.PairingOverridden
                   or AuditJournalAction.RoundLocked
                   or AuditJournalAction.RoundUnlocked
                   or AuditJournalAction.RoundVerified
                   or AuditJournalAction.RoundUnverified
                   or AuditJournalAction.Chess960StartPositionsRolled;
    }

    private static int DeriveChess960Seed(int baseSeed, int roundNumber, int boardNumber)
    {
        unchecked
        {
            var value = 17;
            value = value * 31 + baseSeed;
            value = value * 31 + roundNumber;
            value = value * 31 + boardNumber;
            return value & int.MaxValue;
        }
    }
}
