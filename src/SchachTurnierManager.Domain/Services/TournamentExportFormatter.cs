using System.Globalization;
using System.Net;
using System.Text;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

public sealed class TournamentExportFormatter
{
    public ExportDocument ExportStandingsCsv(TournamentState tournament, IReadOnlyList<StandingRow> standings)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Rang;Name;TWZ;Punkte;Siege;Direktvergleich;Buchholz;Buchholz Cut-1;Sonneborn-Berger;Gegnerschnitt;TPR;Heldenwert");
        foreach (var row in standings)
        {
            var values = new[]
            {
                row.Rank.ToString(CultureInfo.InvariantCulture),
                row.Name,
                row.Twz.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.Points),
                row.Wins.ToString(CultureInfo.InvariantCulture),
                FormatDecimal(row.DirectEncounter),
                FormatDecimal(row.Buchholz),
                FormatDecimal(row.BuchholzCutOne),
                FormatDecimal(row.SonnebornBerger),
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
        builder.AppendLine("Runde;Brett;Weiß;Schwarz;Ergebnis;Status;Hinweise");
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
                    round.ResultStatus.ToString(),
                    pairing.Notes ?? string.Empty
                };
                builder.AppendLine(string.Join(';', values.Select(EscapeCsv)));
            }
        }

        var suffix = roundNumber is null ? "Paarungen" : $"Runde_{roundNumber.Value:D2}";
        return CsvDocument($"{SafeFileName(tournament.Name)}_{suffix}.csv", builder.ToString());
    }

    public ExportDocument ExportPrintableTournamentHtml(TournamentState tournament, IReadOnlyList<StandingRow> standings, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var builder = new StringBuilder();
        AppendHtmlStart(builder, tournament.Name, "Turnierbericht");
        builder.AppendLine($"<h1>{Html(tournament.Name)}</h1>");
        builder.AppendLine("<p class=\"muted\">Druckansicht mit Teilnehmerliste, Tabelle, Runden, Paarungen und Prüfhinweisen.</p>");
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
        builder.AppendLine($"<p class=\"muted\">Rundenblatt für Aushang, Ergebniserfassung oder Kontrolle.</p>");
        builder.AppendLine("<table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Ergebnis</th><th>Hinweise</th></tr></thead><tbody>");
        foreach (var pairing in round.Pairings.OrderBy(p => p.BoardNumber))
        {
            builder.Append("<tr>");
            builder.Append($"<td>{pairing.BoardNumber}</td>");
            builder.Append($"<td>{Html(PlayerDisplay(players, pairing.WhitePlayerId))}</td>");
            builder.Append($"<td>{Html(pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId))}</td>");
            builder.Append($"<td>{Html(ResultLabel(pairing.Result.Kind))}</td>");
            builder.Append($"<td>{Html(pairing.Notes ?? string.Empty)}</td>");
            builder.AppendLine("</tr>");
        }
        builder.AppendLine("</tbody></table>");
        AppendDiagnostics(builder, diagnostics);
        AppendHtmlEnd(builder);
        return HtmlDocument($"{SafeFileName(tournament.Name)}_Runde_{round.RoundNumber:D2}.html", builder.ToString());
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

    private static void AppendPlayers(StringBuilder builder, TournamentState tournament)
    {
        builder.AppendLine("<section><h2>Teilnehmerliste</h2><table><thead><tr><th>Startnr.</th><th>Name</th><th>Verein</th><th>TWZ</th><th>Status</th></tr></thead><tbody>");
        foreach (var player in tournament.Players.OrderBy(p => p.StartingRank).ThenBy(p => p.Name, StringComparer.OrdinalIgnoreCase))
        {
            builder.AppendLine($"<tr><td>{player.StartingRank}</td><td>{Html(player.Name)}</td><td>{Html(player.Club ?? string.Empty)}</td><td>{player.Twz(tournament.Settings.TwzSource)}</td><td>{Html(player.Status.ToString())}</td></tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendStandings(StringBuilder builder, IReadOnlyList<StandingRow> standings)
    {
        builder.AppendLine("<section><h2>Tabelle</h2><table><thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>Buchholz</th><th>SB</th><th>TPR</th></tr></thead><tbody>");
        foreach (var row in standings)
        {
            builder.AppendLine($"<tr><td>{row.Rank}</td><td>{Html(row.Name)}</td><td>{FormatDecimal(row.Points)}</td><td>{row.Wins}</td><td>{FormatDecimal(row.Buchholz)}</td><td>{FormatDecimal(row.SonnebornBerger)}</td><td>{(row.TournamentPerformance?.ToString(CultureInfo.InvariantCulture) ?? "—")}</td></tr>");
        }
        builder.AppendLine("</tbody></table></section>");
    }

    private static void AppendRounds(StringBuilder builder, TournamentState tournament, IReadOnlyList<RoundDiagnostics> diagnostics)
    {
        var players = tournament.Players.ToDictionary(p => p.Id, p => p);
        builder.AppendLine("<section><h2>Runden</h2>");
        foreach (var round in tournament.Rounds.OrderBy(r => r.RoundNumber))
        {
            builder.AppendLine($"<h3>Runde {round.RoundNumber} · {Html(round.ResultStatus.ToString())}</h3>");
            builder.AppendLine("<table><thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Ergebnis</th></tr></thead><tbody>");
            foreach (var pairing in round.Pairings.OrderBy(p => p.BoardNumber))
            {
                builder.AppendLine($"<tr><td>{pairing.BoardNumber}</td><td>{Html(PlayerDisplay(players, pairing.WhitePlayerId))}</td><td>{Html(pairing.IsBye ? "spielfrei" : PlayerDisplay(players, pairing.BlackPlayerId))}</td><td>{Html(ResultLabel(pairing.Result.Kind))}</td></tr>");
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
        if (diagnostics.Messages.Count > 0)
        {
            builder.AppendLine("<ul>");
            foreach (var message in diagnostics.Messages)
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
        builder.AppendLine("<style>body{font-family:Segoe UI,Arial,sans-serif;margin:32px;color:#111827}h1,h2,h3{color:#111827}.muted{color:#64748b}table{border-collapse:collapse;width:100%;margin:12px 0 28px}th,td{border:1px solid #cbd5e1;padding:6px 8px;text-align:left}th{background:#e2e8f0}.diagnostics{background:#f8fafc;border:1px solid #cbd5e1;border-radius:8px;padding:10px 12px;margin:8px 0 24px}dl{display:grid;grid-template-columns:160px 1fr;gap:4px 12px}@media print{body{margin:12mm}.diagnostics{break-inside:avoid}table{break-inside:auto}tr{break-inside:avoid}}</style>");
        builder.AppendLine("</head><body>");
    }

    private static void AppendHtmlEnd(StringBuilder builder)
    {
        builder.AppendLine("<footer class=\"muted\">Erzeugt mit SchachTurnierManager · lokale Druckansicht</footer>");
        builder.AppendLine("</body></html>");
    }

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
