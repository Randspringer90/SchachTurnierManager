using Microsoft.EntityFrameworkCore;

namespace SchachTurnierManager.Infrastructure.Persistence;

public sealed class TournamentDbContext(DbContextOptions<TournamentDbContext> options) : DbContext(options)
{
    public DbSet<TournamentSnapshot> TournamentSnapshots => Set<TournamentSnapshot>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var entity = modelBuilder.Entity<TournamentSnapshot>();
        entity.ToTable("tournament_snapshots");
        entity.HasKey(x => x.Id);
        entity.Property(x => x.Name).HasMaxLength(240).IsRequired();
        entity.Property(x => x.CreatedOn).HasMaxLength(16).IsRequired();
        entity.Property(x => x.UpdatedAt).IsRequired();
        entity.Property(x => x.Json).IsRequired();
        entity.HasIndex(x => x.Name);
    }
}
