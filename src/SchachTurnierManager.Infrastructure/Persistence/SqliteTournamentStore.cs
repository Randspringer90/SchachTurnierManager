using System.Data;
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

    public void Save(TournamentState tournament, bool overwriteExisting = true)
    {
        using var transaction = _dbContext.Database.BeginTransaction(IsolationLevel.Serializable);
        _dbContext.ChangeTracker.Clear();
        var existing = _dbContext.TournamentSnapshots.SingleOrDefault(x => x.Id == tournament.Id);
        if (!overwriteExisting && existing is not null)
            throw new InvalidOperationException($"Turnier {tournament.Id} existiert bereits.");
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
        transaction.Commit();
    }

    public TResult UpdateAtomically<TResult>(Guid id, Func<TournamentState, TResult> update)
    {
        ArgumentNullException.ThrowIfNull(update);
        using var transaction = _dbContext.Database.BeginTransaction(IsolationLevel.Serializable);
        try
        {
            _dbContext.ChangeTracker.Clear();
            var snapshot = _dbContext.TournamentSnapshots.SingleOrDefault(x => x.Id == id)
                ?? throw new InvalidOperationException($"Turnier {id} wurde nicht gefunden.");
            var tournament = Deserialize(snapshot);
            var result = update(tournament);

            snapshot.Name = tournament.Name;
            snapshot.CreatedOn = tournament.CreatedOn.ToString("yyyy-MM-dd");
            snapshot.UpdatedAt = DateTimeOffset.UtcNow;
            snapshot.Json = JsonSerializer.Serialize(tournament, JsonOptions);
            _dbContext.SaveChanges();
            transaction.Commit();
            return result;
        }
        catch
        {
            transaction.Rollback();
            throw;
        }
    }


    public bool Delete(Guid id, Action<TournamentState>? beforeDelete = null)
    {
        using var transaction = _dbContext.Database.BeginTransaction(IsolationLevel.Serializable);
        _dbContext.ChangeTracker.Clear();
        var existing = _dbContext.TournamentSnapshots.SingleOrDefault(x => x.Id == id);
        if (existing is null)
        {
            return false;
        }

        beforeDelete?.Invoke(Deserialize(existing));
        _dbContext.TournamentSnapshots.Remove(existing);
        _dbContext.SaveChanges();
        transaction.Commit();
        return true;
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
