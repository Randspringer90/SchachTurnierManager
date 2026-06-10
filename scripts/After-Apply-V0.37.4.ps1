$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.4'

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
        return $content.Insert($last.Index + $last.Length, [Environment]::NewLine + $usingLine + [Environment]::NewLine)
    }

    return $usingLine + [Environment]::NewLine + $content
}

function Reset-ProgramCsFromGitHead() {
    $programPath = Join-Path $root 'src/SchachTurnierManager.WebApi/Program.cs'
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

    if (-not (Test-Path -LiteralPath $programPath)) {
        throw 'Program.cs wurde nach Git-Reset nicht gefunden.'
    }
}

function Insert-QueryMap([string]$content) {
    $route = 'app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", QueryAuditJournal);'
    if ($content.Contains($route)) {
        Step 'Audit-Journal-Query-Map bereits vorhanden'
        return $content
    }

    if ($content.Contains('/api/tournaments/{id:guid}/audit-journal/query')) {
        throw 'Es existiert noch ein alter Audit-Journal-Query-Endpunkt. Program.cs wurde nicht sauber zurueckgesetzt.'
    }

    $tokens = @(
        'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"',
        'app.MapGet("/api/tournaments/{id:guid}/audit-journal"',
        'app.MapGet("/api/tournaments/{id:guid}/standings/export.csv"',
        'if (embeddedDashboardAvailable)'
    )

    foreach ($token in $tokens) {
        $index = $content.IndexOf($token, [StringComparison]::Ordinal)
        if ($index -ge 0) {
            Step "Audit-Journal-Query-Map vor Token '$token' ergaenzt"
            return $content.Insert($index, [Environment]::NewLine + $route + [Environment]::NewLine)
        }
    }

    throw 'Kein stabiler Einfuegepunkt fuer Audit-Journal-Query-Map gefunden.'
}

function Insert-QueryHandler([string]$content) {
    if ($content.Contains('static IResult QueryAuditJournal(')) {
        Step 'Audit-Journal-Query-Handler bereits vorhanden'
        return $content
    }

    $handler = @'
static IResult QueryAuditJournal(Guid id, string? severity, string? action, int? roundNumber, int? boardNumber, Guid? playerId, string? search, int? maxResults, string? sort, TournamentService service)
{
    try
    {
        AuditJournalSeverity? parsedSeverity = null;
        if (!string.IsNullOrWhiteSpace(severity))
        {
            if (!Enum.TryParse<AuditJournalSeverity>(severity, true, out var severityValue))
            {
                return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severity}." });
            }

            parsedSeverity = severityValue;
        }

        AuditJournalAction? parsedAction = null;
        if (!string.IsNullOrWhiteSpace(action))
        {
            if (!Enum.TryParse<AuditJournalAction>(action, true, out var actionValue))
            {
                return Results.BadRequest(new { error = $"Unbekannte Audit-Aktion: {action}." });
            }

            parsedAction = actionValue;
        }

        var sortDirection = string.Equals(sort, "oldest", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sort, "asc", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sort, "oldestFirst", StringComparison.OrdinalIgnoreCase)
                ? AuditJournalSortDirection.OldestFirst
                : AuditJournalSortDirection.NewestFirst;

        var query = new AuditJournalQuery
        {
            Severity = parsedSeverity,
            Action = parsedAction,
            RoundNumber = roundNumber,
            BoardNumber = boardNumber,
            PlayerId = playerId,
            SearchText = search,
            MaxResults = maxResults,
            SortDirection = sortDirection
        };

        var result = new AuditJournalQueryService().Query(service.GetAuditJournal(id), query);
        return Results.Ok(result);
    }
    catch (InvalidOperationException ex)
    {
        return Results.NotFound(new { error = ex.Message });
    }
}

'@

    $token = 'static bool TryParseExternalPlayerSource'
    $index = $content.IndexOf($token, [StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw 'Kein stabiler Einfuegepunkt fuer Audit-Journal-Query-Handler gefunden.'
    }

    Step 'Audit-Journal-Query-Handler vor TryParseExternalPlayerSource ergaenzt'
    return $content.Insert($index, $handler)
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
    $program = Insert-QueryMap $program
    $program = Insert-QueryHandler $program
    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('## 0.37.4')) {
        $entry = @'

## 0.37.4

- Repariert den Audit-Journal-Query-API-Patch durch Wiederherstellung der Program.cs aus dem letzten gruenen Git-Stand.
- Ergaenzt die Query-Route als kurze MapGet-Zeile und verlagert die Logik in einen statischen Handler, damit die einzeilige Program.cs nicht erneut syntaktisch zerstoert wird.
- Behaelt das gruenes-Gate-vor-Commit-Prinzip bei.
'@
        $changelog = $changelog + $entry
        Step 'CHANGELOG.md ergaenzt'
        Write-Utf8NoBom $changelogPath $changelog
    }
    else {
        Step 'CHANGELOG.md enthaelt 0.37.4 bereits'
    }

    $handoffPath = 'docs/HANDOFF_0_37_4.md'
    $handoff = @'
# Handoff 0.37.4 - Audit-Journal Query API Syntax Fix

## Ziel

v0.37.4 repariert die gescheiterten v0.37.2/v0.37.3-Versuche fuer den Audit-Journal-Query-Endpunkt.

## Umsetzung

- `Program.cs` wird aus dem letzten gruenen Git-Stand wiederhergestellt.
- Danach wird die Version auf `0.37.4` gesetzt.
- Der Endpunkt `GET /api/tournaments/{id:guid}/audit-journal/query` wird als kurze `MapGet`-Route auf `QueryAuditJournal` gemappt.
- Die eigentliche Query-Logik liegt in einem statischen Handler am Ende der Datei.
- Dadurch bleibt die einzeilige Minimal-API-Datei deutlich weniger anfaellig fuer fehlerhafte Inline-Lambda-Inserts.

## Erwartung

- `dotnet build` gruen.
- `dotnet test` weiterhin 86/86 gruen.
- Frontend-Build gruen.
- Portable-ZIP `SchachTurnierManager_Portable_0.37.4.zip`.
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
