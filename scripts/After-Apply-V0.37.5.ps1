$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.5'

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

function Ensure-Using([string]$content, [string]$usingLine) {
    if ($content.Contains($usingLine)) {
        return $content
    }

    $usingMatches = [regex]::Matches($content, 'using\s+[^;]+;')
    if ($usingMatches.Count -gt 0) {
        $last = $usingMatches[$usingMatches.Count - 1]
        return $content.Insert($last.Index + $last.Length, [Environment]::NewLine + $usingLine)
    }

    return $usingLine + [Environment]::NewLine + $content
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

        AuditJournalSeverity? parsedSeverity = null;
        if (queryValues.TryGetValue("severity", out var severityValues) && !string.IsNullOrWhiteSpace(severityValues.ToString()))
        {
            var severityText = severityValues.ToString();
            if (!Enum.TryParse<AuditJournalSeverity>(severityText, true, out var severityValue))
            {
                return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severityText}." });
            }

            parsedSeverity = severityValue;
        }

        AuditJournalAction? parsedAction = null;
        if (queryValues.TryGetValue("action", out var actionValues) && !string.IsNullOrWhiteSpace(actionValues.ToString()))
        {
            var actionText = actionValues.ToString();
            if (!Enum.TryParse<AuditJournalAction>(actionText, true, out var actionValue))
            {
                return Results.BadRequest(new { error = $"Unbekannte Audit-Aktion: {actionText}." });
            }

            parsedAction = actionValue;
        }

        int? parsedRoundNumber = TryParseOptionalInt(queryValues, "roundNumber");
        int? parsedBoardNumber = TryParseOptionalInt(queryValues, "boardNumber");
        int? parsedMaxResults = TryParseOptionalInt(queryValues, "maxResults");
        Guid? parsedPlayerId = TryParseOptionalGuid(queryValues, "playerId");
        var searchText = queryValues.TryGetValue("search", out var searchValues) ? searchValues.ToString() : null;
        var sortText = queryValues.TryGetValue("sort", out var sortValues) ? sortValues.ToString() : null;

        var sortDirection = string.Equals(sortText, "oldest", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "asc", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "oldestFirst", StringComparison.OrdinalIgnoreCase)
                ? AuditJournalSortDirection.OldestFirst
                : AuditJournalSortDirection.NewestFirst;

        var query = new AuditJournalQuery
        {
            Severity = parsedSeverity,
            Action = parsedAction,
            RoundNumber = parsedRoundNumber,
            BoardNumber = parsedBoardNumber,
            PlayerId = parsedPlayerId,
            SearchText = searchText,
            MaxResults = parsedMaxResults,
            SortDirection = sortDirection
        };

        var result = new AuditJournalQueryService().Query(service.GetAuditJournal(id), query);
        return Results.Ok(result);
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
});

'@

    $tokens = @(
        'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"',
        'app.MapGet("/api/tournaments/{id:guid}/audit-journal",',
        'app.MapGet("/api/tournaments/{id:guid}/standings/export.csv"'
    )

    foreach ($token in $tokens) {
        $index = $content.IndexOf($token, [StringComparison]::Ordinal)
        if ($index -ge 0) {
            Step "Audit-Journal-Query-Endpunkt vor Token '$token' ergaenzt"
            return $content.Insert($index, [Environment]::NewLine + $endpoint)
        }
    }

    throw 'Kein stabiler Einfuegepunkt fuer Audit-Journal-Query-Endpunkt gefunden.'
}

function Insert-HelperFunctions([string]$content) {
    if ($content.Contains('static int? TryParseOptionalInt(') -and $content.Contains('static Guid? TryParseOptionalGuid(')) {
        Step 'Audit-Journal-Query-Helfer bereits vorhanden'
        return $content
    }

    $helpers = @'
static int? TryParseOptionalInt(IQueryCollection query, string name)
{
    if (!query.TryGetValue(name, out var values))
    {
        return null;
    }

    var text = values.ToString();
    return int.TryParse(text, out var parsed) ? parsed : null;
}

static Guid? TryParseOptionalGuid(IQueryCollection query, string name)
{
    if (!query.TryGetValue(name, out var values))
    {
        return null;
    }

    var text = values.ToString();
    return Guid.TryParse(text, out var parsed) ? parsed : null;
}

'@

    $token = 'static bool TryParseExternalPlayerSource'
    $index = $content.IndexOf($token, [StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw 'Kein stabiler Einfuegepunkt fuer Audit-Journal-Query-Helfer gefunden.'
    }

    Step 'Audit-Journal-Query-Helfer vor TryParseExternalPlayerSource ergaenzt'
    return $content.Insert($index, $helpers)
}

function Invoke-NativeStep([string]$Name, [scriptblock]$Script) {
    Write-Host "[ReleaseGate] $Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

try {
    Reset-ProgramCsFromGitHead

    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    $programPath = 'src/SchachTurnierManager.WebApi/Program.cs'
    $program = Read-Text $programPath
    $program = Ensure-Using $program 'using SchachTurnierManager.Domain.Services;'
    $program = Insert-QueryEndpoint $program
    $program = Insert-HelperFunctions $program
    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('## 0.37.5')) {
        $entry = @'

## 0.37.5

- Repariert den Audit-Journal-Query-API-Patch durch Reset der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt den Query-Endpunkt als Inline-Minimal-API-Handler mit HttpRequest-Query-Auswertung.
- Fuegt kleine Parser-Helfer fuer optionale int- und Guid-Queryparameter hinzu.
'@
        $changelog = $changelog + $entry
        Step 'CHANGELOG.md ergaenzt'
        Write-Utf8NoBom $changelogPath $changelog
    }
    else {
        Step 'CHANGELOG.md enthaelt 0.37.5 bereits'
    }

    $handoffPath = 'docs/HANDOFF_0_37_5.md'
    $handoff = @'
# Handoff 0.37.5 - Audit-Journal Query API Reset Fix

## Ziel

v0.37.5 repariert die weiterhin fehlerhafte Program.cs-Syntax aus den vorherigen v0.37.x-Versuchen.

## Umsetzung

- Program.cs wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Versionen werden auf 0.37.5 gesetzt.
- Der Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query wird als Inline-Minimal-API-Handler eingefuegt.
- Queryparameter werden ueber HttpRequest.Query gelesen.
- Optionale int-/Guid-Parameter werden ueber kleine lokale Helfer geparst.

## Erwartung

- dotnet build gruen.
- dotnet test weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP SchachTurnierManager_Portable_0.37.5.zip.
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
