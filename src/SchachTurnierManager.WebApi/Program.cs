using System.Text;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SchachTurnierManager.Application;
using SchachTurnierManager.Application.Ai;
using SchachTurnierManager.Application.External;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure;
using SchachTurnierManager.Infrastructure.Persistence;
using SchachTurnierManager.Infrastructure.External;
using SchachTurnierManager.WebApi;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

var configuredConnectionString = builder.Configuration.GetConnectionString("SchachTurnierManager");
string connectionString;
string databaseHealthLabel;
string databaseFullPath;
string auditDirectory;
var defaultDataDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SchachTurnierManager");
if (string.IsNullOrWhiteSpace(configuredConnectionString))
{
    var dataDirectory = builder.Configuration["SchachTurnierManager:DataDirectory"] ?? defaultDataDirectory;
    Directory.CreateDirectory(dataDirectory);
    var databasePath = Path.Combine(dataDirectory, "SchachTurnierManager.sqlite");
    connectionString = $"Data Source={databasePath}";
    databaseHealthLabel = Path.GetFileName(databasePath);
    databaseFullPath = databasePath;
    auditDirectory = Path.Combine(dataDirectory, "audit");
}
else
{
    connectionString = configuredConnectionString;
    databaseHealthLabel = "custom connection";
    databaseFullPath = "custom connection";
    auditDirectory = Path.Combine(defaultDataDirectory, "audit");
}

builder.Services.AddSchachTurnierPersistence(connectionString);
builder.Services.AddFileAuditJournalSink(auditDirectory);
builder.Services.AddExternalPlayerLookupAdapters();
builder.Services.AddSingleton(CreateAiHelpProvider(builder.Configuration));
builder.Services.AddScoped<TournamentService>();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy
        .AllowAnyHeader()
        .AllowAnyMethod()
        .WithOrigins("http://localhost:5173", "https://localhost:5173", "http://127.0.0.1:5173"));
});

var app = builder.Build();

var webRootPath = app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot");
var embeddedDashboardAvailable = File.Exists(Path.Combine(webRootPath, "index.html"));

var startupLogger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Startup");
var usesFileDatabase = !string.Equals(databaseFullPath, "custom connection", StringComparison.Ordinal);
if (usesFileDatabase)
{
    var probe = DatabaseStartupDiagnostics.Probe(databaseFullPath);
    if (!probe.IsHealthy)
    {
        var report = DatabaseStartupDiagnostics.BuildFailureReport(databaseFullPath, probe);
        startupLogger.LogCritical("{Report}", report);
        Console.Error.WriteLine(report);
        Environment.Exit(2);
        return;
    }
}

try
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<TournamentDbContext>();
    db.Database.EnsureCreated();
}
catch (Exception ex)
{
    // Klassisch: "SQLite Error 10: 'disk I/O error'" beim WAL-Pragma. Statt Stacktrace einen
    // verständlichen, handlungsorientierten Hinweis ausgeben und sauber mit Fehlercode beenden,
    // damit das Startskript die Lage erkennt.
    var probe = usesFileDatabase ? DatabaseStartupDiagnostics.Probe(databaseFullPath) : new DatabaseProbeResult
    {
        DatabasePath = databaseFullPath,
        Directory = databaseFullPath,
        DirectoryExists = true,
        DirectoryWritable = true
    };
    var report = DatabaseStartupDiagnostics.BuildFailureReport(databaseFullPath, probe, ex.Message);
    startupLogger.LogCritical(ex, "{Report}", report);
    Console.Error.WriteLine(report);
    Environment.Exit(2);
    return;
}

app.UseCors();

if (embeddedDashboardAvailable)
{
    app.UseDefaultFiles();
    app.UseStaticFiles();
}
else
{
    app.MapGet("/", () => Results.Content("""
        <!doctype html>
        <html lang="de">
        <head><meta charset="utf-8"><title>SchachTurnierManager</title></head>
        <body style="font-family: system-ui, sans-serif; margin: 2rem;">
          <h1>SchachTurnierManager API</h1>
          <p>Das eingebettete Dashboard wurde in diesem Startmodus nicht gefunden.</p>
          <p>Entwicklung: <code>scripts\Start-Dev.ps1</code> starten.</p>
          <p>Portable Paket: <code>scripts\Pack-Portable.ps1</code> erzeugen und dann <code>Start-SchachTurnierManager.bat</code> verwenden.</p>
          <p><a href="/api/health">API-Healthcheck öffnen</a></p>
        </body>
        </html>
        """, "text/html; charset=utf-8"));
}

app.MapGet("/api/health", () => Results.Ok(new
{
    status = "ok",
    app = "SchachTurnierManager",
    version = "0.44.0",
    time = DateTimeOffset.UtcNow,
    database = databaseHealthLabel,
    databasePath = databaseFullPath,
    embeddedDashboard = embeddedDashboardAvailable
}));

app.MapGet("/api/help/assistant", (IAiHelpProvider provider) => Results.Ok(provider.GetStatus()));

app.MapPost("/api/help/assistant/ask", async (AiHelpRequest request, IAiHelpProvider provider, CancellationToken cancellationToken) =>
{
    var status = provider.GetStatus();
    try
    {
        return Results.Ok(await provider.AskAsync(request, cancellationToken));
    }
    catch (Exception ex)
    {
        return Results.Ok(new AiHelpResponse(
            IsConfigured: false,
            Mode: status.Mode,
            Provider: status.Provider,
            Answer: DisabledAiHelpProvider.NotConfiguredMessage,
            Citations: [],
            Warnings: [$"Provider-Fehler: {ex.Message}", DisabledAiHelpProvider.NotConfiguredMessage],
            Topics: status.Topics));
    }
});


app.MapGet("/api/external-players/providers", (ExternalPlayerLookupService service) => Results.Ok(service.Providers));

app.MapGet("/api/external-players/search", async (string? source, string? query, ExternalPlayerLookupService service, CancellationToken cancellationToken) =>
{
    if (!TryParseExternalPlayerSource(source, out var parsedSource))
    {
        return Results.BadRequest(new { error = $"Unbekannte Quelle: {source ?? "<leer>"}." });
    }

    var result = await service.SearchAsync(parsedSource, query ?? string.Empty, cancellationToken);
    return Results.Ok(result);
});

app.MapGet("/api/external-players/search-all", async (string? query, ExternalPlayerLookupService service, CancellationToken cancellationToken) =>
{
    var result = await service.SearchAllAsync(query ?? string.Empty, cancellationToken);
    return Results.Ok(result);
});

app.MapGet("/api/external-players/fide/{fideId}", async (string fideId, ExternalPlayerLookupService service, CancellationToken cancellationToken) =>
{
    var result = await service.LookupByIdAsync(ExternalPlayerSource.Fide, fideId, cancellationToken);
    return Results.Ok(result);
});

app.MapPost("/api/tournaments/{id:guid}/external-players/check-duplicates", (Guid id, ExternalPlayerDuplicateRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.CheckExternalPlayerDuplicates(id, request.Profile));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/external-players/apply", (Guid id, ApplyExternalPlayerRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.ApplyExternalPlayer(id, request.Profile, request.TargetPlayerId, request.CreateIfNoTarget, request.OverwriteExistingValues));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments", (TournamentService service) => Results.Ok(service.ListTournaments()));

app.MapPost("/api/tournaments", (CreateTournamentRequest request, TournamentService service) =>
{
    try
    {
        var created = service.CreateTournament(request.Name, request.Settings);
        return Results.Created($"/api/tournaments/{created.Id}", created);
    }
    catch (ArgumentException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RequireTournament(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapDelete("/api/tournaments/{id:guid}", (Guid id, TournamentService service) =>
{
    if (!service.DeleteTournament(id))
    {
        return Results.NotFound(new { error = $"Turnier {id} wurde nicht gefunden." });
    }

    return Results.Ok(new { deleted = true, id });
});

app.MapPost("/api/tournaments/{id:guid}/reset", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.ResetTournament(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapPut("/api/tournaments/{id:guid}/settings", (Guid id, UpdateTournamentSettingsRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.UpdateSettings(id, request.Settings));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/import", (ImportTournamentRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.SaveImportedTournament(request.Tournament, request.OverwriteExisting));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/export/json", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Json(service.RequireTournament(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/players", (Guid id, PlayerRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.AddPlayer(id, request.ToPlayer()));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPut("/api/tournaments/{id:guid}/players/{playerId:guid}", (Guid id, Guid playerId, PlayerRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.UpdatePlayer(id, playerId, request.ToPlayer(playerId)));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPatch("/api/tournaments/{id:guid}/players/{playerId:guid}/status", (Guid id, Guid playerId, UpdatePlayerStatusRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.SetPlayerStatus(id, playerId, request.Status));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapDelete("/api/tournaments/{id:guid}/players/{playerId:guid}", (Guid id, Guid playerId, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RemovePlayer(id, playerId));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/players/export.csv", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Text(service.ExportPlayersCsv(id), "text/csv; charset=utf-8");
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/players/preview-import.csv", (Guid id, PreviewPlayersCsvRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.PreviewPlayersCsv(id, request.Content, request.ReplaceExisting));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
app.MapPost("/api/tournaments/{id:guid}/players/import.csv", (Guid id, ImportPlayersCsvRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.ImportPlayersCsv(id, request.Content, request.ReplaceExisting));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/pairings/preview-next-round", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.PreviewNextRound(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});
app.MapGet("/api/tournaments/{id:guid}/pairings/preview-next-round/export.csv", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportNextRoundPreviewCsv(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/pairings/preview-next-round/print/html", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPrintableNextRoundPreviewHtml(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/pairings/next-round", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GenerateNextRound(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/rounds/generate", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GenerateNextRound(id));
    }
    catch (Exception ex) when (ex is InvalidOperationException or NotSupportedException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/results", (Guid id, RecordBoardResultRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RecordResult(id, request.RoundNumber, request.BoardNumber, request.Result));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/boards/{boardNumber:int}/result", (Guid id, int roundNumber, int boardNumber, RecordResultRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RecordResult(id, roundNumber, boardNumber, request.Result));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPut("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/boards/{boardNumber:int}/pairing", (Guid id, int roundNumber, int boardNumber, OverridePairingRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.OverridePairing(id, roundNumber, boardNumber, request.WhitePlayerId, request.BlackPlayerId, request.Notes));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/chess960/start-positions", (Guid id, int roundNumber, RollChess960StartPositionsRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RollChess960StartPositions(id, roundNumber, request.OverwriteExisting, request.Seed));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPost("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/chess960/start-positions/{boardNumber:int}", (Guid id, int roundNumber, int boardNumber, RollChess960StartPositionForBoardRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.RollChess960StartPositionForBoard(id, roundNumber, boardNumber, request.OverwriteExisting, request.Seed, request.PositionNumber));
    }
    catch (ArgumentOutOfRangeException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPatch("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/lock", (Guid id, int roundNumber, UpdateRoundLockRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.SetRoundLock(id, roundNumber, request.IsLocked));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapPatch("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/verify", (Guid id, int roundNumber, UpdateRoundVerifiedRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.SetRoundVerified(id, roundNumber, request.IsVerified));
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/standings", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetStandings(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/cross-table", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetCrossTable(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/categories", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetCategoryStandings(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/hero-cup", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetHeroCup(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/audit", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetAudit(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/audit-journal", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetAuditJournal(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});


app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", (Guid id, HttpRequest request, TournamentService service) =>
{
    try
    {
        var queryValues = request.Query;

        AuditJournalSeverity? severity = null;
        if (queryValues.TryGetValue("severity", out var severityValues) && !string.IsNullOrWhiteSpace(severityValues.ToString()))
        {
            var severityText = severityValues.ToString();
            if (!Enum.TryParse<AuditJournalSeverity>(severityText, ignoreCase: true, out var parsedSeverity))
            {
                return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severityText}." });
            }

            severity = parsedSeverity;
        }

        AuditJournalAction? action = null;
        if (queryValues.TryGetValue("action", out var actionValues) && !string.IsNullOrWhiteSpace(actionValues.ToString()))
        {
            var actionText = actionValues.ToString();
            if (!Enum.TryParse<AuditJournalAction>(actionText, ignoreCase: true, out var parsedAction))
            {
                return Results.BadRequest(new { error = $"Unbekannte Audit-Aktion: {actionText}." });
            }

            action = parsedAction;
        }

        int? roundNumber = null;
        if (queryValues.TryGetValue("roundNumber", out var roundNumberValues) && int.TryParse(roundNumberValues.ToString(), out var parsedRoundNumber))
        {
            roundNumber = parsedRoundNumber;
        }

        int? boardNumber = null;
        if (queryValues.TryGetValue("boardNumber", out var boardNumberValues) && int.TryParse(boardNumberValues.ToString(), out var parsedBoardNumber))
        {
            boardNumber = parsedBoardNumber;
        }

        int? maxResults = null;
        if (queryValues.TryGetValue("maxResults", out var maxResultsValues) && int.TryParse(maxResultsValues.ToString(), out var parsedMaxResults))
        {
            maxResults = parsedMaxResults;
        }

        Guid? playerId = null;
        if (queryValues.TryGetValue("playerId", out var playerIdValues) && Guid.TryParse(playerIdValues.ToString(), out var parsedPlayerId))
        {
            playerId = parsedPlayerId;
        }

        var searchText = queryValues.TryGetValue("search", out var searchValues) ? searchValues.ToString() : null;
        var sortText = queryValues.TryGetValue("sort", out var sortValues) ? sortValues.ToString() : null;
        var sortDirection = string.Equals(sortText, "oldest", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "asc", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "oldestFirst", StringComparison.OrdinalIgnoreCase)
                ? SchachTurnierManager.Domain.Services.AuditJournalSortDirection.OldestFirst
                : SchachTurnierManager.Domain.Services.AuditJournalSortDirection.NewestFirst;

        var query = new SchachTurnierManager.Domain.Services.AuditJournalQuery
        {
            Severity = severity,
            Action = action,
            RoundNumber = roundNumber,
            BoardNumber = boardNumber,
            PlayerId = playerId,
            SearchText = searchText,
            MaxResults = maxResults,
            SortDirection = sortDirection
        };

        var result = new SchachTurnierManager.Domain.Services.AuditJournalQueryService().Query(service.GetAuditJournal(id), query);
        return Results.Ok(result);
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/audit-journal/export.jsonl", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportAuditJournalJsonl(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/audit-journal/export.json", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportAuditJournalJson(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/round-diagnostics", (Guid id, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetRoundDiagnostics(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/diagnostics", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetRoundDiagnostics(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/pairing-quality", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.GetPairingQuality(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/standings/export.csv", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportStandingsCsv(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/pairings/export.csv", (Guid id, int? roundNumber, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPairingsCsv(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/print/html", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPrintableTournamentHtml(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/package/print/html", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPrintableTournamentPackageHtml(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/package/export.json", (Guid id, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportTournamentPackageJson(id));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

app.MapGet("/api/tournaments/{id:guid}/rounds/{roundNumber:int}/print/html", (Guid id, int roundNumber, TournamentService service) =>
{
    try
    {
        return ToDownload(service.ExportPrintableRoundHtml(id, roundNumber));
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

if (embeddedDashboardAvailable)
{
    app.MapFallbackToFile("index.html");
}

app.Run();


static bool TryParseExternalPlayerSource(string? value, out ExternalPlayerSource source)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        source = ExternalPlayerSource.Fide;
        return true;
    }

    if (int.TryParse(value, out var numeric) && Enum.IsDefined(typeof(ExternalPlayerSource), numeric))
    {
        source = (ExternalPlayerSource)numeric;
        return true;
    }

    return Enum.TryParse(value, ignoreCase: true, out source);
}

static IAiHelpProvider CreateAiHelpProvider(IConfiguration configuration)
{
    var enabled = bool.TryParse(configuration["STM_AI_HELP_ENABLED"], out var parsedEnabled) && parsedEnabled;
    var provider = configuration["STM_AI_PROVIDER"]?.Trim() ?? "disabled";
    var normalizedProvider = provider.ToLowerInvariant();

    if (enabled && (normalizedProvider is "local-docs" or "localdocs" or "docs"))
    {
        return new LocalDocsAiHelpProvider();
    }

    return new DisabledAiHelpProvider(provider);
}

static IResult ToDownload(ExportDocument document)
{
    return Results.File(Encoding.UTF8.GetBytes(document.Content), document.ContentType, document.FileName);
}
