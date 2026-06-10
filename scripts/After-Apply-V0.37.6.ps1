$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.6'

function Step([string]$message) {
    Write-Host "[v$version] $message"
}

function Read-Text([string]$relativePath) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Datei nicht gefunden: $relativePath"
    }
    return [System.IO.File]::ReadAllText($path)
}

function Write-Utf8NoBom([string]$relativePath, [string]$content) {
    $path = Join-Path $root $relativePath
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($path, $content, $encoding)
    Step "$relativePath als UTF-8 ohne BOM gespeichert"
}

function Replace-Version([string]$relativePath) {
    $content = Read-Text $relativePath
    $updated = $content
    if ($relativePath -like '*.json') {
        $updated = [regex]::Replace($updated, '"version"\s*:\s*"0\.\d+\.\d+"', '"version": "' + $version + '"')
    }
    else {
        $updated = [regex]::Replace($updated, '0\.37\.[0-9]+', $version)
        $updated = [regex]::Replace($updated, '0\.36\.1', $version)
        $updated = [regex]::Replace($updated, 'version\s*=\s*"0\.\d+\.\d+"', 'version = "' + $version + '"')
    }

    if ($updated -ne $content) {
        Step "$relativePath auf $version gesetzt"
    }
    else {
        Step "$relativePath bereits auf $version oder ohne passende Versionsmarke"
    }
    Write-Utf8NoBom $relativePath $updated
}

function Reset-ProgramCsFromGitHead() {
    Push-Location $root
    try {
        & git checkout -- 'src/SchachTurnierManager.WebApi/Program.cs'
        if ($LASTEXITCODE -ne 0) {
            throw 'git checkout fuer Program.cs ist fehlgeschlagen.'
        }
        Step 'Program.cs aus letztem gruenen Git-Stand wiederhergestellt'
    }
    finally {
        Pop-Location
    }
}

function Insert-QueryEndpoint([string]$content) {
    if ($content.Contains('/api/tournaments/{id:guid}/audit-journal/query')) {
        Step 'Audit-Journal-Query-Endpunkt bereits vorhanden'
        return $content
    }

    $endpoint = @'
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

'@

    $token = 'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"'
    $index = $content.IndexOf($token, [StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw 'Kein stabiler Einfuegepunkt fuer Audit-Journal-Query-Endpunkt gefunden.'
    }

    Step "Audit-Journal-Query-Endpunkt vor Token '$token' ergaenzt"
    return $content.Insert($index, [Environment]::NewLine + $endpoint)
}

try {
    Reset-ProgramCsFromGitHead

    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    $programPath = 'src/SchachTurnierManager.WebApi/Program.cs'
    $program = Read-Text $programPath
    $program = Insert-QueryEndpoint $program
    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('## 0.37.6')) {
        $entry = @'

## 0.37.6

- Repariert den Audit-Journal-Query-API-Patch erneut durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Entfernt die separate Helper-Funktionsstrategie der vorherigen Fixes.
- Ergaenzt den Query-Endpunkt als eigenstaendigen Inline-Minimal-API-Handler ohne zusaetzliche lokale Helfer.
'@
        $changelog = $changelog + $entry
        Step 'CHANGELOG.md ergaenzt'
        Write-Utf8NoBom $changelogPath $changelog
    }
    else {
        Step 'CHANGELOG.md enthaelt 0.37.6 bereits'
    }

    $handoffPath = 'docs/HANDOFF_0_37_6.md'
    $handoff = @'
# Handoff 0.37.6 - Audit-Journal Query API Inline Fix

## Ziel

v0.37.6 repariert die fehlerhafte Program.cs-Syntax aus den vorherigen v0.37.x-Versuchen.

## Umsetzung

- Program.cs wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Versionen werden auf 0.37.6 gesetzt.
- Der Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query wird als Inline-Minimal-API-Handler eingefuegt.
- Es werden keine separaten Hilfsfunktionen in Program.cs ergaenzt, um Top-Level-/Local-Function-Syntaxprobleme zu vermeiden.

## Erwartung

- dotnet build gruen.
- dotnet test weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP SchachTurnierManager_Portable_0.37.6.zip.
'@
    Write-Utf8NoBom $handoffPath $handoff

    Write-Host "[v$version] Release-Gate..."
    Push-Location $root
    try {
        & (Join-Path $root 'scripts/Invoke-ReleaseGate.ps1')
        if ($LASTEXITCODE -ne 0) {
            throw "Release-Gate ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
        }
        git status --short
        Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
        git status --short
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Error $_
    exit 1
}
