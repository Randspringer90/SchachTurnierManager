using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.Infrastructure;
using SchachTurnierManager.Infrastructure.Persistence;
using SchachTurnierManager.WebApi;

var builder = WebApplication.CreateBuilder(args);

var dataDirectory = builder.Configuration["SchachTurnierManager:DataDirectory"]
    ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SchachTurnierManager");
Directory.CreateDirectory(dataDirectory);
var databasePath = Path.Combine(dataDirectory, "SchachTurnierManager.sqlite");
var connectionString = builder.Configuration.GetConnectionString("SchachTurnierManager")
    ?? $"Data Source={databasePath}";

builder.Services.AddSchachTurnierPersistence(connectionString);
builder.Services.AddScoped<TournamentService>();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy
        .AllowAnyHeader()
        .AllowAnyMethod()
        .WithOrigins("http://localhost:5173", "https://localhost:5173"));
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<TournamentDbContext>();
    db.Database.EnsureCreated();
}

app.UseCors();

app.MapGet("/api/health", () => Results.Ok(new
{
    status = "ok",
    app = "SchachTurnierManager",
    version = "0.2.0",
    time = DateTimeOffset.UtcNow,
    database = databasePath
}));

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

app.Run();

public sealed record RecordBoardResultRequest(int RoundNumber, int BoardNumber, GameResultKind Result);
