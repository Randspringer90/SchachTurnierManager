using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using SchachTurnierManager.Application;
using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Infrastructure.Persistence;

public sealed class SqliteTournamentStore(TournamentDbContext dbContext) : ITournamentStore
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly TournamentDbContext _dbContext = dbContext;

    public IReadOnlyList<TournamentState> List()
    {
        return _dbContext.TournamentSnapshots
            .AsNoTracking()
            .OrderBy(x => x.CreatedOn)
            .ThenBy(x => x.Name)
            .AsEnumerable()
            .Select(Deserialize)
            .ToList();
    }

    public TournamentState? Get(Guid id)
    {
        var snapshot = _dbContext.TournamentSnapshots.AsNoTracking().SingleOrDefault(x => x.Id == id);
        return snapshot is null ? null : Deserialize(snapshot);
    }

    public void Save(TournamentState tournament)
    {
        var existing = _dbContext.TournamentSnapshots.SingleOrDefault(x => x.Id == tournament.Id);
        var json = JsonSerializer.Serialize(tournament, JsonOptions);
        if (existing is null)
        {
            _dbContext.TournamentSnapshots.Add(new TournamentSnapshot
            {
                Id = tournament.Id,
                Name = tournament.Name,
                CreatedOn = tournament.CreatedOn.ToString("yyyy-MM-dd"),
                UpdatedAt = DateTimeOffset.UtcNow,
                Json = json
            });
        }
        else
        {
            existing.Name = tournament.Name;
            existing.CreatedOn = tournament.CreatedOn.ToString("yyyy-MM-dd");
            existing.UpdatedAt = DateTimeOffset.UtcNow;
            existing.Json = json;
        }

        _dbContext.SaveChanges();
    }

    private static TournamentState Deserialize(TournamentSnapshot snapshot)
    {
        try
        {
            return JsonSerializer.Deserialize<TournamentState>(snapshot.Json, JsonOptions)
                ?? throw new InvalidOperationException($"Turnier {snapshot.Id} konnte nicht deserialisiert werden.");
        }
        catch (JsonException ex)
        {
            throw new InvalidOperationException($"Persistiertes Turnier {snapshot.Id} ist beschädigt.", ex);
        }
    }
}
