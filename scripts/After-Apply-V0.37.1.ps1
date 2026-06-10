$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.1'

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
        $updated = $updated -replace '0\.37\.0', $version
        $updated = $updated -replace '0\.36\.1', $version
        $updated = [regex]::Replace($updated, 'version\s*=\s*"0\.\d+\.\d+"', 'version = "' + $version + '"')
    }

    if ($updated -ne $content) {
        Step "$relativePath auf $version gesetzt"
        Write-Utf8NoBom $relativePath $updated
    }
    else {
        Step "$relativePath bereits auf $version oder ohne passende Versionsmarke"
        Write-Utf8NoBom $relativePath $updated
    }
}

function Ensure-Contains([string]$relativePath, [string]$marker, [scriptblock]$update) {
    $content = Read-Text $relativePath
    if ($content.Contains($marker)) {
        Step "$marker bereits vorhanden in $relativePath"
        return
    }
    $updated = & $update $content
    if ([string]::IsNullOrWhiteSpace($updated) -or $updated -eq $content) {
        throw "Konnte $marker nicht in $relativePath ergänzen."
    }
    Write-Utf8NoBom $relativePath $updated
    Step "$marker ergänzt in $relativePath"
}

try {
    Replace-Version 'src/SchachTurnierManager.WebApi/Program.cs'
    Replace-Version 'src/SchachTurnierManager.WebApp/package.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/package-lock.json'
    Replace-Version 'src/SchachTurnierManager.WebApp/src/main.tsx'

    $programPath = 'src/SchachTurnierManager.WebApi/Program.cs'
    $program = Read-Text $programPath

    if (-not $program.Contains('using SchachTurnierManager.Domain.Services;')) {
        if ($program.Contains('using SchachTurnierManager.Domain.Models;')) {
            $program = $program.Replace('using SchachTurnierManager.Domain.Models;', 'using SchachTurnierManager.Domain.Models; using SchachTurnierManager.Domain.Services;')
            Step 'Program.cs: using SchachTurnierManager.Domain.Services ergänzt'
        }
        else {
            $program = 'using SchachTurnierManager.Domain.Services; ' + $program
            Step 'Program.cs: using SchachTurnierManager.Domain.Services am Anfang ergänzt'
        }
    }
    else {
        Step 'Program.cs: using SchachTurnierManager.Domain.Services bereits vorhanden'
    }

    $queryRouteMarker = '"/api/tournaments/{id:guid}/audit-journal/query"'
    if (-not $program.Contains($queryRouteMarker)) {
        $queryEndpoint = 'app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", (Guid id, string? severity, string? action, int? roundNumber, int? boardNumber, Guid? playerId, string? search, int? maxResults, string? sort, TournamentService service) => { try { AuditJournalSeverity? parsedSeverity = null; if (!string.IsNullOrWhiteSpace(severity)) { if (!Enum.TryParse<AuditJournalSeverity>(severity, ignoreCase: true, out var severityValue)) { return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severity}." }); } parsedSeverity = severityValue; } AuditJournalAction? parsedAction = null; if (!string.IsNullOrWhiteSpace(action)) { if (!Enum.TryParse<AuditJournalAction>(action, ignoreCase: true, out var actionValue)) { return Results.BadRequest(new { error = $"Unbekannte Audit-Aktion: {action}." }); } parsedAction = actionValue; } var sortDirection = string.Equals(sort, "oldest", StringComparison.OrdinalIgnoreCase) || string.Equals(sort, "asc", StringComparison.OrdinalIgnoreCase) || string.Equals(sort, "oldestFirst", StringComparison.OrdinalIgnoreCase) ? AuditJournalSortDirection.OldestFirst : AuditJournalSortDirection.NewestFirst; var query = new AuditJournalQuery { Severity = parsedSeverity, Action = parsedAction, RoundNumber = roundNumber, BoardNumber = boardNumber, PlayerId = playerId, SearchText = search, MaxResults = maxResults, SortDirection = sortDirection }; return Results.Ok(new AuditJournalQueryService().Query(service.GetAuditJournal(id), query)); } catch (InvalidOperationException ex) { return Results.NotFound(new { error = ex.Message }); } }); '
        $existingAuditEndpoint = 'app.MapGet("/api/tournaments/{id:guid}/audit-journal", (Guid id, TournamentService service) => { try { return Results.Ok(service.GetAuditJournal(id)); } catch (InvalidOperationException ex) { return Results.NotFound(new { error = ex.Message }); } });'
        if ($program.Contains($existingAuditEndpoint)) {
            $program = $program.Replace($existingAuditEndpoint, $existingAuditEndpoint + ' ' + $queryEndpoint)
            Step 'Audit-Journal-Query-Endpunkt nach bestehendem Audit-Journal-Endpunkt ergänzt'
        }
        else {
            $fallbackToken = 'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"'
            if ($program.Contains($fallbackToken)) {
                $program = $program.Replace($fallbackToken, $queryEndpoint + $fallbackToken)
                Step 'Audit-Journal-Query-Endpunkt vor Round-Diagnostics ergänzt'
            }
            else {
                $fallbackToken = 'if (embeddedDashboardAvailable) {'
                if ($program.Contains($fallbackToken)) {
                    $program = $program.Replace($fallbackToken, $queryEndpoint + $fallbackToken)
                    Step 'Audit-Journal-Query-Endpunkt vor Dashboard-Fallback ergänzt'
                }
                else {
                    throw "Kein stabiler Einfügepunkt für Audit-Journal-Query-Endpunkt gefunden in $programPath."
                }
            }
        }
    }
    else {
        Step 'Audit-Journal-Query-Endpunkt bereits vorhanden'
    }

    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('0.37.1')) {
        $entry = @"

## 0.37.1

- Fix: Audit-Journal-Query-API robust in `Program.cs` eingefügt, auch wenn die WebApi-Datei einzeilig formatiert ist.
- Behält die Query-Schicht aus 0.36.1 bei und stellt sie über `/api/tournaments/{id}/audit-journal/query` bereit.
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.
"@
        $changelog = $entry.TrimEnd() + "`r`n" + $changelog
        Step 'CHANGELOG.md ergänzt'
    }
    else {
        Step 'CHANGELOG.md enthält 0.37.1 bereits'
    }
    Write-Utf8NoBom $changelogPath $changelog

    $handoffPath = 'docs/HANDOFF_0_37_1.md'
    if (-not (Test-Path -LiteralPath (Join-Path $root $handoffPath))) {
        $handoff = @"
# Handoff 0.37.1 - Audit-Journal Query API Fix

## Ziel

0.37.1 repariert den fehlgeschlagenen 0.37.0-Patch. Die Ursache war ein zu fragiler Einfügeanker in der einzeilig formatierten `Program.cs`.

## Inhalt

- Version auf 0.37.1 gesetzt.
- `using SchachTurnierManager.Domain.Services;` sichergestellt.
- Endpunkt `GET /api/tournaments/{id}/audit-journal/query` ergänzt.
- Unterstützte Queryparameter: `severity`, `action`, `roundNumber`, `boardNumber`, `playerId`, `search`, `maxResults`, `sort`.
- Fehlerhafte Enum-Werte liefern `400 BadRequest`.
- Unbekannte Turniere liefern `404 NotFound`.

## Nachkontrolle

Das Script führt `scripts/Invoke-ReleaseGate.ps1` aus. Erst bei grünem Gate committen/pushen.
"@
        Write-Utf8NoBom $handoffPath $handoff
    }
    else {
        Step "$handoffPath bereits vorhanden"
        Write-Utf8NoBom $handoffPath (Read-Text $handoffPath)
    }

    Write-Utf8NoBom 'scripts/After-Apply-V0.37.1.ps1' (Read-Text 'scripts/After-Apply-V0.37.1.ps1')

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
