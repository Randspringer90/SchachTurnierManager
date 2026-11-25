using System.Data;
using System.Globalization;
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

    public IReadOnlyList<TournamentSummary> ListSummaries()
    {
        // Columns only: the cost does not grow with tournament size, and a damaged
        // snapshot cannot make the whole list unavailable.
        return _dbContext.TournamentSnapshots
            .AsNoTracking()
            .OrderBy(x => x.CreatedOn)
            .ThenBy(x => x.Name)
            .Select(x => new { x.Id, x.Name, x.CreatedOn, x.UpdatedAt, x.Revision, x.Format, x.PlayerCount, x.RoundCount })
            .AsEnumerable()
            .Select(x => new TournamentSummary(
                x.Id,
                x.Name,
                DateOnly.TryParseExact(x.CreatedOn, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var createdOn)
                    ? createdOn
                    : DateOnly.MinValue,
                x.UpdatedAt,
                x.Revision,
                Enum.TryParse<TournamentFormat>(x.Format, ignoreCase: false, out var format) && Enum.IsDefined(format)
                    ? format
                    : default,
                x.PlayerCount,
                x.RoundCount))
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
        // The revision belongs to this database, never to the caller or to an imported backup.
        tournament.Revision = (existing?.Revision ?? 0) + 1;
        if (existing is null)
        {
            existing = new TournamentSnapshot { Id = tournament.Id };
            _dbContext.TournamentSnapshots.Add(existing);
        }

        Project(tournament, existing);
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

            // An idempotent retry must leave the row untouched, including revision and timestamp.
            tournament.Revision = snapshot.Revision;
            if (JsonSerializer.Serialize(tournament, JsonOptions) == snapshot.Json)
            {
                transaction.Commit();
                return result;
            }

            tournament.Revision = snapshot.Revision + 1;
            Project(tournament, snapshot);
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

    /// <summary>Writes the aggregate and its list columns into one row.</summary>
    private static void Project(TournamentState tournament, TournamentSnapshot snapshot)
    {
        snapshot.Name = tournament.Name;
        snapshot.CreatedOn = tournament.CreatedOn.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        snapshot.UpdatedAt = DateTimeOffset.UtcNow;
        snapshot.Revision = tournament.Revision;
        snapshot.PlayerCount = tournament.Players.Count;
        snapshot.RoundCount = tournament.Rounds.Count;
        snapshot.Format = tournament.Settings.Format.ToString();
        snapshot.Json = JsonSerializer.Serialize(tournament, JsonOptions);
    }

    private static TournamentState Deserialize(TournamentSnapshot snapshot)
    {
        try
        {
            var tournament = JsonSerializer.Deserialize<TournamentState>(snapshot.Json, JsonOptions)
                ?? throw new InvalidOperationException($"Turnier {snapshot.Id} konnte nicht deserialisiert werden.");
            // The column is authoritative; migrated legacy snapshots carry no revision in their JSON.
            tournament.Revision = snapshot.Revision;
            return tournament;
        }
        catch (JsonException ex)
        {
            throw new InvalidOperationException($"Persistiertes Turnier {snapshot.Id} ist beschädigt.", ex);
        }
    }
}
