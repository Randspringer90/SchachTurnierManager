using System.Text.Json;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Domain.Services;

namespace SchachTurnierManager.Application;

public sealed class TournamentService(ITournamentStore store, IAuditJournalSink? auditSink = null)
{
    private readonly ITournamentStore _store = store;
    private readonly IAuditJournalSink? _auditSink = auditSink;
    private readonly RoundRobinPairingEngine _roundRobin = new();
    private readonly SwissPairingEngine _swiss = new();
    private readonly FideDutchPairingStrategy _fideDutch = new();
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

    public IReadOnlyList<TournamentSummary> ListTournamentSummaries() => _store.ListSummaries();

    public TournamentState CreateTournament(string name, TournamentSettings? settings = null)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Turniername darf nicht leer sein.", nameof(name))
                .WithErrorCode("TOURNAMENT_NAME_REQUIRED");
        }

        var tournament = new TournamentState
        {
            ResultQueueEpoch = Guid.NewGuid(),
            Name = name.Trim(),
            Settings = settings ?? new TournamentSettings()
        };
        AddAuditEntry(tournament, AuditJournalAction.TournamentCreated, AuditJournalSeverity.Info, "Turnier angelegt.", $"Name: {tournament.Name}");
        _store.Save(tournament);
        return tournament;
    }


    public bool DeleteTournament(Guid tournamentId)
    {
        return _store.Delete(tournamentId, tournament => AddAuditEntry(
            tournament, AuditJournalAction.TournamentDeleted, AuditJournalSeverity.Critical,
            $"Turnier gelöscht: {tournament.Name}.",
            $"Runden: {tournament.Rounds.Count}, Spieler: {tournament.Players.Count}, Audit-Einträge: {tournament.AuditJournal.Count}."));
    }

    public TournamentState ResetTournament(Guid tournamentId)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var removedRoundCount = tournament.Rounds.Count;
            var removedAuditEntryCount = tournament.AuditJournal.RemoveAll(IsRoundRelatedAuditEntry);
            tournament.Rounds.Clear();
            tournament.RoundRobinPlan = null;
            tournament.ResultQueueEpoch = Guid.NewGuid();
            tournament.ResultMutationReceipts.Clear();
            AddAuditEntry(
                tournament,
                AuditJournalAction.TournamentReset,
                AuditJournalSeverity.Warning,
                "Turnier auf Start zurückgesetzt.",
                $"Alle Runden, Ergebnisse, rundenbezogenen Audit-Einträge und Chess960-Startstellungen wurden entfernt. Entfernte Runden: {removedRoundCount}, entfernte Audit-Einträge: {removedAuditEntryCount}.");

            return tournament;
        });
    }

    public TournamentState UpdateSettings(Guid tournamentId, TournamentSettings settings)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var normalized = NormalizeSettings(settings);

            if (tournament.Rounds.Count > 0 && normalized.Format != tournament.Settings.Format)
            {
                throw new InvalidOperationException("Das Turnierformat kann nach bereits ausgelosten Runden nicht mehr geändert werden.")
                    .WithErrorCode("TOURNAMENT_FORMAT_LOCKED");
            }

            tournament.Settings = normalized;
            AddAuditEntry(
                tournament,
                AuditJournalAction.SettingsUpdated,
                AuditJournalSeverity.Info,
                "Turniereinstellungen aktualisiert.",
                $"Format: {normalized.Format}, Runden: {normalized.PlannedRounds}, Forfeit-Policy: {normalized.ForfeitTiebreakPolicy}, ungespielte Runden/Buchholz: {normalized.UnplayedRoundBuchholzMode}");

            return tournament;
        });
    }

    public TournamentState SaveImportedTournament(TournamentState tournament, bool overwriteExisting)
    {
        ValidateImportedTournament(tournament);
        // Use the same snapshot serialization contract as InMemoryTournamentStore.
        // Normalization and a refused save must never mutate the caller's backup.
        var imported = JsonSerializer.Deserialize<TournamentState>(JsonSerializer.Serialize(tournament))
            ?? throw new InvalidOperationException("Importierter Turniersnapshot konnte nicht kopiert werden.")
                .WithErrorCode("BACKUP_SNAPSHOT_COPY_FAILED");
        imported.Name = imported.Name.Trim();
        imported.Settings = NormalizeSettings(imported.Settings);
        imported.ResultQueueEpoch = Guid.NewGuid();

        var entry = new AuditJournalEntry
        {
            Action = AuditJournalAction.TournamentImported,
            Severity = AuditJournalSeverity.Warning,
            Summary = "Turnier importiert.",
            Details = $"OverwriteExisting: {overwriteExisting}"
        };
        imported.AuditJournal.Add(entry);
        _store.Save(imported, overwriteExisting);

        var mirrorWarning = MirrorAuditEntry(imported, entry);
        if (mirrorWarning is null)
        {
            return imported;
        }

        try
        {
            return _store.UpdateAtomically(imported.Id, current =>
            {
                // Preserve intervening edits. An entirely replaced snapshot must not
                // receive a warning belonging to an import it no longer contains.
                if (current.AuditJournal.Any(saved => saved.Id == entry.Id))
                {
                    current.AuditJournal.Add(mirrorWarning);
                }
                return current;
            });
        }
        catch (Exception)
        {
            // The import is already committed. A second failure must not report it as
            // rejected or encourage an unsafe retry; disclose the transient warning.
            imported.AuditJournal[^1] = mirrorWarning with
            {
                Summary = "Turnier gespeichert; Audit-Spiegel fehlgeschlagen, Audit-Warnung nicht gespeichert."
            };
            return imported;
        }
    }


    public ExternalPlayerDuplicateCheck CheckExternalPlayerDuplicates(Guid tournamentId, ExternalPlayerProfile profile)
    {
        return _externalPlayerImport.CheckDuplicates(RequireTournament(tournamentId), profile);
    }

    public ExternalPlayerApplyResult ApplyExternalPlayer(Guid tournamentId, ExternalPlayerProfile profile, Guid? targetPlayerId, bool createIfNoTarget, bool overwriteExistingValues, IReadOnlyList<string>? selectedFields = null, Player? expectedPlayer = null)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            if (selectedFields is not null)
            {
                var target = targetPlayerId is null ? null : tournament.Players.SingleOrDefault(player => player.Id == targetPlayerId);
                if (targetPlayerId is not null && target is null) throw new InvalidOperationException("Zielspieler wurde nicht gefunden.")
                    .WithErrorCode("PLAYER_NOT_FOUND");
                if (target is not null && (expectedPlayer is null || target != expectedPlayer)) throw new ExternalPlayerConflictException();
                profile = ExternalPlayerFieldSelection.Prepare(profile, target, selectedFields);
            }
            ExternalPlayerApplyResult result;

            if (targetPlayerId is not null)
            {
                result = _externalPlayerImport.UpdatePlayer(tournament, targetPlayerId.Value, profile, overwriteExistingValues);
                var index = tournament.Players.FindIndex(player => player.Id == targetPlayerId.Value);
                if (index < 0)
                {
                    throw new InvalidOperationException($"Spieler {targetPlayerId} wurde nicht gefunden.")
                        .WithErrorCode("PLAYER_NOT_FOUND");
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
                    throw new InvalidOperationException("Kein Zielspieler angegeben. Wähle einen vorhandenen Teilnehmer oder erlaube das Neuanlegen.")
                        .WithErrorCode("EXTERNAL_PLAYER_TARGET_REQUIRED");
                }

                result = _externalPlayerImport.CreatePlayer(tournament, profile);
                var normalized = NormalizePlayerForSave(tournament, result.Player, preserveExistingRank: false);
                EnsureUniqueExternalIds(tournament, normalized.FideId, normalized.NationalId, normalized.Id);
                EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
                tournament.Players.Add(normalized);
                result = result with { Player = normalized };
            }

            AddAuditEntry(tournament, AuditJournalAction.ExternalPlayerApplied, AuditJournalSeverity.Info, $"Externe Spielerdaten übernommen: {result.Player.Name}. Felder: {string.Join(", ", result.ChangedFields)}.", null, playerId: result.Player.Id, playerName: result.Player.Name);

            return result;
        });
    }

    public Player AddPlayer(Guid tournamentId, Player player)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
            EnsureUniqueExternalIds(tournament, normalized.FideId, normalized.NationalId, normalized.Id);
            EnsureUniquePlayerName(tournament, normalized.Name, normalized.Id);
            tournament.Players.Add(normalized);
            AddAuditEntry(tournament, AuditJournalAction.PlayerAdded, AuditJournalSeverity.Info, $"Spieler hinzugefügt: {normalized.Name}.", null, playerId: normalized.Id, playerName: normalized.Name);

            return normalized;
        });
    }

    public PlayerImportPreview PreviewPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        return _playerImportPreview.Preview(RequireTournament(tournamentId), csv, replaceExisting);
    }
    public IReadOnlyList<Player> ImportPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        return _store.UpdateAtomically<IReadOnlyList<Player>>(tournamentId, tournament =>
        {
            var importedPlayers = PlayerCsvCodec.ImportPlayers(csv);
            if (importedPlayers.Count == 0)
            {
                return Array.Empty<Player>();
            }

            if (replaceExisting)
            {
                if (tournament.Rounds.Count > 0)
                {
                    throw new InvalidOperationException("Teilnehmer können nach ausgelosten Runden nicht vollständig ersetzt werden. Nutze stattdessen Ergänzen oder lege ein neues Turnier an.")
                        .WithErrorCode("PARTICIPANT_REPLACEMENT_LOCKED");
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

            return added;
        });
    }

    /// <summary>
    /// STM-IE-002: Importiert Spieler-Stammdaten aus einer Swiss-Manager-Importlayout-CSV.
    /// <paramref name="fileBytes"/> statt eines bereits dekodierten Strings, damit echte
    /// UTF-8-/Windows-1252-Erkennung moeglich ist (Issue-Anforderung), nicht nur eine vom
    /// Frontend erratene Dekodierung.
    /// </summary>
    public PlayerImportOutcome ImportSwissManagerCsv(Guid tournamentId, byte[] fileBytes, bool replaceExisting)
    {
        var text = ImportTextDecoder.Decode(fileBytes);
        var result = SwissManagerCsvCodec.ImportPlayers(text);
        var added = MergeImportedPlayers(tournamentId, result.Players, replaceExisting);
        return new PlayerImportOutcome(added, result.Errors);
    }

    /// <summary>
    /// STM-IE-002: Importiert Spieler-Stammdaten (keine Turnierlogik/Ergebnisse) aus einer
    /// TRF16-Datei. Siehe <see cref="ImportSwissManagerCsv"/> zur Begruendung von byte[].
    /// </summary>
    public PlayerImportOutcome ImportTrf16Players(Guid tournamentId, byte[] fileBytes, bool replaceExisting)
    {
        var text = ImportTextDecoder.Decode(fileBytes);
        var result = _exports.ImportTrf16Players(text);
        var added = MergeImportedPlayers(tournamentId, result.Players, replaceExisting);
        return new PlayerImportOutcome(added, result.Errors);
    }

    private IReadOnlyList<Player> MergeImportedPlayers(Guid tournamentId, IReadOnlyList<Player> importedPlayers, bool replaceExisting)
    {
        return _store.UpdateAtomically<IReadOnlyList<Player>>(tournamentId, tournament =>
        {
            if (importedPlayers.Count == 0)
            {
                return Array.Empty<Player>();
            }

            if (replaceExisting)
            {
                if (tournament.Rounds.Count > 0)
                {
                    throw new InvalidOperationException("Teilnehmer können nach ausgelosten Runden nicht vollständig ersetzt werden. Nutze stattdessen Ergänzen oder lege ein neues Turnier an.")
                        .WithErrorCode("PARTICIPANT_REPLACEMENT_LOCKED");
                }

                tournament.Players.Clear();
            }

            var added = new List<Player>();
            foreach (var player in importedPlayers)
            {
                var normalized = NormalizePlayerForSave(tournament, player, preserveExistingRank: false);
                if (HasExternalIdClash(tournament, normalized.FideId, normalized.NationalId, normalized.Id)
                    || tournament.Players.Any(existing => existing.Id != normalized.Id
                        && string.Equals(existing.Name, normalized.Name, StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                tournament.Players.Add(normalized);
                added.Add(normalized);
            }

            return added;
        });
    }

    public string ExportPlayersCsv(Guid tournamentId)
    {
        return PlayerCsvCodec.ExportPlayers(RequireTournament(tournamentId).Players);
    }

    public Player UpdatePlayer(Guid tournamentId, Guid playerId, Player player)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var index = tournament.Players.FindIndex(p => p.Id == playerId);
            if (index < 0)
            {
                throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.")
                    .WithErrorCode("PLAYER_NOT_FOUND");
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

            return normalized;
        });
    }

    public Player SetPlayerStatus(Guid tournamentId, Guid playerId, PlayerStatus status)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var index = tournament.Players.FindIndex(p => p.Id == playerId);
            if (index < 0)
            {
                throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.")
                    .WithErrorCode("PLAYER_NOT_FOUND");
            }

            var existing = tournament.Players[index];
            tournament.Players[index] = existing with { Status = status };
            AddAuditEntry(tournament, AuditJournalAction.PlayerStatusChanged, AuditJournalSeverity.Warning, $"Spielerstatus geändert: {existing.Name} -> {status}.", null, playerId: existing.Id, playerName: existing.Name);

            return tournament.Players[index];
        });
    }

    public Player RemovePlayer(Guid tournamentId, Guid playerId)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var index = tournament.Players.FindIndex(p => p.Id == playerId);
            if (index < 0)
            {
                throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden.")
                    .WithErrorCode("PLAYER_NOT_FOUND");
            }

            var existing = tournament.Players[index];
            var hasPairings = tournament.Rounds
                .SelectMany(r => r.Pairings)
                .Any(p => p.WhitePlayerId == playerId || p.BlackPlayerId == playerId);

            if (!hasPairings)
            {
                tournament.Players.RemoveAt(index);
                AddAuditEntry(tournament, AuditJournalAction.PlayerRemoved, AuditJournalSeverity.Warning, $"Spieler entfernt: {existing.Name}.", "Spieler hatte noch keine Paarungen.", playerId: existing.Id, playerName: existing.Name);

                return existing;
            }

            var withdrawn = existing with
            {
                Status = PlayerStatus.Withdrawn,
                Notes = AppendNote(existing.Notes, "Automatisch zurückgezogen statt gelöscht, weil bereits Paarungen existieren.")
            };
            tournament.Players[index] = withdrawn;
            AddAuditEntry(tournament, AuditJournalAction.PlayerWithdrawn, AuditJournalSeverity.Warning, $"Spieler zurückgezogen: {withdrawn.Name}.", "Entfernen war nicht möglich, weil bereits Paarungen existieren.", playerId: withdrawn.Id, playerName: withdrawn.Name);

            return withdrawn;
        });
    }

    public NextRoundPreview PreviewNextRound(Guid tournamentId)
    {
        return UpdatePairingAtomically(tournamentId, "Runde-Vorschau blockiert.", tournament =>
        {
            NextRoundPreview preview;
            preview = BuildNextRoundPreview(tournament, "preview");

            // Die Vorschau selbst wird nicht als Runde gespeichert; dass eine Vorschau erzeugt wurde,
            // inklusive Forensik-Kennzahlen, gehört aber ins Audit-Journal.
            AddAuditEntry(
                tournament,
                AuditJournalAction.RoundPreviewGenerated,
                AuditJournalSeverity.Info,
                $"Runde-Vorschau erzeugt: Runde {preview.RoundNumber}.",
                preview.Round.Forensics?.ToSummaryLine(),
                roundNumber: preview.RoundNumber);

            return preview;
        });
    }

    /// <summary>
    /// Waehlt das Auslosungsverfahren fuer das Schweizer System (STM-FACH-002). Standard bleibt die
    /// bestehende Optimal-V2-Engine; FIDE-Dutch wird ueber
    /// <see cref="TournamentSettings.PairingStrategy"/> bewusst ausgewaehlt.
    /// </summary>
    private ISwissPairingStrategy SelectSwissStrategy(TournamentState tournament) =>
        tournament.Settings.PairingStrategy switch
        {
            SwissPairingStrategyKind.FideDutch => _fideDutch,
            _ => _swiss
        };

    private NextRoundPreview BuildNextRoundPreview(TournamentState tournament, string trigger)
    {
        EnsureCanCreateNextRound(tournament);

        TournamentRound previewRound = tournament.Settings.Format switch
        {
            TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament),
            TournamentFormat.Swiss => SelectSwissStrategy(tournament).GenerateNextRound(tournament),
            _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
                .WithErrorCode("TOURNAMENT_FORMAT_UNSUPPORTED")
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
        return UpdatePairingAtomically(tournamentId, "Auslosung blockiert.", tournament =>
        {

            TournamentRound nextRound;
            EnsureCanCreateNextRound(tournament);
            nextRound = tournament.Settings.Format switch
            {
                TournamentFormat.RoundRobin => GetNextRoundRobinRound(tournament, persistPlan: true),
                TournamentFormat.Swiss => SelectSwissStrategy(tournament).GenerateNextRound(tournament),
                _ => throw new NotSupportedException($"Format {tournament.Settings.Format} ist im MVP noch nicht implementiert.")
                    .WithErrorCode("TOURNAMENT_FORMAT_UNSUPPORTED")
            };

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

            return nextRound;
        });
    }

    public TournamentRound RollChess960StartPositions(Guid tournamentId, int roundNumber, bool overwriteExisting, int? seed = null)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var roundIndex = RequireRoundIndex(tournament, roundNumber);
            var round = tournament.Rounds[roundIndex];
            if (round.IsLocked || round.IsVerified)
            {
                throw new InvalidOperationException($"Runde {roundNumber} ist gesperrt oder geprüft. Startstellungen können nicht mehr geändert werden.")
                    .WithErrorCode("CHESS960_ROUND_LOCKED");
            }

            var existingCount = round.Pairings.Count(pairing => pairing.Chess960StartPosition is not null);
            if (existingCount > 0 && !overwriteExisting)
            {
                throw new InvalidOperationException("Für diese Runde existieren bereits Chess960-Startstellungen. Zum Überschreiben muss overwriteExisting=true gesetzt werden.")
                    .WithErrorCode("CHESS960_ROUND_OVERWRITE_REQUIRED");
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
                throw new InvalidOperationException($"Runde {roundNumber} enthält kein reguläres Brett für eine Chess960-Startstellung.")
                    .WithErrorCode("CHESS960_REGULAR_BOARD_REQUIRED");
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

            return updated;
        });
    }

    public TournamentRound RollChess960StartPositionForBoard(
        Guid tournamentId,
        int roundNumber,
        int boardNumber,
        bool overwriteExisting,
        int? seed = null,
        int? positionNumber = null)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var roundIndex = RequireRoundIndex(tournament, roundNumber);
            var round = tournament.Rounds[roundIndex];
            if (round.IsLocked || round.IsVerified)
            {
                throw new InvalidOperationException($"Runde {roundNumber} ist gesperrt oder geprüft. Startstellungen können nicht mehr geändert werden.")
                    .WithErrorCode("CHESS960_ROUND_LOCKED");
            }

            var pairing = round.Pairings.FirstOrDefault(item => item.BoardNumber == boardNumber);
            if (pairing is null)
            {
                throw new InvalidOperationException($"Brett {boardNumber} existiert in Runde {roundNumber} nicht.")
                    .WithErrorCode("BOARD_NOT_FOUND");
            }

            if (pairing.IsBye)
            {
                throw new InvalidOperationException($"Brett {boardNumber} ist spielfrei und erhält keine Chess960-Startstellung.")
                    .WithErrorCode("CHESS960_BYE_BOARD");
            }

            var hadExisting = pairing.Chess960StartPosition is not null;
            if (hadExisting && !overwriteExisting)
            {
                throw new InvalidOperationException($"Für Brett {boardNumber} existiert bereits eine Chess960-Startstellung. Zum Überschreiben muss overwriteExisting=true gesetzt werden.")
                    .WithErrorCode("CHESS960_BOARD_OVERWRITE_REQUIRED");
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

            return updated;
        });
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
    public TournamentRound RecordQueuedResult(Guid tournamentId, QueuedResultMutation mutation)
    {
        ArgumentNullException.ThrowIfNull(mutation);
        if (mutation.MutationId == Guid.Empty || mutation.WhitePlayerId == Guid.Empty || mutation.BlackPlayerId == Guid.Empty ||
            mutation.WhitePlayerId == mutation.BlackPlayerId || mutation.RoundNumber < 1 || mutation.BoardNumber < 1 ||
            !Enum.IsDefined(mutation.Result) || !Enum.IsDefined(mutation.ExpectedPreviousResult))
            throw new ArgumentException("Vorgemerktes Ergebnis enthält ungültige Pflichtwerte.")
                .WithErrorCode("QUEUED_RESULT_INVALID");
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            if (tournament.ResultMutationReceipts.TryGetValue(mutation.MutationId, out var receipt))
            {
                if (receipt != mutation) throw new QueuedResultConflictException();
                return tournament.Rounds[RequireRoundIndex(tournament, mutation.RoundNumber)];
            }
            if (tournament.ResultMutationReceipts.Count >= 10000)
                throw new InvalidOperationException("Die Grenze für bestätigte Offline-Ergebnisse ist erreicht. Bitte Turnierleitung kontaktieren.")
                    .WithErrorCode("RESULT_RECEIPT_LIMIT");
            var round = tournament.Rounds.FirstOrDefault(item => item.RoundNumber == mutation.RoundNumber);
            var pairing = round?.Pairings.FirstOrDefault(item => item.BoardNumber == mutation.BoardNumber);
            if (tournament.ResultQueueEpoch != mutation.Epoch || pairing is null || pairing.IsBye || round!.IsLocked ||
                pairing.WhitePlayerId != mutation.WhitePlayerId || pairing.BlackPlayerId != mutation.BlackPlayerId ||
                pairing.Result.Kind != mutation.ExpectedPreviousResult || pairing.LastChangedAt != mutation.ExpectedLastChangedAt)
                throw new QueuedResultConflictException();
            var updated = RecordResultCore(tournament, mutation.RoundNumber, mutation.BoardNumber, mutation.Result, mutation.ExpectedPreviousResult);
            tournament.ResultMutationReceipts.Add(mutation.MutationId, mutation);
            return updated;
        });
    }

    public TournamentRound RecordResult(
        Guid tournamentId,
        int roundNumber,
        int boardNumber,
        GameResultKind resultKind,
        GameResultKind? expectedPreviousResult = null,
        string? correctionReason = null,
        DateTimeOffset? expectedLastChangedAt = null)
    {
        if (!Enum.IsDefined(resultKind) ||
            (expectedPreviousResult is { } expected && !Enum.IsDefined(expected)))
        {
            throw new InvalidOperationException("Ergebniswert oder erwarteter vorheriger Ergebniswert ist ungültig.")
                .WithErrorCode("RESULT_VALUE_INVALID");
        }
        var reason = string.IsNullOrWhiteSpace(correctionReason) ? null : correctionReason.Trim();
        if (reason is { Length: > MaxCorrectionReasonLength })
        {
            throw new InvalidOperationException($"Der Korrekturgrund darf höchstens {MaxCorrectionReasonLength} Zeichen lang sein.")
                .WithErrorCode("RESULT_REASON_TOO_LONG");
        }
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            if (expectedLastChangedAt is { } expectedChange)
            {
                // Detects an intermediate change even when the value was changed back (A -> B -> A).
                var board = tournament.Rounds[RequireRoundIndex(tournament, roundNumber)].Pairings
                    .FirstOrDefault(p => p.BoardNumber == boardNumber);
                if (board is not null && board.LastChangedAt != expectedChange)
                {
                    throw new InvalidOperationException(
                        $"Das Ergebnis für Runde {roundNumber}, Brett {boardNumber} wurde zwischenzeitlich geändert. " +
                        "Bitte Turnierstand neu laden und die Korrektur erneut prüfen.")
                        .WithErrorCode("RESULT_CHANGED");
                }
            }
            return RecordResultCore(tournament, roundNumber, boardNumber, resultKind, expectedPreviousResult, reason);
        });
    }

    private const int MaxCorrectionReasonLength = 500;

    private TournamentRound RecordResultCore(TournamentState tournament, int roundNumber, int boardNumber,
        GameResultKind resultKind, GameResultKind? expectedPreviousResult, string? correctionReason = null)
    {
            GameResultKind? previousKind = null;
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
                    previousKind = p.Result.Kind;
                    if (expectedPreviousResult is not null && p.Result.Kind != expectedPreviousResult.Value)
                    {
                        throw new InvalidOperationException(
                            $"Das Ergebnis für Runde {roundNumber}, Brett {boardNumber} wurde zwischenzeitlich geändert. " +
                            "Bitte Turnierstand neu laden und die Korrektur erneut prüfen.")
                            .WithErrorCode("RESULT_CHANGED");
                    }
                    EnsureResultMatchesPairing(p, resultKind, roundNumber);
                    var changedAt = DateTimeOffset.UtcNow;
                    if (p.LastChangedAt is { } prior && changedAt <= prior)
                    {
                        if (prior.Ticks == DateTime.MaxValue.Ticks || prior.UtcTicks == DateTime.MaxValue.Ticks)
                            throw new InvalidOperationException("Der vorhandene Ergebniszeitstempel liegt am Darstellungsende. Datenbestand pruefen; die Aenderung wurde nicht gespeichert.")
                                .WithErrorCode("RESULT_TIMESTAMP_LIMIT");
                        changedAt = prior.AddTicks(1);
                    }
                    return p with { Result = new GameResult(resultKind), LastChangedAt = changedAt };
                })
                .ToList();

            if (!foundBoard)
            {
                throw new InvalidOperationException($"Brett {boardNumber} wurde in Runde {roundNumber} nicht gefunden.")
                    .WithErrorCode("BOARD_NOT_FOUND");
            }

            var updated = WithCalculatedStatus(round with { Pairings = updatedPairings });
            tournament.Rounds[roundIndex] = updated;
            if (previousKind is { } previous && previous != GameResultKind.NotPlayed && previous != resultKind)
            {
                // STM-FACH-007: one explicit correction event. Later rounds keep their pairings (they were
                // drawn with the old result); standings and tie-breaks are always recalculated on read.
                // Only result-dependent formats pair later rounds from earlier results. A round-robin
                // plan is fixed up front, so a correction never invalidates its later rounds.
                var resultDependentPairing = tournament.Settings.Format != TournamentFormat.RoundRobin;
                var laterRounds = resultDependentPairing
                    ? tournament.Rounds.Where(r => r.RoundNumber > roundNumber).Select(r => r.RoundNumber).OrderBy(n => n).ToArray()
                    : Array.Empty<int>();
                var summary = $"Ergebnis korrigiert: Runde {roundNumber}, Brett {boardNumber}.";
                if (laterRounds.Length > 0)
                {
                    summary += $" Bereits mit dem alten Ergebnis gepaart: Runde {string.Join(", ", laterRounds)}. " +
                               "Diese Paarungen bleiben unverändert; Tabelle und Feinwertungen werden neu berechnet.";
                }
                AddAuditEntry(tournament, AuditJournalAction.ResultCorrected,
                    laterRounds.Length > 0 ? AuditJournalSeverity.Warning : AuditJournalSeverity.Info,
                    summary, $"previous={previous}; new={resultKind}",
                    roundNumber: roundNumber, boardNumber: boardNumber, reason: correctionReason);
            }
            else
            {
                AddAuditEntry(tournament, AuditJournalAction.ResultRecorded, AuditJournalSeverity.Info, $"Ergebnis eingetragen: Runde {roundNumber}, Brett {boardNumber}.", resultKind.ToString(), roundNumber: roundNumber, boardNumber: boardNumber);
            }
            return updated;
    }

    public TournamentRound OverridePairing(Guid tournamentId, int roundNumber, int boardNumber, Guid? whitePlayerId, Guid? blackPlayerId, string? notes)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            if (!tournament.Settings.AllowManualPairingOverrides)
            {
                throw new InvalidOperationException("Manuelle Paarungsänderungen sind in den Turniereinstellungen deaktiviert.")
                    .WithErrorCode("MANUAL_PAIRING_DISABLED");
            }

            var roundIndex = RequireRoundIndex(tournament, roundNumber);
            var round = tournament.Rounds[roundIndex];
            EnsureRoundEditable(round);

            if (whitePlayerId is null && blackPlayerId is null)
            {
                throw new InvalidOperationException("Mindestens ein Spieler muss gesetzt sein.")
                    .WithErrorCode("PAIRING_PLAYER_REQUIRED");
            }

            if (whitePlayerId is not null && blackPlayerId is not null && whitePlayerId == blackPlayerId)
            {
                throw new InvalidOperationException("Ein Spieler kann nicht gegen sich selbst spielen.")
                    .WithErrorCode("PAIRING_SELF_OPPONENT");
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
                            throw new InvalidOperationException("Ein Spieler darf in derselben Runde nicht mehrfach gepaart werden.")
                                .WithErrorCode("PAIRING_PLAYER_DUPLICATE");
                        }

                        return pairing;
                    }

                    foundBoard = true;
                    if (whitePlayerId is null)
                    {
                        throw new InvalidOperationException("Ein Brett benötigt mindestens einen Weißspieler. Für Bye bitte Spieler als Weiß und Schwarz leer lassen.")
                            .WithErrorCode("PAIRING_WHITE_REQUIRED");
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
                throw new InvalidOperationException($"Brett {boardNumber} wurde in Runde {roundNumber} nicht gefunden.")
                    .WithErrorCode("BOARD_NOT_FOUND");
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

            return updated;
        });
    }

    public TournamentRound SetRoundLock(Guid tournamentId, int roundNumber, bool isLocked)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
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

            return updated;
        });
    }

    public TournamentRound SetRoundVerified(Guid tournamentId, int roundNumber, bool isVerified)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var roundIndex = RequireRoundIndex(tournament, roundNumber);
            var round = tournament.Rounds[roundIndex];

            if (isVerified && !IsRoundComplete(round))
            {
                throw new InvalidOperationException($"Runde {roundNumber} kann erst geprüft werden, wenn alle Ergebnisse eingetragen sind.")
                    .WithErrorCode("ROUND_REVIEW_RESULTS_PENDING");
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

            return updated;
        });
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

    public ExportDocument ExportTrf16(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        // FIDE-TRF-Spezifikation erwartet alle Turnierteilnehmer, nicht nur die
        // in der sichtbaren Rangliste verbliebenen aktiven Spieler (STM-IE-001).
        return _exports.ExportTrf16(tournament, _standings.Calculate(tournament, includeInactive: true));
    }

    public ExportDocument ExportSwissManagerCsv(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        var csv = SwissManagerCsvCodec.ExportPlayers(tournament.Players);
        return new ExportDocument
        {
            FileName = $"{tournament.Name}_SwissManager.csv".Replace(' ', '_'),
            ContentType = "text/csv; charset=utf-8",
            Content = csv
        };
    }

    public ExportDocument ExportPrintableTournamentHtml(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportPrintableTournamentHtml(
            tournament,
            _standings.Calculate(tournament),
            _roundDiagnostics.Calculate(tournament));
    }

    public ExportDocument ExportPrintableTournamentPackageHtml(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportPrintableTournamentPackageHtml(
            tournament,
            _standings.Calculate(tournament),
            _roundDiagnostics.Calculate(tournament));
    }

    public ExportDocument ExportTournamentPackageJson(Guid tournamentId)
    {
        var tournament = RequireTournament(tournamentId);
        return _exports.ExportTournamentPackageJson(
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
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var document = _auditExport.BuildJsonl(tournament);
            RecordAuditExport(tournament, document.FileName, "jsonl");
            return document;
        });
    }

    public ExportDocument ExportAuditJournalJson(Guid tournamentId)
    {
        return _store.UpdateAtomically(tournamentId, tournament =>
        {
            var document = _auditExport.BuildJson(tournament);
            RecordAuditExport(tournament, document.FileName, "json");
            return document;
        });
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
    }

    private TResult UpdatePairingAtomically<TResult>(Guid id, string summary, Func<TournamentState, TResult> update)
    {
        try { return _store.UpdateAtomically(id, update); }
        catch (InvalidOperationException failure)
        {
            try
            {
                _store.UpdateAtomically(id, state =>
                {
                    AddAuditEntry(state, AuditJournalAction.PairingGenerationBlocked,
                        AuditJournalSeverity.Warning, summary, failure.Message, reason: failure.Message);
                    return true;
                });
            }
            catch { /* An audit failure must not replace the original pairing error. */ }
            throw;
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
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.")
            .WithErrorCode("TOURNAMENT_NOT_FOUND");
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

    private AuditJournalEntry? MirrorAuditEntry(TournamentState tournament, AuditJournalEntry entry)
    {
        if (_auditSink is null)
        {
            return null;
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
                var warning = new AuditJournalEntry
                {
                    Action = AuditJournalAction.AuditJournalMirrorFailed,
                    Severity = AuditJournalSeverity.Warning,
                    Actor = "System",
                    Summary = "Audit-Spiegel konnte nicht geschrieben werden.",
                    Details = ex.Message
                };
                tournament.AuditJournal.Add(warning);
                return warning;
            }
        }
        return null;
    }

    private static TournamentSettings NormalizeSettings(TournamentSettings settings)
    {
        var tiebreaks = (settings.Tiebreaks ?? Array.Empty<TiebreakType>())
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
            UnplayedRoundBuchholzMode = Enum.IsDefined(settings.UnplayedRoundBuchholzMode)
                ? settings.UnplayedRoundBuchholzMode
                : UnplayedRoundBuchholzMode.IgnoreUnplayedRounds,
            Tiebreaks = tiebreaks
        };
    }

    private static void ValidateImportedTournament(TournamentState tournament)
    {
        if (tournament is null)
        {
            throw new ArgumentNullException(nameof(tournament), "Importiertes Turnier fehlt.");
        }

        if (tournament.Id == Guid.Empty)
        {
            throw new ArgumentException("Importiertes Turnier hat keine gültige ID.", nameof(tournament))
                .WithErrorCode("BACKUP_TOURNAMENT_ID_INVALID");
        }

        if (string.IsNullOrWhiteSpace(tournament.Name))
        {
            throw new ArgumentException("Importiertes Turnier hat keinen Namen.", nameof(tournament))
                .WithErrorCode("BACKUP_TOURNAMENT_NAME_MISSING");
        }

        if (tournament.Settings is null)
        {
            throw new ArgumentException("Importiertes Turnier hat keine Einstellungen.", nameof(tournament))
                .WithErrorCode("BACKUP_SETTINGS_MISSING");
        }

        if (tournament.Players is null)
        {
            throw new ArgumentException("Importiertes Turnier hat keine Teilnehmerliste.", nameof(tournament))
                .WithErrorCode("BACKUP_PARTICIPANTS_MISSING");
        }

        if (tournament.Rounds is null)
        {
            throw new ArgumentException("Importiertes Turnier hat keine Rundenliste.", nameof(tournament))
                .WithErrorCode("BACKUP_ROUNDS_MISSING");
        }

        if (tournament.AuditJournal is null)
        {
            throw new ArgumentException("Importiertes Turnier hat kein Audit-Journal.", nameof(tournament))
                .WithErrorCode("BACKUP_AUDIT_MISSING");
        }

        if (tournament.ResultMutationReceipts is null || tournament.ResultMutationReceipts.Count > 10000 ||
            tournament.ResultMutationReceipts.Any(item => item.Value is null || item.Key == Guid.Empty || item.Key != item.Value.MutationId ||
                item.Value.RoundNumber < 1 || item.Value.BoardNumber < 1 || item.Value.WhitePlayerId == Guid.Empty ||
                item.Value.BlackPlayerId == Guid.Empty || item.Value.WhitePlayerId == item.Value.BlackPlayerId ||
                !Enum.IsDefined(item.Value.Result) || !Enum.IsDefined(item.Value.ExpectedPreviousResult)))
            throw new ArgumentException("Importiertes Turnier enthält ungültige Offline-Ergebnisbestätigungen.", nameof(tournament))
                .WithErrorCode("BACKUP_RESULT_RECEIPTS_INVALID");

        ValidateImportedPlayers(tournament.Players);
        ValidateImportedRounds(tournament);
        if (tournament.RoundRobinPlan is not null)
        {
            if (tournament.Settings.Format != TournamentFormat.RoundRobin)
                throw new InvalidOperationException("Ein Rundenturnier-Spielplan gehört ausschließlich zu einem Rundenturnier.")
                    .WithErrorCode("ROUND_ROBIN_PLAN_FORMAT_MISMATCH");
            new RoundRobinPairingEngine().ValidateHistory(tournament, tournament.RoundRobinPlan);
        }
        foreach (var entry in tournament.AuditJournal)
        {
            if (entry is null || entry.Actor is null || entry.Summary is null)
            {
                throw new InvalidOperationException("Importiertes Audit-Journal enthält einen leeren Eintrag oder Pflichttext.")
                    .WithErrorCode("BACKUP_AUDIT_ENTRY_INVALID");
            }
        }
    }

    private static void ValidateImportedPlayers(IReadOnlyList<Player> players)
    {
        var ids = new HashSet<Guid>();
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var fideIds = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var nationalIds = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        for (var index = 0; index < players.Count; index++)
        {
            var player = players[index];
            if (player is null)
            {
                throw new InvalidOperationException($"Importierter Teilnehmer in Zeile {index + 1} ist leer.")
                    .WithErrorCode("BACKUP_PARTICIPANT_EMPTY");
            }

            if (player.Id == Guid.Empty)
            {
                throw new InvalidOperationException($"Importierter Teilnehmer '{player.Name}' hat keine gültige ID.")
                    .WithErrorCode("BACKUP_PARTICIPANT_ID_INVALID");
            }

            if (player.Rating is null)
            {
                throw new InvalidOperationException($"Importierter Teilnehmer in Zeile {index + 1} hat kein Ratingprofil.")
                    .WithErrorCode("BACKUP_RATING_PROFILE_MISSING");
            }

            if (!ids.Add(player.Id))
            {
                throw new InvalidOperationException($"Teilnehmer-ID {player.Id} kommt mehrfach vor.")
                    .WithErrorCode("BACKUP_PARTICIPANT_ID_DUPLICATE");
            }

            if (string.IsNullOrWhiteSpace(player.Name))
            {
                throw new InvalidOperationException($"Importierter Teilnehmer {player.Id} hat keinen Namen.")
                    .WithErrorCode("BACKUP_PARTICIPANT_NAME_MISSING");
            }

            var name = player.Name.Trim();
            if (!names.Add(name))
            {
                throw new InvalidOperationException($"Der Spielername '{name}' kommt mehrfach vor.")
                    .WithErrorCode("PLAYER_NAME_DUPLICATE");
            }

            AddUniqueImportedExternalId(fideIds, "FIDE-ID", player.FideId, name);
            AddUniqueImportedExternalId(nationalIds, "DSB-ID", player.NationalId, name);
        }
    }

    private static void AddUniqueImportedExternalId(
        IDictionary<string, string> seen,
        string label,
        string? value,
        string playerName)
    {
        var normalized = NormalizeExternalId(value);
        if (normalized is null)
        {
            return;
        }

        if (seen.TryGetValue(normalized, out var previousPlayer))
        {
            throw new InvalidOperationException($"{label} {value} kommt mehrfach vor ({previousPlayer}, {playerName}).")
                .WithErrorCode("BACKUP_EXTERNAL_ID_DUPLICATE");
        }

        seen[normalized] = playerName;
    }

    private static void ValidateImportedRounds(TournamentState tournament)
    {
        var playerIds = tournament.Players.Select(player => player.Id).ToHashSet();
        var plannedRounds = Math.Max(1, tournament.Settings.PlannedRounds);
        if (tournament.Rounds.Count > plannedRounds)
        {
            throw new InvalidOperationException($"Importiertes Turnier enthält {tournament.Rounds.Count} Runden, geplant sind aber nur {plannedRounds}.")
                .WithErrorCode("BACKUP_TOO_MANY_ROUNDS");
        }

        var emptyRoundIndex = tournament.Rounds.FindIndex(round => round is null);
        if (emptyRoundIndex >= 0)
        {
            throw new InvalidOperationException($"Importierte Runde {emptyRoundIndex + 1} ist leer.")
                .WithErrorCode("BACKUP_ROUND_EMPTY");
        }

        var orderedRounds = tournament.Rounds.OrderBy(round => round.RoundNumber).ToArray();
        for (var index = 0; index < orderedRounds.Length; index++)
        {
            var round = orderedRounds[index];
            var expectedRoundNumber = index + 1;
            if (round.RoundNumber != expectedRoundNumber)
            {
                throw new InvalidOperationException($"Importierte Runden müssen fortlaufend bei 1 beginnen. Erwartet: Runde {expectedRoundNumber}, gefunden: Runde {round.RoundNumber}.")
                    .WithErrorCode("BACKUP_ROUND_SEQUENCE_INVALID");
            }

            if (round.Pairings is null)
            {
                throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} hat keine Paarungsliste.")
                    .WithErrorCode("BACKUP_PAIRINGS_MISSING");
            }

            ValidateImportedRoundEvidence(round);

            var boardNumbers = new HashSet<int>();
            var roundPlayers = new HashSet<Guid>();
            foreach (var pairing in round.Pairings)
            {
                if (pairing is null)
                {
                    throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} enthält ein leeres Brett.")
                        .WithErrorCode("BACKUP_BOARD_EMPTY");
                }

                if (pairing.BoardNumber <= 0)
                {
                    throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} enthält eine ungültige Brettnummer.")
                        .WithErrorCode("BACKUP_BOARD_NUMBER_INVALID");
                }

                if (pairing.Result is null || !Enum.IsDefined(pairing.Result.Kind))
                {
                    throw new InvalidOperationException($"Runde {round.RoundNumber}, Brett {pairing.BoardNumber}: Ergebnis fehlt oder ist ungültig.")
                        .WithErrorCode("BACKUP_RESULT_INVALID");
                }
                if (pairing.Chess960StartPosition is { } position &&
                    (position.WhiteBackRank is null || position.BlackBackRank is null))
                {
                    throw new InvalidOperationException($"Runde {round.RoundNumber}, Brett {pairing.BoardNumber}: Chess960-Pflichttext fehlt.")
                        .WithErrorCode("BACKUP_CHESS960_TEXT_MISSING");
                }

                if (!boardNumbers.Add(pairing.BoardNumber))
                {
                    throw new InvalidOperationException($"Runde {round.RoundNumber} enthält Brett {pairing.BoardNumber} mehrfach.")
                        .WithErrorCode("BACKUP_BOARD_DUPLICATE");
                }

                if (pairing.WhitePlayerId is null || pairing.WhitePlayerId.Value == Guid.Empty)
                {
                    throw new InvalidOperationException($"Runde {round.RoundNumber}, Brett {pairing.BoardNumber}: Weißspieler fehlt.")
                        .WithErrorCode("PAIRING_WHITE_REQUIRED");
                }

                EnsureResultMatchesPairing(pairing, pairing.Result.Kind, round.RoundNumber);
                var whitePlayerId = pairing.WhitePlayerId!.Value;
                EnsureImportedPairingPlayerExists(playerIds, whitePlayerId, round.RoundNumber, pairing.BoardNumber, "Weiß");
                AddImportedRoundPlayer(roundPlayers, whitePlayerId, round.RoundNumber, pairing.BoardNumber);

                if (pairing.BlackPlayerId is not null)
                {
                    if (pairing.BlackPlayerId.Value == Guid.Empty)
                    {
                        throw new InvalidOperationException($"Runde {round.RoundNumber}, Brett {pairing.BoardNumber}: Schwarzspieler fehlt.")
                            .WithErrorCode("BACKUP_BLACK_PLAYER_MISSING");
                    }

                    if (pairing.BlackPlayerId.Value == whitePlayerId)
                    {
                        throw new InvalidOperationException($"Runde {round.RoundNumber}, Brett {pairing.BoardNumber}: Ein Spieler ist gegen sich selbst gepaart.")
                            .WithErrorCode("PAIRING_SELF_OPPONENT");
                    }

                    EnsureImportedPairingPlayerExists(playerIds, pairing.BlackPlayerId.Value, round.RoundNumber, pairing.BoardNumber, "Schwarz");
                    AddImportedRoundPlayer(roundPlayers, pairing.BlackPlayerId.Value, round.RoundNumber, pairing.BoardNumber);
                }
            }
        }
    }

    private static void ValidateImportedRoundEvidence(TournamentRound round)
    {
        var audit = round.Audit;
        if (audit is null || audit.Algorithm is null || audit.RulesetVersion is null)
        {
            throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} hat keinen vollständigen Auditstand.")
                .WithErrorCode("BACKUP_ROUND_AUDIT_INVALID");
        }
        ValidateImportedTextList(audit.Messages);
        ValidateImportedTextList(audit.ScoreGroups);
        ValidateImportedTextList(audit.Floaters);
        ValidateImportedTextList(audit.ColorNotes);

        if (round.Forensics is not { } forensics) return;
        if (forensics.Trigger is null || forensics.Format is null || forensics.Algorithm is null || forensics.QualitySeverity is null)
        {
            throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} hat unvollständige Forensiktexte.")
                .WithErrorCode("BACKUP_FORENSIC_TEXT_INVALID");
        }
        ValidateImportedTextList(forensics.ByeDecisions);
        ValidateImportedTextList(forensics.RematchWarnings);
        ValidateImportedTextList(forensics.ScoreGroupDeviations);
        ValidateImportedTextList(forensics.ColorNotes);
        ValidateImportedTextList(forensics.EngineMessages);
        ValidateImportedTextList(forensics.Findings);
        if (forensics.ProposedPairings is null || forensics.ProposedPairings.Any(board =>
                board is null || board.White is null || board.Black is null))
        {
            throw new InvalidOperationException($"Importierte Runde {round.RoundNumber} hat eine unvollständige forensische Brettliste.")
                .WithErrorCode("BACKUP_FORENSIC_BOARDS_INVALID");
        }
    }

    private static void ValidateImportedTextList(IReadOnlyList<string>? values)
    {
        if (values is null || values.Any(value => value is null))
        {
            throw new InvalidOperationException("Importierte Audit-/Forensikliste fehlt oder enthält einen leeren Textwert.")
                .WithErrorCode("BACKUP_TEXT_LIST_INVALID");
        }
    }

    private static void EnsureImportedPairingPlayerExists(
        ISet<Guid> playerIds,
        Guid playerId,
        int roundNumber,
        int boardNumber,
        string color)
    {
        if (!playerIds.Contains(playerId))
        {
            throw new InvalidOperationException($"Runde {roundNumber}, Brett {boardNumber}: {color}spieler {playerId} ist nicht in der Teilnehmerliste.")
                .WithErrorCode("BACKUP_PAIRING_PLAYER_UNKNOWN");
        }
    }

    private static void AddImportedRoundPlayer(ISet<Guid> roundPlayers, Guid playerId, int roundNumber, int boardNumber)
    {
        if (!roundPlayers.Add(playerId))
        {
            throw new InvalidOperationException($"Runde {roundNumber}: Spieler {playerId} ist mehrfach gepaart (zuletzt Brett {boardNumber}).")
                .WithErrorCode("PAIRING_PLAYER_DUPLICATE");
        }
    }

    private static int RequireRoundIndex(TournamentState tournament, int roundNumber)
    {
        var index = tournament.Rounds.FindIndex(r => r.RoundNumber == roundNumber);
        if (index < 0)
        {
            throw new InvalidOperationException($"Runde {roundNumber} wurde nicht gefunden.")
                .WithErrorCode("ROUND_NOT_FOUND");
        }

        return index;
    }

    private static void EnsureResultMatchesPairing(Pairing pairing, GameResultKind resultKind, int roundNumber)
    {
        if (pairing.WhitePlayerId is null || pairing.WhitePlayerId == Guid.Empty)
        {
            throw new InvalidOperationException($"Runde {roundNumber}, Brett {pairing.BoardNumber}: Weißspieler fehlt.")
                .WithErrorCode("PAIRING_WHITE_REQUIRED");
        }

        if ((pairing.BlackPlayerId is null) != (resultKind == GameResultKind.Bye))
        {
            throw new InvalidOperationException(
                $"Runde {roundNumber}, Brett {pairing.BoardNumber}: Bye ist nur für ein Brett ohne Schwarzspieler zulässig; " +
                "ein solches Freilos muss als Bye gewertet werden.")
                .WithErrorCode("RESULT_BYE_MISMATCH");
        }
    }

    private static void EnsureRoundEditable(TournamentRound round)
    {
        if (round.IsLocked || round.IsVerified)
        {
            throw new InvalidOperationException($"Runde {round.RoundNumber} ist gesperrt oder geprüft und kann nicht mehr geändert werden.")
                .WithErrorCode("ROUND_LOCKED");
        }
    }

    private static void EnsurePreviousRoundComplete(TournamentState tournament)
    {
        var latestRound = tournament.Rounds.OrderByDescending(r => r.RoundNumber).FirstOrDefault();
        if (latestRound is not null && !IsRoundComplete(latestRound))
        {
            throw new InvalidOperationException($"Runde {latestRound.RoundNumber} hat noch offene Ergebnisse. Bitte erst abschließen oder korrigieren.")
                .WithErrorCode("PREVIOUS_ROUND_INCOMPLETE");
        }
    }

    private static void EnsureCanCreateNextRound(TournamentState tournament)
    {
        if (tournament.Players.Count(p => p.IsActive) < 2)
        {
            throw new InvalidOperationException("Für eine Auslosung werden mindestens zwei aktive Spieler benötigt.")
                .WithErrorCode("PAIRING_MINIMUM_PLAYERS");
        }

        if (tournament.Rounds.Count >= tournament.Settings.PlannedRounds)
        {
            throw new InvalidOperationException($"Die geplante maximale Rundenzahl ({tournament.Settings.PlannedRounds}) ist bereits erreicht.")
                .WithErrorCode("PLANNED_ROUND_LIMIT");
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
            throw new InvalidOperationException($"Spieler {playerId} wurde nicht gefunden ({argumentName}).")
                .WithErrorCode("PLAYER_NOT_FOUND");
        }

        if (!player.IsActive)
        {
            throw new InvalidOperationException($"Spieler {player.Name} ist nicht aktiv und kann nicht gepaart werden.")
                .WithErrorCode("PLAYER_INACTIVE");
        }
    }

    private TournamentRound GetNextRoundRobinRound(TournamentState tournament, bool persistPlan = false)
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
                    "damit bereits gespielte Runden nicht rückwirkend verändert werden.")
                    .WithErrorCode("ROUND_ROBIN_PARTICIPANTS_CHANGED");
            }
        }

        var plan = tournament.Rounds.Count == 0
            ? _roundRobin.CreatePlan(activePlayers, tournament.Settings.TwzSource)
            : tournament.RoundRobinPlan ?? _roundRobin.ReconstructLegacyPlan(tournament);
        _roundRobin.ValidateHistory(tournament, plan);
        if (!activePlayers.Select(player => player.Id).ToHashSet().SetEquals(plan.ParticipantOrder))
            throw new InvalidOperationException("Der aktive Teilnehmerkreis passt nicht zum gespeicherten Rundenturnier-Spielplan. Vor der Fortsetzung ausdrücklich prüfen.")
                .WithErrorCode("ROUND_ROBIN_PARTICIPANTS_MISMATCH");
        var next = _roundRobin.GenerateRound(plan, tournament.Rounds.Count + 1);
        if (persistPlan) tournament.RoundRobinPlan = plan;
        return next;
    }

    private static Player NormalizePlayerForSave(TournamentState tournament, Player player, bool preserveExistingRank)
    {
        if (string.IsNullOrWhiteSpace(player.Name))
        {
            throw new ArgumentException("Spielername ist Pflicht.", nameof(player))
                .WithErrorCode("PLAYER_NAME_REQUIRED");
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
            throw new InvalidOperationException($"Ein Spieler mit dem Namen '{name}' existiert bereits in diesem Turnier.")
                .WithErrorCode("PLAYER_NAME_DUPLICATE");
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
                    $"Ein Teilnehmer mit FIDE-ID {fideId} ist bereits im Turnier vorhanden: {clash.Name}. Bitte den vorhandenen Teilnehmer bearbeiten statt eine Dublette anzulegen.")
                    .WithErrorCode("PLAYER_FIDE_ID_DUPLICATE");
            }
        }

        var normalizedNational = NormalizeExternalId(nationalId);
        if (normalizedNational is not null)
        {
            var clash = tournament.Players.FirstOrDefault(p => p.Id != ownId && NormalizeExternalId(p.NationalId) == normalizedNational);
            if (clash is not null)
            {
                throw new InvalidOperationException(
                    $"Ein Teilnehmer mit DSB-ID {nationalId} ist bereits im Turnier vorhanden: {clash.Name}. Bitte den vorhandenen Teilnehmer bearbeiten statt eine Dublette anzulegen.")
                    .WithErrorCode("PLAYER_NATIONAL_ID_DUPLICATE");
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
            throw new InvalidOperationException($"Der Spielername '{duplicate.Key}' kommt mehrfach vor.")
                .WithErrorCode("PLAYER_NAME_DUPLICATE");
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
                   or AuditJournalAction.ResultCorrected
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

/// <summary>STM-IE-002: Ergebnis eines Stammdaten-Imports (Swiss-Manager-CSV oder TRF16).</summary>
public sealed record PlayerImportOutcome(IReadOnlyList<Player> Added, IReadOnlyList<string> FormatErrors);
