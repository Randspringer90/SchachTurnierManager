using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class TournamentExportFormatter
{
    public ExportDocument ExportStandingsCsv(TournamentState tournament, IReadOnlyList<StandingRow> standings)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Rang;Name;TWZ;Punkte;Siege;Schwarzsiege;Direktvergleich;Buchholz;Buchholz Cut-1;Buchholz Cut-2;Median Buchholz;Sonneborn-Berger;Koya;Progressiv;Gegnerschnitt;TPR;Heldenwert");
        foreach (var row in standings)
        {
            var values = new[]
            {
                row.Rank.ToString(CultureInfo.InvariantCulture),
                row.Name,
                row.Twz.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.Points),
                row.Wins.ToString(CultureInfo.InvariantCulture),
                row.BlackWins.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.DirectEncounter),
                FormatDecimal(row.Buchholz),
                FormatDecimal(row.BuchholzCutOne),
                FormatDecimal(row.BuchholzCutTwo),
                FormatDecimal(row.MedianBuchholz),
                FormatDecimal(row.SonnebornBerger),
                FormatDecimal(row.KoyaScore),
                FormatDecimal(row.ProgressiveScore),
                FormatDecimal(row.AverageOpponentRating),
                row.TournamentPerformance?.ToString(CultureInfo.InvariantCulture) ?? string.Empty,
                FormatDecimal(row.HeroScore)
            };
            builder.AppendLine(string.Join(';', values.Select(EscapeCsv)));
        }

        return CsvDocument($"{SafeFileName(tournament.Name)}_Tabelle.csv", builder.ToString());
    }

    public ExportDocument ExportPairingsCsv(TournamentState tournament, int? roundNumber = null)
    {
        var rounds = roundNumber is null
            ? tournament.Rounds.OrderBy(r => r.RoundNumber).ToList()
            : tournament.Rounds.Where(r => r.RoundNumber == roundNumber.Value).ToList();
        if (roundNumber is not null && rounds.Count == 0)
        {
            throw new InvalidOperationException($"Runde {roundNumber.Value} wurde nicht gefunden.");
        }

        var players = tournament.Players.ToDictionary(p => p.Id, p => p.Name);
        var builder = new StringBuilder();
        builder.AppendLine("Runde;Brett;Weiß;Schwarz;Ergebnis;Chess960-Startstellung;Chess960-ID;Status;Hinweise");
        foreach (var round in rounds)
        {
            foreach (var pairing in round.Pairings.OrderBy(p => p.BoardNumber))
            {
                var values = new[]
                {
                    round.RoundNumber.ToString(CultureInfo.InvariantCulture),
                    pairing.BoardNumber.ToString(CultureInfo.InvariantCulture),
                    PlayerName(players, pairing.WhitePlayerId),
                    pairing.IsBye ? "spielfrei" : PlayerName(players, pairing.BlackPlayerId),
                    ResultLabel(pairing.Result.Kind),
                    Chess960PositionLabel(pairing),
                    Chess960PositionNumberLabel(pairing),
                    round.ResultStatus.ToString(),
                    pairing.Notes ?? string.Empty
                };
                builder.AppendLine(string.Join(';', values.Select(EscapeCsv)));
            }
        }

        var suffix = roundNumber is null ? "Paarungen" : $"Runde_{roundNumber.Value:D2}";
        return CsvDocument($"{SafeFileName(tournament.Name)}_{suffix}.csv", builder.ToString());
    }


    public ExportDocument ExportDownloadManifestJson(TournamentState tournament, IReadOnlyList<StandingRow> standings)
    {
        var latestRound = tournament.Rounds.Count == 0
            ? (int?)null
            : tournament.Rounds.Max(round => round.RoundNumber);

        var downloads = new List<object>
        {
            DownloadEntry("players-csv", "Teilnehmer CSV", $"/api/tournaments/{tournament.Id}/players/export.csv", "Teilnehmerliste mit Verein, IDs, Titel, Status und Notizen."),
            DownloadEntry("standings-csv", "Tabelle CSV", $"/api/tournaments/{tournament.Id}/standings/export.csv", "Aktuelle Tabelle mit Wertungskette und Tie-Break-Werten."),
            DownloadEntry("pairings-csv", "Alle Paarungen CSV", $"/api/tournaments/{tournament.Id}/pairings/export.csv", "Alle gespeicherten Runden und Bretter inklusive Ergebnis und Chess960-Information."),
            DownloadEntry("print-html", "Turnier-Druckansicht HTML", $"/api/tournaments/{tournament.Id}/print/html", "Kompletter Turnierbericht für Aushang, PDF-Druck oder Archiv."),
            DownloadEntry("audit-jsonl", "Audit-Bundle JSONL", $"/api/tournaments/{tournament.Id}/audit-journal/export.jsonl", "Forensisches Audit-Bundle für Nachvollziehbarkeit nach jeder Runde."),
            DownloadEntry("audit-json", "Audit-Bundle JSON", $"/api/tournaments/{tournament.Id}/audit-journal/export.json", "Strukturiertes Audit-Bundle für Review und spätere Auswertung.")
        };

        if (latestRound is not null)
        {
            downloads.Add(DownloadEntry(
                "latest-pairings-csv",
                "Aktuelle Runde CSV",
                $"/api/tournaments/{tournament.Id}/pairings/export.csv?roundNumber={latestRound.Value}",
                $"Nur Runde {latestRound.Value} für schnellen Aushang oder Ergebniszettel."));
            downloads.Add(DownloadEntry(
                "latest-round-html",
                "Aktuelle Runde HTML",
                $"/api/tournaments/{tournament.Id}/rounds/{latestRound.Value}/print/html",
                $"Rundenblatt für Runde {latestRound.Value}."));
        }

        var openBoards = tournament.Rounds.Sum(round => round.Pairings.Count(pairing => !pairing.IsBye && pairing.Result.Kind == GameResultKind.NotPlayed));
        var byeBoards = tournament.Rounds.Sum(round => round.Pairings.Count(pairing => pairing.IsBye));
        var forfeitBoards = tournament.Rounds.Sum(round => round.Pairings.Count(pairing => pairing.Result.Kind is GameResultKind.WhiteForfeitWin or GameResultKind.BlackForfeitWin or GameResultKind.DoubleForfeit));
        var manifest = new
        {
            schema = "schach-turnier-manager.export-manifest.v1",
            generatedAt = DateTimeOffset.Now,
            tournament = new
            {
                tournament.Id,
                tournament.Name,
                format = tournament.Settings.Format.ToString(),
                scoringSystem = tournament.Settings.ScoringSystem.ToString(),
                players = tournament.Players.Count,
                activePlayers = tournament.Players.Count(player => player.Status == PlayerStatus.Active),
                rounds = tournament.Rounds.Count,
                standingsRows = standings.Count
            },
            checks = new
            {
                openBoards,
                byeBoards,
                forfeitBoards,
                latestRound,
                publishReady = openBoards == 0
            },
            downloads,
            recommendedWorkflow = new[]
            {
                "Vor Veröffentlichung offene Bretter und kampflose Ergebnisse prüfen.",
                "Teilnehmer-CSV, Tabelle-CSV, Paarungen-CSV und Druckansicht exportieren.",
                "Nach jeder Runde ein Audit-Bundle JSONL lokal sichern.",
                "Bei Finale/Abschluss zusätzlich dieses Manifest zum Exportpaket legen."
            },
            privacy = new
            {
                mode = "local-only",
                note = "Das Manifest enthält nur lokale Downloadpfade und Turnier-Metadaten; es lädt keine Daten zu externen Diensten hoch."
            }
        };

        var content = JsonSerializer.Serialize(manifest, new JsonSerializerOptions { WriteIndented = true });
        return new ExportDocument
        {
            FileName = $"{SafeFileName(tournament.Name)}_Exportmanifest.json",
            ContentType = "application/json; charset=utf-8",
            Content = content
        };
    }

    public ExportDocument ExportPrintableTournamentHtml(TournamentState tournament, IReadOnlyList<StandingRow> standings, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, "Turnierbericht");
        builder.AppendLine($"<h1>{Html(tournament.Name)}</h1>");
        builder.AppendLine($"<p class=\"muted\">Druckansicht mit Teilnehmerliste, Tabelle, Runden, Paarungen und Prüfhinweisen. · Gedruckt am {Html(PrintedAtLabel())}</p>");
        AppendTournamentMeta(builder, tournament);
        AppendPlayers(builder, tournament);
        AppendStandings(builder, standings);
        AppendRounds(builder, tournament, diagnostics);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Druckansicht.html", builder.ToString());
    }

    public ExportDocument ExportPrintableRoundHtml(TournamentState tournament, TournamentRound round, RoundDiagnostics diagnostics)
    {
        var players = tournament.Players.ToDictionary(p => p.Id, p => p);
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, $"Runde {round.RoundNumber}");
        builder.AppendLine($"<h1>{Html(tournament.Name)} · Runde {round.RoundNumber}</h1>");
        builder.AppendLine($"<p class=\"muted\">Rundenblatt für Aushang, Ergebniserfassung oder Kontrolle. · Gedruckt am {Html(PrintedAtLabel())}</p>");
        builder.AppendLine("<table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Chess960</th><th>Ergebnis</th><th>Hinweise</th></tr></thead><tbody>");
        foreach (var pairing in round.Pairings.OrderBy(p => p.BoardNumber))
        {
            builder.Append("<tr>");
            builder.Append($"<td>{pairing.BoardNumber}</td>");
            builder.Append($"<td>{Html(PlayerDisplay(players, pairing.WhitePlayerId))}</td>");
            builder.Append($"<td>{Html(pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId))}</td>");
            builder.Append($"<td>{Html(Chess960Display(pairing))}</td>");
            builder.Append($"<td class=\"result-cell\">{PrintResultCell(pairing)}</td>");
            builder.Append($"<td>{Html(pairing.Notes ?? string.Empty)}</td>");
            builder.AppendLine("</tr>");
        }
        builder.AppendLine("</tbody></table>");
        AppendDiagnostics(builder, diagnostics);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Runde_{round.RoundNumber:D2}.html", builder.ToString());
    }

    public ExportDocument ExportPrintableTournamentPackageHtml(TournamentState tournament, IReadOnlyList<StandingRow> standings, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var currentRound = CurrentRound(tournament);
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, "Turnierpaket");
        builder.AppendLine($"<h1>{Html(tournament.Name)} · Turnierpaket</h1>");
        builder.AppendLine($"<p class=\"muted\">Operator-Paket für Aushang, Ergebnisannahme, Tabellenkontrolle und lokale Sicherung. · Gedruckt am {Html(PrintedAtLabel())}</p>");
        AppendTournamentMeta(builder, tournament);
        AppendPackageHints(builder, tournament, currentRound);
        AppendPlayers(builder, tournament);
        AppendStandings(builder, standings);
        AppendCurrentRoundSheet(builder, tournament, currentRound, diagnostics);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Turnierpaket.html", builder.ToString());
    }

    public ExportDocument ExportTournamentPackageJson(TournamentState tournament, IReadOnlyList<StandingRow> standings, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var currentRound = CurrentRound(tournament);
        var players = tournament.Players.ToDictionary(p => p.Id, p => p);
        var currentDiagnostics = currentRound is null
            ? null
            : diagnostics.FirstOrDefault(item => item.RoundNumber == currentRound.RoundNumber);

        var payload = new
        {
            kind = "SchachTurnierManager.TournamentPackage",
            exportedAt = DateTimeOffset.UtcNow,
            backupHint = "Vor und nach jeder Runde zusätzlich JSON-Backup ziehen; diese Paketdatei ersetzt kein Restore-Backup.",
            auditHint = "Nach jeder Runde und am Turnierende Audit-Bundle exportieren.",
            displayHint = "Zuschauer-/Beamer-Ansichten sind lokale read-only Links der WebApp und enthalten keine Operator-Controls.",
            tournament = new
            {
                id = tournament.Id,
                name = tournament.Name,
                createdOn = tournament.CreatedOn,
                format = tournament.Settings.Format.ToString(),
                plannedRounds = tournament.Settings.PlannedRounds,
                playedRounds = tournament.Rounds.Count,
                playerCount = tournament.Players.Count,
                activePlayerCount = tournament.Players.Count(player => player.Status == PlayerStatus.Active)
            },
            participants = tournament.Players
                .OrderBy(player => player.StartingRank)
                .ThenBy(player => player.Name, StringComparer.OrdinalIgnoreCase)
                .Select(player => new
                {
                    id = player.Id,
                    startingRank = player.StartingRank,
                    name = player.Name,
                    club = player.Club,
                    fideId = player.FideId,
                    nationalId = player.NationalId,
                    birthYear = player.BirthYear,
                    status = player.Status.ToString(),
                    twz = player.Twz(tournament.Settings.TwzSource)
                }),
            standings = standings.Select(row => new
            {
                rank = row.Rank,
                playerId = row.PlayerId,
                name = row.Name,
                twz = row.Twz,
                points = row.Points,
                wins = row.Wins,
                blackWins = row.BlackWins,
                buchholz = row.Buchholz,
                buchholzCutOne = row.BuchholzCutOne,
                sonnebornBerger = row.SonnebornBerger,
                tournamentPerformance = row.TournamentPerformance
            }),
            currentRound = currentRound is null
                ? null
                : new
                {
                    roundNumber = currentRound.RoundNumber,
                    resultStatus = currentRound.ResultStatus.ToString(),
                    isLocked = currentRound.IsLocked,
                    isVerified = currentRound.IsVerified,
                    openBoards = currentDiagnostics?.OpenBoards ?? currentRound.Pairings.Count(pairing => !pairing.IsBye && !pairing.Result.IsPlayed),
                    pairings = currentRound.Pairings.OrderBy(pairing => pairing.BoardNumber).Select(pairing => new
                    {
                        boardNumber = pairing.BoardNumber,
                        white = PlayerDisplay(players, pairing.WhitePlayerId),
                        black = pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId),
                        result = ResultLabel(pairing.Result.Kind),
                        isBye = pairing.IsBye,
                        isManualOverride = pairing.IsManualOverride,
                        chess960 = Chess960Display(pairing),
                        notes = pairing.Notes
                    })
                },
            roundDiagnostics = diagnostics.OrderBy(item => item.RoundNumber).Select(item => new
            {
                roundNumber = item.RoundNumber,
                isComplete = item.IsComplete,
                isLocked = item.IsLocked,
                isVerified = item.IsVerified,
                openBoards = item.OpenBoards,
                forfeitBoards = item.ForfeitBoards,
                byeBoards = item.ByeBoards,
                warnings = item.Warnings
            }),
            exportFiles = new
            {
                htmlPackage = "package/print/html",
                jsonPackage = "package/export.json",
                standingsCsv = "standings/export.csv",
                currentPairingsCsv = currentRound is null ? null : $"pairings/export.csv?roundNumber={currentRound.RoundNumber}",
                allPairingsCsv = "pairings/export.csv",
                backupJson = "export/json",
                auditBundleJsonl = "audit-journal/export.jsonl",
                spectatorView = "?view=public",
                beamerView = "?view=beamer"
            }
        };

        var json = JsonSerializer.Serialize(payload, new JsonSerializerOptions { WriteIndented = true });
        return JsonDocument($"{SafeFileName(tournament.Name)}_Turnierpaket.json", json);
    }

    public ExportDocument ExportNextRoundPreviewCsv(TournamentState tournament, NextRoundPreview preview)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Runde;Brett;Weiß;Schwarz;Weiß Punkte vorher;Schwarz Punkte vorher;Score-Differenz;Bye;Rematch;Scoregruppen-Abweichung;Farbfolge-Risiko;Hinweise");
        foreach (var board in preview.PairingQuality.Boards.OrderBy(b => b.BoardNumber))
        {
            var hasColorRisk = board.WouldGiveWhiteThirdSameColor || board.WouldGiveBlackThirdSameColor;
            var values = new[]
            {
                preview.RoundNumber.ToString(CultureInfo.InvariantCulture),
                board.BoardNumber.ToString(CultureInfo.InvariantCulture),
                board.WhiteName,
                board.IsBye ? "spielfrei" : board.BlackName,
                FormatDecimal(board.WhiteScoreBeforeRound),
                board.IsBye ? string.Empty : FormatDecimal(board.BlackScoreBeforeRound),
                board.IsBye ? string.Empty : FormatDecimal(board.ScoreDifference),
                board.IsBye ? "ja" : "nein",
                board.IsRematch ? "ja" : "nein",
                board.IsCrossScoreGroupPairing ? "ja" : "nein",
                hasColorRisk ? "ja" : "nein",
                string.Join(" | ", board.Findings)
            };
            builder.AppendLine(string.Join(';', values.Select(EscapeCsv)));
        }

        return CsvDocument($"{SafeFileName(tournament.Name)}_Vorschau_Runde_{preview.RoundNumber:D2}.csv", builder.ToString());
    }

    public ExportDocument ExportPrintableNextRoundPreviewHtml(TournamentState tournament, NextRoundPreview preview)
    {
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, $"Auslosungsvorschau Runde {preview.RoundNumber}");
        builder.AppendLine($"<h1>{Html(tournament.Name)} · Auslosungsvorschau Runde {preview.RoundNumber}</h1>");
        builder.AppendLine("<p class=\"muted\">Diese Vorschau wurde nicht gespeichert. Erst die echte Auslosung übernimmt die Paarungen ins Turnier.</p>");
        AppendPreviewSummary(builder, preview);
        AppendPreviewPairings(builder, preview);
        AppendPreviewAudit(builder, preview);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Vorschau_Runde_{preview.RoundNumber:D2}.html", builder.ToString());
    }

    private static void AppendPreviewSummary(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Qualität</h2>");
        builder.AppendLine("<dl>");
        builder.AppendLine($"<dt>Zusammenfassung</dt><dd>{Html(preview.Summary)}</dd>");
        builder.AppendLine($"<dt>Speicherbar</dt><dd>{(preview.IsSavable ? "ja" : "nein")}</dd>");
        builder.AppendLine($"<dt>Qualitätswert</dt><dd>{preview.PairingQuality.QualityScore}/100 · {Html(preview.PairingQuality.Severity.ToString())}</dd>");
        builder.AppendLine($"<dt>Bretter</dt><dd>{preview.BoardCount}</dd>");
        builder.AppendLine($"<dt>Rematches</dt><dd>{preview.PairingQuality.RematchCount}</dd>");
        builder.AppendLine($"<dt>Scoregruppen-Abweichungen</dt><dd>{preview.PairingQuality.CrossScoreGroupPairingCount}</dd>");
        builder.AppendLine($"<dt>Farbfolge-Risiken</dt><dd>{preview.PairingQuality.ThirdSameColorRiskCount}</dd>");
        builder.AppendLine($"<dt>Byes</dt><dd>{preview.PairingQuality.ByeCount}</dd>");
        builder.AppendLine("</dl>");
        if (preview.Messages.Count > 0 || preview.PairingQuality.Findings.Count > 0)
        {
            builder.AppendLine("<div class=\"diagnostics\"><strong>Hinweise:</strong><ul>");
            foreach (var message in preview.Messages.Concat(preview.PairingQuality.Findings).Distinct())
            {
                builder.AppendLine($"<li>{Html(message)}</li>");
            }
            builder.AppendLine("</ul></div>");
        }
        builder.AppendLine("</section>");
    }

    private static void AppendPreviewPairings(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Paarungen</h2><table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Score vor Runde</th><th>Hinweise</th></tr></thead><tbody>");
        foreach (var board in preview.PairingQuality.Boards.OrderBy(b => b.BoardNumber))
        {
            var score = board.IsBye ? "Bye" : $"{FormatDecimal(board.WhiteScoreBeforeRound)} : {FormatDecimal(board.BlackScoreBeforeRound)}";
            var notes = board.Findings.Count == 0 ? "ok" : string.Join(" | ", board.Findings);
            builder.Append("<tr>");
            builder.Append($"<td>{board.BoardNumber}</td>");
            builder.Append($"<td>{Html(board.WhiteName)}</td>");
            builder.Append($"<td>{Html(board.IsBye ? "spielfrei" : board.BlackName)}</td>");
            builder.Append($"<td>{Html(score)}</td>");
            builder.Append($"<td>{Html(notes)}</td>");
            builder.AppendLine("</tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendPreviewAudit(StringBuilder builder, NextRoundPreview preview)
    {
        builder.AppendLine("<section><h2>Audit</h2>");
        builder.AppendLine($"<p class=\"muted\">Algorithmus: {Html(preview.Round.Audit.Algorithm)} · Ruleset: {Html(preview.Round.Audit.RulesetVersion)}</p>");
        AppendAuditList(builder, "Hinweise", preview.Round.Audit.Messages);
        AppendAuditList(builder, "Scoregruppen", preview.Round.Audit.ScoreGroups);
        AppendAuditList(builder, "Floater", preview.Round.Audit.Floaters);
        AppendAuditList(builder, "Farben", preview.Round.Audit.ColorNotes);
        builder.AppendLine("</section>");
    }

    private static void AppendAuditList(StringBuilder builder, string title, IReadOnlyList<string> items)
    {
        builder.AppendLine($"<h3>{Html(title)}</h3><ul>");
        if (items.Count == 0)
        {
            builder.AppendLine("<li>keine</li>");
        }
        else
        {
            foreach (var item in items)
            {
                builder.AppendLine($"<li>{Html(item)}</li>");
            }
        }
        builder.AppendLine("</ul>");
    }

    private static void AppendTournamentMeta(StringBuilder builder, TournamentState tournament)
    {
        builder.AppendLine("<section><h2>Turnierdaten</h2><dl>");
        builder.AppendLine($"<dt>Format</dt><dd>{Html(tournament.Settings.Format.ToString())}</dd>");
        builder.AppendLine($"<dt>Wertung</dt><dd>{Html(tournament.Settings.ScoringSystem.ToString())}</dd>");
        builder.AppendLine($"<dt>Teilnehmer</dt><dd>{tournament.Players.Count}</dd>");
        builder.AppendLine($"<dt>Runden</dt><dd>{tournament.Rounds.Count}</dd>");
        builder.AppendLine("</dl></section>");
    }

    private static void AppendPackageHints(StringBuilder builder, TournamentState tournament, TournamentRound? currentRound)
    {
        var currentRoundLabel = currentRound is null ? "noch keine Runde ausgelost" : $"Runde {currentRound.RoundNumber}";
        builder.AppendLine("<section><h2>Operator-Hinweise</h2>");
        builder.AppendLine("<div class=\"diagnostics\"><strong>Turnierpaket-Inhalt:</strong><ul>");
        builder.AppendLine("<li>Teilnehmerliste</li>");
        builder.AppendLine($"<li>Paarungen für {Html(currentRoundLabel)}</li>");
        builder.AppendLine("<li>Aktuelle Tabelle / Standings</li>");
        builder.AppendLine($"<li>Ergebnisbogen für {Html(currentRoundLabel)}</li>");
        builder.AppendLine("<li>Backup- und Audit-Erinnerung</li>");
        builder.AppendLine("</ul></div>");
        builder.AppendLine("<div class=\"diagnostics\"><strong>Backup:</strong> Vor Runde 1, nach jeder Runde und am Turnierende ein separates JSON-Backup exportieren. Dieses HTML-Paket ist ein Aushang-/Kontrollpaket und ersetzt kein Restore-Backup.</div>");
        builder.AppendLine("<div class=\"diagnostics\"><strong>Audit:</strong> Nach jeder Runde zusätzlich das Audit-Bundle exportieren, damit Paarungen, Korrekturen und Warnungen forensisch nachvollziehbar bleiben.</div>");
        builder.AppendLine("<div class=\"diagnostics\"><strong>Zuschauer/Beamer:</strong> Für Anzeige am Handy oder Beamer die lokale read-only Ansicht der WebApp nutzen. Operator-Ansicht nur auf vertrauenswürdigen lokalen Geräten öffnen.</div>");
        builder.AppendLine($"<p class=\"muted\">Geplante Runden: {tournament.Settings.PlannedRounds} · aktuelle Runde: {Html(currentRoundLabel)}</p>");
        builder.AppendLine("</section>");
    }

    private static void AppendPlayers(StringBuilder builder, TournamentState tournament)
    {
        builder.AppendLine("<section><h2>Teilnehmerliste</h2><table><thead><tr><th>Startnr.</th><th>Name</th><th>Verein</th><th>FIDE-ID</th><th>TWZ</th><th>Jg.</th><th>Alter</th><th>Status</th></tr></thead><tbody>");
        foreach (var player in tournament.Players.OrderBy(p => p.StartingRank).ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase))
        {
            builder.AppendLine($"<tr><td>{player.StartingRank}</td><td>{Html(player.Name)}</td><td>{Html(player.Club ?? string.Empty)}</td><td>{Html(player.FideId ?? string.Empty)}</td><td>{player.Twz(tournament.Settings.TwzSource)}</td><td>{Html(BirthYearLabel(player))}</td><td>{Html(ApproxAgeLabel(player))}</td><td>{Html(player.Status.ToString())}</td></tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendStandings(StringBuilder builder, IReadOnlyList<StandingRow> standings)
    {
        builder.AppendLine("<section><h2>Tabelle</h2><table><thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Schwarzsiege</th><th>Buchholz</th><th>BH Cut-1</th><th>BH Cut-2</th><th>Median</th><th>SB</th><th>Koya</th><th>Progressiv</th><th>TPR</th></tr></thead><tbody>");
        foreach (var row in standings)
        {
            builder.AppendLine($"<tr><td>{row.Rank}</td><td>{Html(row.Name)}</td><td>{FormatDecimal(row.Points)}</td><td>{row.Wins}</td><td>{row.BlackWins}</td><td>{FormatDecimal(row.Buchholz)}</td><td>{FormatDecimal(row.BuchholzCutOne)}</td><td>{FormatDecimal(row.BuchholzCutTwo)}</td><td>{FormatDecimal(row.MedianBuchholz)}</td><td>{FormatDecimal(row.SonnebornBerger)}</td><td>{FormatDecimal(row.KoyaScore)}</td><td>{FormatDecimal(row.ProgressiveScore)}</td><td>{(row.TournamentPerformance?.ToString(CultureInfo.InvariantCulture) ?? "—")}</td></tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendCurrentRoundSheet(StringBuilder builder, TournamentState tournament, TournamentRound? currentRound, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        builder.AppendLine("<section><h2>Ergebnisbogen / aktuelle Runde</h2>");
        if (currentRound is null)
        {
            builder.AppendLine("<div class=\"diagnostics\">Noch keine Runde ausgelost. Erst Teilnehmer prüfen, Vorschau erzeugen und Runde 1 auslosen.</div>");
            builder.AppendLine("</section>");
            return;
        }

        var players = tournament.Players.ToDictionary(p => p.Id, p => p);
        builder.AppendLine($"<h3>Runde {currentRound.RoundNumber}</h3>");
        builder.AppendLine("<table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Chess960</th><th>Ergebnis</th><th>Unterschrift / Notiz</th></tr></thead><tbody>");
        foreach (var pairing in currentRound.Pairings.OrderBy(p => p.BoardNumber))
        {
            builder.Append("<tr>");
            builder.Append($"<td>{pairing.BoardNumber}</td>");
            builder.Append($"<td>{Html(PlayerDisplay(players, pairing.WhitePlayerId))}</td>");
            builder.Append($"<td>{Html(pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId))}</td>");
            builder.Append($"<td>{Html(Chess960Display(pairing))}</td>");
            builder.Append($"<td class=\"result-cell\">{PrintResultCell(pairing)}</td>");
            builder.Append($"<td>{Html(pairing.Notes ?? string.Empty)}</td>");
            builder.AppendLine("</tr>");
        }
        builder.AppendLine("</tbody></table>");

        var diagnostic = diagnostics.FirstOrDefault(item => item.RoundNumber == currentRound.RoundNumber);
        if (diagnostic is not null)
        {
            AppendDiagnostics(builder, diagnostic);
        }

        builder.AppendLine("</section>");
    }

    private static void AppendRounds(StringBuilder builder, TournamentState tournament, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var players = tournament.Players.ToDictionary(p => p.Id, p => p);
        builder.AppendLine("<section><h2>Runden</h2>");
        foreach (var round in tournament.Rounds.OrderBy(r => r.RoundNumber))
        {
            builder.AppendLine($"<h3>Runde {round.RoundNumber} · {Html(round.ResultStatus.ToString())}</h3>");
            builder.AppendLine("<table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Chess960</th><th>Ergebnis</th></tr></thead><tbody>");
            foreach (var pairing in round.Pairings.OrderBy(p => p.BoardNumber))
            {
                builder.AppendLine($"<tr><td>{pairing.BoardNumber}</td><td>{Html(PlayerDisplay(players, pairing.WhitePlayerId))}</td><td>{Html(pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId))}</td><td>{Html(Chess960Display(pairing))}</td><td>{Html(ResultLabel(pairing.Result.Kind))}</td></tr>");
            }
            builder.AppendLine("</tbody></table>");
            var diagnostic = diagnostics.FirstOrDefault(d => d.RoundNumber == round.RoundNumber);
            if (diagnostic is not null)
            {
                AppendDiagnostics(builder, diagnostic);
            }
        }
        builder.AppendLine("</section>");
    }

    private static void AppendDiagnostics(StringBuilder builder, RoundDiagnostics diagnostics)
    {
        builder.AppendLine("<div class=\"diagnostics\">");
        builder.AppendLine($"<strong>Rundenprüfung:</strong> offen {diagnostics.OpenBoards}, kampflos {diagnostics.ForfeitBoards}, Byes {diagnostics.ByeBoards}");
        if (diagnostics.Warnings.Count > 0)
        {
            builder.AppendLine("<ul>");
            foreach (var message in diagnostics.Warnings)
            {
                builder.AppendLine($"<li>{Html(message)}</li>");
            }
            builder.AppendLine("</ul>");
        }
        builder.AppendLine("</div>");
    }

    private static void AppendHtmlStart(StringBuilder builder, string tournamentName, string title)
    {
        builder.AppendLine("<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">");
        builder.AppendLine($"<title>{Html(tournamentName)} · {Html(title)}</title>");
        builder.AppendLine("<style>body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#111827}h1,h2,h3{color:#111827}.muted{color:#64748b}table{border-collapse:collapse;width:100%;margin:12px 0 28px}th,td{border:1px solid #cbd5e1;padding:6px 8px;text-align:left}th{background:#e2e8f0}.diagnostics{background:#f8fafc;border:1px solid #cbd5e1;border-radius:8px;padding:10px 12px;margin:8px 0 24px}.result-cell{min-width:72px}dl{display:grid;grid-template-columns:160px 1fr;gap:4px 12px}@media print{body{margin:12mm}.diagnostics{break-inside:avoid}table{break-inside:auto}tr{break-inside:avoid}}</style>");
        builder.AppendLine("</head><body>");
    }

    private static void AppendHtmlEnd(StringBuilder builder)
    {
        builder.AppendLine("<footer class=\"muted\">Erzeugt mit SchachTurnierManager · lokale Druckansicht</footer>");
        builder.AppendLine("</body></html>");
    }


    private static object DownloadEntry(string key, string label, string path, string description) => new
    {
        key,
        label,
        method = "GET",
        path,
        description
    };

    private static ExportDocument CsvDocument(string fileName, string content) => new()
    {
        FileName = fileName,
        ContentType = "text/csv; charset=utf-8",
        Content = content
    };

    private static ExportDocument HtmlDocument(string fileName, string content) => new()
    {
        FileName = fileName,
        ContentType = "text/html; charset=utf-8",
        Content = content
    };

    private static ExportDocument JsonDocument(string fileName, string content) => new()
    {
        FileName = fileName,
        ContentType = "application/json; charset=utf-8",
        Content = content
    };

    private static TournamentRound? CurrentRound(TournamentState tournament)
    {
        return tournament.Rounds
            .OrderByDescending(round => round.RoundNumber)
            .FirstOrDefault();
    }

    private static string PlayerName(IReadOnlyDictionary<Guid, string> players, Guid? id)
    {
        return id is not null && players.TryGetValue(id.Value, out var name) ? name : string.Empty;
    }

    private static string PlayerDisplay(IReadOnlyDictionary<Guid, Player> players, Guid? id)
    {
        if (id is null || !players.TryGetValue(id.Value, out var player))
        {
            return string.Empty;
        }

        var twz = player.Twz(TwzSource.ManualThenDwzThenElo);
        return twz > 0 ? $"{player.Name} ({twz})" : player.Name;
    }

    private static string ResultLabel(GameResultKind kind)
    {
        return kind switch
        {
            GameResultKind.WhiteWin => "1-0",
            GameResultKind.Draw => "½-½",
            GameResultKind.BlackWin => "0-1",
            GameResultKind.WhiteForfeitWin => "+/-",
            GameResultKind.BlackForfeitWin => "-/+",
            GameResultKind.DoubleForfeit => "-/-",
            GameResultKind.Bye => "Bye",
            GameResultKind.ArmageddonWhiteWin => "Armageddon Weiß",
            GameResultKind.ArmageddonBlackWin => "Armageddon Schwarz",
            _ => "offen"
        };
    }

    private static string FormatDecimal(decimal value) => value.ToString("0.##", CultureInfo.InvariantCulture);

    private static string PrintedAtLabel() => DateTime.Now.ToString("dd.MM.yyyy HH:mm", CultureInfo.GetCultureInfo("de-DE"));

    private static string BirthYearLabel(Player player) => player.BirthYear?.ToString(CultureInfo.InvariantCulture) ?? string.Empty;

    private static string ApproxAgeLabel(Player player)
        => player.BirthYear is int year && year > 1900 && year <= DateTime.Now.Year
            ? $"ca. {DateTime.Now.Year - year}"
            : string.Empty;

    // Offene Bretter bekommen ein leeres, beschreibbares Feld, damit das gedruckte
    // Rundenblatt direkt am Brett von Hand ausgefüllt werden kann.
    private static string PrintResultCell(Pairing pairing)
        => pairing.Result.Kind == GameResultKind.NotPlayed && !pairing.IsBye
            ? "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
            : Html(ResultLabel(pairing.Result.Kind));

    private static string Chess960PositionLabel(Pairing pairing) => pairing.Chess960StartPosition?.WhiteBackRank ?? string.Empty;

    private static string Chess960PositionNumberLabel(Pairing pairing) => pairing.Chess960StartPosition?.PositionNumber.ToString(CultureInfo.InvariantCulture) ?? string.Empty;

    private static string Chess960Display(Pairing pairing)
    {
        return pairing.Chess960StartPosition is null
            ? string.Empty
            : $"{pairing.Chess960StartPosition.WhiteBackRank} (SP {pairing.Chess960StartPosition.PositionNumber})";
    }

    private static string SafeFileName(string value)
    {
        var invalid = Path.GetInvalidFileNameChars().ToHashSet();
        var safe = new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray()).Trim();
        return string.IsNullOrWhiteSpace(safe) ? "Turnier" : safe.Replace(' ', '_');
    }

    private static string EscapeCsv(string? value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return string.Empty;
        }

        var mustQuote = value.Contains(';') || value.Contains('"') || value.Contains('\n') || value.Contains('\r');
        var escaped = value.Replace("\"", "\"\"");
        return mustQuote ? $"\"{escaped}\"" : escaped;
    }

    private static string Html(string value) => WebUtility.HtmlEncode(value);
}
