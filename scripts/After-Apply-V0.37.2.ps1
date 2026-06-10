$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.2'

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
        $updated = [regex]::Replace($updated, '0\.37\.[01]', $version)
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
        return $content.Insert($last.Index + $last.Length, ' ' + $usingLine)
    }

    return $usingLine + ' ' + $content
}

try {
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    $programPath = 'src/SchachTurnierManager.WebApi/Program.cs'
    $program = Read-Text $programPath
    $program = Ensure-Using $program 'using SchachTurnierManager.Domain.Models;'
    $program = Ensure-Using $program 'using SchachTurnierManager.Domain.Services;'

    $queryRouteMarkerGuid = '"/api/tournaments/{id:guid}/audit-journal/query"'
    $queryRouteMarkerPlain = '"/api/tournaments/{id}/audit-journal/query"'
    if ($program.Contains($queryRouteMarkerGuid) -or $program.Contains($queryRouteMarkerPlain)) {
        Step 'Audit-Journal-Query-Endpunkt bereits vorhanden'
    }
    else {
        $queryEndpoint = @'
app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", (Guid id, string? severity, string? action, int? roundNumber, int? boardNumber, Guid? playerId, string? search, int? maxResults, string? sort, TournamentService service) =>
{
    try
    {
        AuditJournalSeverity? parsedSeverity = null;
        if (!string.IsNullOrWhiteSpace(severity))
        {
            if (!Enum.TryParse<AuditJournalSeverity>(severity, ignoreCase: true, out var severityValue))
            {
                return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severity}." });
            }
            parsedSeverity = severityValue;
        }

        AuditJournalAction? parsedAction = null;
        if (!string.IsNullOrWhiteSpace(action))
        {
            if (!Enum.TryParse<AuditJournalAction>(action, ignoreCase: true, out var actionValue))
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
});
'@
        $queryEndpointOneLine = ($queryEndpoint -replace "`r?`n", ' ')

        $inserted = $false
        $tokens = @(
            'app.MapGet("/api/tournaments/{id:guid}/audit-journal",',
            'app.MapGet("/api/tournaments/{id}/audit-journal",',
            'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"',
            'app.MapGet("/api/tournaments/{id}/round-diagnostics"',
            'app.MapGet("/api/tournaments/{id:guid}/export/report"',
            'app.MapGet("/api/tournaments/{id}/export/report"',
            'app.Run();'
        )

        foreach ($token in $tokens) {
            $index = $program.IndexOf($token, [StringComparison]::Ordinal)
            if ($index -ge 0) {
                if ($token -like 'app.MapGet*' -and $token.Contains('audit-journal')) {
                    $nextIndex = $program.IndexOf('app.Map', $index + 1, [StringComparison]::Ordinal)
                    if ($nextIndex -ge 0) {
                        $program = $program.Insert($nextIndex, $queryEndpointOneLine + ' ')
                    }
                    else {
                        $program = $program.Insert($index, $queryEndpointOneLine + ' ')
                    }
                }
                else {
                    $program = $program.Insert($index, $queryEndpointOneLine + ' ')
                }
                Step "Audit-Journal-Query-Endpunkt vor/nach Token '$token' ergänzt"
                $inserted = $true
                break
            }
        }

        if (-not $inserted) {
            throw "Kein stabiler Einfügepunkt für Audit-Journal-Query-Endpunkt gefunden in $programPath."
        }
    }

    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('0.37.2')) {
        $entry = @'

## 0.37.2

- Fix: Audit-Journal-Query-API-Fixscript repariert; keine PowerShell-Backtick-/Unicode-Escape-Falle mehr in eingebetteten Markdown-Texten.
- Query-Endpunkt wird robust vor stabilen WebApi-Tokens eingefügt, notfalls vor app.Run().
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.
'@
        $changelog = $entry.TrimEnd() + "`r`n" + $changelog
        Step 'CHANGELOG.md ergänzt'
    }
    else {
        Step 'CHANGELOG.md enthält 0.37.2 bereits'
    }
    Write-Utf8NoBom $changelogPath $changelog

    $handoffPath = 'docs/HANDOFF_0_37_2.md'
    if (-not (Test-Path -LiteralPath (Join-Path $root $handoffPath))) {
        $handoff = @'
# Handoff 0.37.2 - Audit-Journal Query API Fix

## Ziel

0.37.2 repariert den fehlgeschlagenen 0.37.1-Fix. Ursache war ein PowerShell-Parserfehler durch Backticks in einer doppelt gequoteten Here-String-Zeichenkette.

## Inhalt

- Version auf 0.37.2 gesetzt.
- using SchachTurnierManager.Domain.Models; sichergestellt.
- using SchachTurnierManager.Domain.Services; sichergestellt.
- Endpunkt GET /api/tournaments/{id:guid}/audit-journal/query ergänzt.
- Unterstützte Queryparameter: severity, action, roundNumber, boardNumber, playerId, search, maxResults, sort.
- Fehlerhafte Enum-Werte liefern 400 BadRequest.
- Unbekannte Turniere liefern 404 NotFound.

## Nachkontrolle

Das Script führt scripts/Invoke-ReleaseGate.ps1 aus. Erst bei grünem Gate committen/pushen.
'@
        Write-Utf8NoBom $handoffPath $handoff
    }
    else {
        Step "$handoffPath bereits vorhanden"
        Write-Utf8NoBom $handoffPath (Read-Text $handoffPath)
    }

    Write-Utf8NoBom 'scripts/After-Apply-V0.37.2.ps1' (Read-Text 'scripts/After-Apply-V0.37.2.ps1')

    Step 'Release-Gate...'
    Push-Location $root
    try {
        & (Join-Path $root 'scripts/Invoke-ReleaseGate.ps1')
        if ($LASTEXITCODE -ne 0) {
            throw "Release-Gate ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    Push-Location $root
    try { git status --short }
    finally { Pop-Location }
}
catch {
    Write-Error $_
    exit 1
}
