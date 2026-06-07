using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;
using SchachTurnierManager.WebApi;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<ITournamentStore, InMemoryTournamentStore>();
builder.Services.AddSingleton<TournamentService>();
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy
        .AllowAnyHeader()
        .AllowAnyMethod()
        .WithOrigins("http://localhost:5173", "https://localhost:5173"));
});

var app = builder.Build();
app.UseCors();

app.MapGet("/api/health", () => Results.Ok(new
{
    status = "ok",
    app = "SchachTurnierManager",
    version = "0.1.0",
    time = DateTimeOffset.UtcNow
}));

app.MapGet("/api/tournaments", (TournamentService service) => Results.Ok(service.ListTournaments()));

app.MapPost("/api/tournaments", (CreateTournamentRequest request, TournamentService service) =>
{
    var created = service.CreateTournament(request.Name, request.Settings);
    return Results.Created($"/api/tournaments/{created.Id}", created);
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

app.MapPost("/api/tournaments/{id:guid}/players", (Guid id, AddPlayerRequest request, TournamentService service) =>
{
    try
    {
        var player = new Player
        {
            Name = request.Name,
            Club = request.Club,
            BirthYear = request.BirthYear,
            Gender = request.Gender,
            FideId = request.FideId,
            Title = request.Title,
            Rating = new RatingProfile
            {
                Elo = request.Elo,
                Dwz = request.Dwz,
                ManualTwz = request.ManualTwz
            }
        };
        return Results.Ok(service.AddPlayer(id, player));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
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

app.Run();
