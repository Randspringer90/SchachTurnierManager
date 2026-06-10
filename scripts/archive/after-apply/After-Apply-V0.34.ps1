Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[v0.34.0] $Message"
}

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Datei nicht gefunden: $RelativePath"
    }
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Content
    )
    $path = Join-Path $Root $RelativePath
    [System.IO.File]::WriteAllText($path, $Content, $Utf8NoBom)
}

function Set-TextFileUtf8NoBom {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Replace-Version {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $text = Read-Text $RelativePath
    $updated = $text.Replace('0.33.0', '0.34.0')
    if ($updated -eq $text) {
        if ($text.Contains('0.34.0')) {
            Write-Step "$RelativePath ist bereits auf 0.34.0"
        } else {
            Write-Step "$RelativePath enthielt keine 0.33.0-Version mehr"
        }
    } else {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf 0.34.0 gesetzt"
    }
}

function Replace-Once {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$Old,
        [Parameter(Mandatory = $true)][string]$New,
        [Parameter(Mandatory = $true)][string]$Description,
        [string]$AlreadyMarker = ''
    )
    $text = Read-Text $RelativePath
    if ($AlreadyMarker -and $text.Contains($AlreadyMarker)) {
        Write-Step "$Description bereits vorhanden"
        return
    }

    $oldVariants = @($Old, $Old.Replace("`r`n", "`n"), $Old.Replace("`n", "`r`n")) | Select-Object -Unique
    foreach ($candidate in $oldVariants) {
        if ($text.Contains($candidate)) {
            $newCandidate = if ($candidate.Contains("`r`n")) { $New.Replace("`n", "`r`n") } else { $New.Replace("`r`n", "`n") }
            $updated = $text.Replace($candidate, $newCandidate)
            Write-Text $RelativePath $updated
            Write-Step "$Description ergänzt"
            return
        }
    }

    throw "Anker fuer $Description nicht gefunden in $RelativePath."
}

function Add-ChangelogEntry {
    $path = 'CHANGELOG.md'
    $text = Read-Text $path
    if ($text.Contains('## 0.34.0')) {
        Write-Step 'CHANGELOG.md enthaelt 0.34.0 bereits'
        return
    }

    $entry = @'
## 0.34.0 - Persistent Audit Journal Foundation

- Persistierbares Auditjournal im `TournamentState` ergänzt.
- Neue Domain-Typen `AuditJournalEntry`, `AuditJournalAction` und `AuditJournalSeverity` ergänzt.
- Zentrale Turnierleiteraktionen werden nun dauerhaft protokolliert: Turnier/Spieler/Runden/Ergebnisse/manuelle Paarungen/Rundenprüfung.
- Neuer API-Endpunkt `GET /api/tournaments/{id}/audit-journal`.
- Neue Application-Regressionstests für Kernworkflow, manuelle Korrekturen und Snapshot-Persistenz.
- Keine Änderung an Auslosungslogik oder Wertungsberechnung.

'@

    Write-Text $path ($entry + $text)
    Write-Step 'CHANGELOG.md ergaenzt'
}

function Ensure-TournamentStateAuditJournal {
    $relativePath = 'src/SchachTurnierManager.Domain/Models/TournamentState.cs'
    Replace-Once $relativePath @'
    public List<TournamentRound> Rounds { get; init; } = new();
}
'@ @'
    public List<TournamentRound> Rounds { get; init; } = new();
    public List<AuditJournalEntry> AuditJournal { get; init; } = new();
}
'@ 'AuditJournal im TournamentState' 'public List<AuditJournalEntry> AuditJournal'
}

function Patch-TournamentService {
    $relativePath = 'src/SchachTurnierManager.Application/TournamentService.cs'

    Replace-Once $relativePath @'
        var tournament = new TournamentState
        {
            Name = name.Trim(),
            Settings = settings ?? new TournamentSettings()
        };
        _store.Save(tournament);
'@ @'
        var tournament = new TournamentState
        {
            Name = name.Trim(),
            Settings = settings ?? new TournamentSettings()
        };
        AddAuditEntry(tournament, AuditJournalAction.TournamentCreated, AuditJournalSeverity.Info, "Turnier angelegt.", $"Name: {tournament.Name}");
        _store.Save(tournament);
'@ 'Auditjournal: Turnier anlegen' 'Turnier angelegt.'

    Replace-Once $relativePath @'
        tournament.Settings = normalized;
        _store.Save(tournament);
'@ @'
        tournament.Settings = normalized;
        AddAuditEntry(tournament, AuditJournalAction.SettingsUpdated, AuditJournalSeverity.Info, "Turniereinstellungen aktualisiert.", $"Format: {normalized.Format}, Runden: {normalized.PlannedRounds}");
        _store.Save(tournament);
'@ 'Auditjournal: Einstellungen aktualisieren' 'Turniereinstellungen aktualisiert.'

    Replace-Once $relativePath @'
        EnsureUniquePlayerNames(tournament);
        _store.Save(tournament);
'@ @'
        EnsureUniquePlayerNames(tournament);
        AddAuditEntry(tournament, AuditJournalAction.TournamentImported, AuditJournalSeverity.Warning, "Turnier importiert.", $"OverwriteExisting: {overwriteExisting}");
        _store.Save(tournament);
'@ 'Auditjournal: Turnierimport' 'Turnier importiert.'

    Replace-Once $relativePath @'
        _store.Save(tournament);
        return result;
    }

    public Player AddPlayer(Guid tournamentId, Player player)
'@ @'
        AddAuditEntry(tournament, AuditJournalAction.ExternalPlayerApplied, AuditJournalSeverity.Info, $"Externe Spielerdaten übernommen: {result.Player.Name}.", null, playerId: result.Player.Id, playerName: result.Player.Name);
        _store.Save(tournament);
        return result;
    }

    public Player AddPlayer(Guid tournamentId, Player player)
'@ 'Auditjournal: externe Spielerdaten' 'Externe Spielerdaten übernommen'

    Replace-Once $relativePath @'
        tournament.Players.Add(normalized);
        _store.Save(tournament);
        return normalized;
'@ @'
        tournament.Players.Add(normalized);
        AddAuditEntry(tournament, AuditJournalAction.PlayerAdded, AuditJournalSeverity.Info, $"Spieler hinzugefügt: {normalized.Name}.", null, playerId: normalized.Id, playerName: normalized.Name);
        _store.Save(tournament);
        return normalized;
'@ 'Auditjournal: Spieler hinzufügen' 'Spieler hinzugefügt:'

    Replace-Once $relativePath @'
        tournament.Players[index] = normalized;
        _store.Save(tournament);
        return normalized;
'@ @'
        tournament.Players[index] = normalized;
        AddAuditEntry(tournament, AuditJournalAction.PlayerUpdated, AuditJournalSeverity.Info, $"Spieler aktualisiert: {normalized.Name}.", null, playerId: normalized.Id, playerName: normalized.Name);
        _store.Save(tournament);
        return normalized;
'@ 'Auditjournal: Spieler aktualisieren' 'Spieler aktualisiert:'

    Replace-Once $relativePath @'
        var existing = tournament.Players[index];
        tournament.Players[index] = existing with { Status = status };
        _store.Save(tournament);
        return tournament.Players[index];
'@ @'
        var existing = tournament.Players[index];
        tournament.Players[index] = existing with { Status = status };
        AddAuditEntry(tournament, AuditJournalAction.PlayerStatusChanged, AuditJournalSeverity.Warning, $"Spielerstatus geändert: {existing.Name} -> {status}.", null, playerId: existing.Id, playerName: existing.Name);
        _store.Save(tournament);
        return tournament.Players[index];
'@ 'Auditjournal: Spielerstatus' 'Spielerstatus geändert:'

    Replace-Once $relativePath @'
            tournament.Players.RemoveAt(index);
            _store.Save(tournament);
            return existing;
'@ @'
            tournament.Players.RemoveAt(index);
            AddAuditEntry(tournament, AuditJournalAction.PlayerRemoved, AuditJournalSeverity.Warning, $"Spieler entfernt: {existing.Name}.", "Spieler hatte noch keine Paarungen.", playerId: existing.Id, playerName: existing.Name);
            _store.Save(tournament);
            return existing;
'@ 'Auditjournal: Spieler entfernen' 'Spieler entfernt:'

    Replace-Once $relativePath @'
        tournament.Players[index] = withdrawn;
        _store.Save(tournament);
        return withdrawn;
'@ @'
        tournament.Players[index] = withdrawn;
        AddAuditEntry(tournament, AuditJournalAction.PlayerWithdrawn, AuditJournalSeverity.Warning, $"Spieler zurückgezogen: {withdrawn.Name}.", "Entfernen war nicht möglich, weil bereits Paarungen existieren.", playerId: withdrawn.Id, playerName: withdrawn.Name);
        _store.Save(tournament);
        return withdrawn;
'@ 'Auditjournal: Spieler zurückziehen' 'Spieler zurückgezogen:'

    Replace-Once $relativePath @'
        tournament.Rounds.Add(nextRound);
        _store.Save(tournament);
        return nextRound;
'@ @'
        tournament.Rounds.Add(nextRound);
        AddAuditEntry(tournament, AuditJournalAction.RoundGenerated, AuditJournalSeverity.Info, $"Runde {nextRound.RoundNumber} ausgelost.", $"{nextRound.Pairings.Count} Brett(er).", roundNumber: nextRound.RoundNumber);
        _store.Save(tournament);
        return nextRound;
'@ 'Auditjournal: Runde auslosen' 'ausgelost.'

    Replace-Once $relativePath @'
        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
'@ @'
        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings });
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(tournament, AuditJournalAction.ResultRecorded, AuditJournalSeverity.Info, $"Ergebnis eingetragen: Runde {roundNumber}, Brett {boardNumber}.", resultKind.ToString(), roundNumber: roundNumber, boardNumber: boardNumber);
        _store.Save(tournament);
        return updated;
'@ 'Auditjournal: Ergebnis erfassen' 'Ergebnis eingetragen:'

    Replace-Once $relativePath @'
        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings, Audit = audit });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
'@ @'
        var updated = WithCalculatedStatus(round with { Pairings = updatedPairings, Audit = audit });
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(tournament, AuditJournalAction.PairingOverridden, AuditJournalSeverity.Warning, $"Paarung manuell geändert: Runde {roundNumber}, Brett {boardNumber}.", normalizedNotes, roundNumber: roundNumber, boardNumber: boardNumber, reason: normalizedNotes);
        _store.Save(tournament);
        return updated;
'@ 'Auditjournal: manuelle Paarung' 'Paarung manuell geändert:'

    Replace-Once $relativePath @'
        var updated = WithCalculatedStatus(round with
        {
            IsLocked = isLocked,
            LockedAt = isLocked ? DateTimeOffset.UtcNow : null,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
'@ @'
        var updated = WithCalculatedStatus(round with
        {
            IsLocked = isLocked,
            LockedAt = isLocked ? DateTimeOffset.UtcNow : null,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(tournament, isLocked ? AuditJournalAction.RoundLocked : AuditJournalAction.RoundUnlocked, AuditJournalSeverity.Warning, isLocked ? $"Runde {roundNumber} gesperrt." : $"Runde {roundNumber} entsperrt.", null, roundNumber: roundNumber);
        _store.Save(tournament);
        return updated;
'@ 'Auditjournal: Runde sperren' 'gesperrt.'

    Replace-Once $relativePath @'
        var updated = WithCalculatedStatus(round with
        {
            IsVerified = isVerified,
            VerifiedAt = isVerified ? DateTimeOffset.UtcNow : null,
            IsLocked = isVerified || round.IsLocked,
            LockedAt = isVerified ? (round.LockedAt ?? DateTimeOffset.UtcNow) : round.LockedAt,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        _store.Save(tournament);
        return updated;
'@ @'
        var updated = WithCalculatedStatus(round with
        {
            IsVerified = isVerified,
            VerifiedAt = isVerified ? DateTimeOffset.UtcNow : null,
            IsLocked = isVerified || round.IsLocked,
            LockedAt = isVerified ? (round.LockedAt ?? DateTimeOffset.UtcNow) : round.LockedAt,
            Audit = audit
        });
        tournament.Rounds[roundIndex] = updated;
        AddAuditEntry(tournament, isVerified ? AuditJournalAction.RoundVerified : AuditJournalAction.RoundUnverified, AuditJournalSeverity.Warning, isVerified ? $"Runde {roundNumber} geprüft." : $"Runde {roundNumber} als ungeprüft markiert.", null, roundNumber: roundNumber);
        _store.Save(tournament);
        return updated;
'@ 'Auditjournal: Runde prüfen' 'als ungeprüft markiert'

    Replace-Once $relativePath @'
    public IReadOnlyList<PairingAudit> GetAudit(Guid tournamentId)
    {
        return RequireTournament(tournamentId).Rounds.Select(r => r.Audit).ToList();
    }

    public IReadOnlyList<RoundDiagnostics> GetRoundDiagnostics(Guid tournamentId)
'@ @'
    public IReadOnlyList<PairingAudit> GetAudit(Guid tournamentId)
    {
        return RequireTournament(tournamentId).Rounds.Select(r => r.Audit).ToList();
    }

    public IReadOnlyList<AuditJournalEntry> GetAuditJournal(Guid tournamentId)
    {
        return RequireTournament(tournamentId).AuditJournal
            .OrderByDescending(entry => entry.CreatedAt)
            .ThenByDescending(entry => entry.Id)
            .ToList();
    }

    public IReadOnlyList<RoundDiagnostics> GetRoundDiagnostics(Guid tournamentId)
'@ 'Auditjournal-Service-Getter' 'GetAuditJournal'

    Replace-Once $relativePath @'
    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private static TournamentSettings NormalizeSettings(TournamentSettings settings)
'@ @'
    public TournamentState RequireTournament(Guid tournamentId)
    {
        return _store.Get(tournamentId) ?? throw new InvalidOperationException($"Turnier {tournamentId} wurde nicht gefunden.");
    }

    private static void AddAuditEntry(
        TournamentState tournament,
        AuditJournalAction action,
        AuditJournalSeverity severity,
        string summary,
        string? details = null,
        int? roundNumber = null,
        int? boardNumber = null,
        Guid? playerId = null,
        string? playerName = null,
        string? reason = null)
    {
        tournament.AuditJournal.Add(new AuditJournalEntry
        {
            Action = action,
            Severity = severity,
            Summary = summary,
            Details = string.IsNullOrWhiteSpace(details) ? null : details.Trim(),
            Reason = string.IsNullOrWhiteSpace(reason) ? null : reason.Trim(),
            RoundNumber = roundNumber,
            BoardNumber = boardNumber,
            PlayerId = playerId,
            PlayerName = string.IsNullOrWhiteSpace(playerName) ? null : playerName.Trim()
        });
    }

    private static TournamentSettings NormalizeSettings(TournamentSettings settings)
'@ 'Auditjournal-Helfer' 'private static void AddAuditEntry'
}

function Patch-Program {
    $relativePath = 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Once $relativePath @'
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

app.MapGet("/api/tournaments/{id:guid}/round-diagnostics", (Guid id, TournamentService service) =>
'@ @'
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

app.MapGet("/api/tournaments/{id:guid}/round-diagnostics", (Guid id, TournamentService service) =>
'@ 'Auditjournal-API-Endpunkt' '/audit-journal'
}

function Invoke-NativeStep {
    param([string]$Name, [scriptblock]$Script)
    Write-Step "$Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

Push-Location $Root
try {
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'
    Ensure-TournamentStateAuditJournal
    Patch-TournamentService
    Patch-Program
    Add-ChangelogEntry

    @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.Domain/Models/AuditJournalEntry.cs',
        'src/SchachTurnierManager.Domain/Models/TournamentState.cs',
        'src/SchachTurnierManager.Application/TournamentService.cs',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'tests/SchachTurnierManager.Application.Tests/AuditJournalWorkflowTests.cs',
        'docs/HANDOFF_0_34_0.md',
        'scripts/After-Apply-V0.34.ps1'
    ) | ForEach-Object { Set-TextFileUtf8NoBom $_ }

    $releaseGate = Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1'
    if (-not (Test-Path -LiteralPath $releaseGate)) {
        throw 'Release-Gate nicht gefunden. Bitte zuerst v0.30.0 sauber einspielen.'
    }

    Invoke-NativeStep 'Release-Gate' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $releaseGate -Root $Root }

    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git status --short
} finally {
    Pop-Location
}
