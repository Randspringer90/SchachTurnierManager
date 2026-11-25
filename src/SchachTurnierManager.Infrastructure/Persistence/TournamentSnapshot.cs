using System.ComponentModel.DataAnnotations;

namespace SchachTurnierManager.Infrastructure.Persistence;

public sealed class TournamentSnapshot
{
    [Key]
    public Guid Id { get; set; }

    [MaxLength(240)]
    public string Name { get; set; } = string.Empty;

    public string CreatedOn { get; set; } = string.Empty;

    public DateTimeOffset UpdatedAt { get; set; }

    public string Json { get; set; } = string.Empty;

    // Schema version 1: list and staleness data that must be readable without parsing Json.
    public long Revision { get; set; }

    public int PlayerCount { get; set; }

    public int RoundCount { get; set; }

    [MaxLength(32)]
    public string Format { get; set; } = string.Empty;
}
