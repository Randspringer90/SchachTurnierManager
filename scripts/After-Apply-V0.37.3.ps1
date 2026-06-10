$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$version = '0.37.3'

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
        $updated = [regex]::Replace($updated, '0\.37\.[0-2]', $version)
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
        $separator = [Environment]::NewLine
        if ($content.IndexOf([Environment]::NewLine) -lt 0) {
            $separator = ' '
        }
        return $content.Insert($last.Index + $last.Length, $separator + $usingLine)
    }

    return $usingLine + [Environment]::NewLine + $content
}

function Remove-ExistingQueryEndpoints([string]$content) {
    $markers = @(
        'app.MapGet("/api/tournaments/{id:guid}/audit-journal/query"',
        'app.MapGet("/api/tournaments/{id}/audit-journal/query"'
    )

    $removedAny = $true
    while ($removedAny) {
        $removedAny = $false
        foreach ($marker in $markers) {
            $start = $content.IndexOf($marker, [StringComparison]::Ordinal)
            if ($start -lt 0) {
                continue
            }

            $nextMap = $content.IndexOf('app.Map', $start + $marker.Length, [StringComparison]::Ordinal)
            $appRun = $content.IndexOf('app.Run();', $start + $marker.Length, [StringComparison]::Ordinal)
            $end = -1
            if ($nextMap -ge 0 -and $appRun -ge 0) {
                $end = [Math]::Min($nextMap, $appRun)
            }
            elseif ($nextMap -ge 0) {
                $end = $nextMap
            }
            elseif ($appRun -ge 0) {
                $end = $appRun
            }
            else {
                $semicolon = $content.IndexOf('});', $start, [StringComparison]::Ordinal)
                if ($semicolon -ge 0) {
                    $end = $semicolon + 3
                }
            }

            if ($end -lt 0 -or $end -le $start) {
                throw 'Fehlerhafter Audit-Journal-Query-Endpunkt konnte nicht sicher entfernt werden.'
            }

            $content = $content.Remove($start, $end - $start).Insert($start, [Environment]::NewLine)
            Step 'Vorhandenen/fehlerhaften Audit-Journal-Query-Endpunkt entfernt'
            $removedAny = $true
            break
        }
    }

    return $content
}

function Insert-QueryEndpoint([string]$content) {
    if ($content.Contains('/api/tournaments/{id:guid}/audit-journal/query') -or $content.Contains('/api/tournaments/{id}/audit-journal/query')) {
        Step 'Audit-Journal-Query-Endpunkt bereits vorhanden'
        return $content
    }

    $endpoint = @'

app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", (Guid id, Microsoft.AspNetCore.Http.HttpRequest request, TournamentService service) =>
{
    try
    {
        var severityText = request.Query["severity"].ToString();
        AuditJournalSeverity? severity = null;
        if (!string.IsNullOrWhiteSpace(severityText))
        {
            if (!Enum.TryParse<AuditJournalSeverity>(severityText, true, out var severityValue))
            {
                return Results.BadRequest(new { error = $"Unbekannter Audit-Schweregrad: {severityText}." });
            }
            severity = severityValue;
        }

        var actionText = request.Query["action"].ToString();
        AuditJournalAction? action = null;
        if (!string.IsNullOrWhiteSpace(actionText))
        {
            if (!Enum.TryParse<AuditJournalAction>(actionText, true, out var actionValue))
            {
                return Results.BadRequest(new { error = $"Unbekannte Audit-Aktion: {actionText}." });
            }
            action = actionValue;
        }

        int? roundNumber = null;
        var roundNumberText = request.Query["roundNumber"].ToString();
        if (!string.IsNullOrWhiteSpace(roundNumberText))
        {
            if (!int.TryParse(roundNumberText, out var parsedRoundNumber))
            {
                return Results.BadRequest(new { error = $"Ungültige Rundennummer: {roundNumberText}." });
            }
            roundNumber = parsedRoundNumber;
        }

        int? boardNumber = null;
        var boardNumberText = request.Query["boardNumber"].ToString();
        if (!string.IsNullOrWhiteSpace(boardNumberText))
        {
            if (!int.TryParse(boardNumberText, out var parsedBoardNumber))
            {
                return Results.BadRequest(new { error = $"Ungültige Brettnummer: {boardNumberText}." });
            }
            boardNumber = parsedBoardNumber;
        }

        Guid? playerId = null;
        var playerIdText = request.Query["playerId"].ToString();
        if (!string.IsNullOrWhiteSpace(playerIdText))
        {
            if (!Guid.TryParse(playerIdText, out var parsedPlayerId))
            {
                return Results.BadRequest(new { error = $"Ungültige Spieler-ID: {playerIdText}." });
            }
            playerId = parsedPlayerId;
        }

        int? maxResults = null;
        var maxResultsText = request.Query["maxResults"].ToString();
        if (!string.IsNullOrWhiteSpace(maxResultsText))
        {
            if (!int.TryParse(maxResultsText, out var parsedMaxResults))
            {
                return Results.BadRequest(new { error = $"Ungültige maximale Trefferanzahl: {maxResultsText}." });
            }
            maxResults = parsedMaxResults;
        }

        var sortText = request.Query["sort"].ToString();
        var sortDirection = string.Equals(sortText, "oldest", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "asc", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sortText, "oldestFirst", StringComparison.OrdinalIgnoreCase)
                ? AuditJournalSortDirection.OldestFirst
                : AuditJournalSortDirection.NewestFirst;

        var query = new AuditJournalQuery
        {
            Severity = severity,
            Action = action,
            RoundNumber = roundNumber,
            BoardNumber = boardNumber,
            PlayerId = playerId,
            SearchText = request.Query["search"].ToString(),
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

    $tokens = @(
        'app.MapGet("/api/tournaments/{id:guid}/round-diagnostics"',
        'app.MapGet("/api/tournaments/{id}/round-diagnostics"',
        'app.MapGet("/api/tournaments/{id:guid}/export/report"',
        'app.MapGet("/api/tournaments/{id}/export/report"',
        'app.Run();'
    )

    foreach ($token in $tokens) {
        $index = $content.IndexOf($token, [StringComparison]::Ordinal)
        if ($index -ge 0) {
            Step "Audit-Journal-Query-Endpunkt vor Token '$token' ergänzt"
            return $content.Insert($index, $endpoint + [Environment]::NewLine)
        }
    }

    throw 'Kein stabiler Einfügepunkt für Audit-Journal-Query-Endpunkt gefunden.'
}

function Invoke-NativeStep([string]$Name, [scriptblock]$Script) {
    Write-Host "[ReleaseGate] $Name..."
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
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
    $program = Remove-ExistingQueryEndpoints $program
    $program = Insert-QueryEndpoint $program
    Write-Utf8NoBom $programPath $program

    $changelogPath = 'CHANGELOG.md'
    $changelog = Read-Text $changelogPath
    if (-not $changelog.Contains('0.37.3')) {
        $entry = @'

## 0.37.3

- Fix: fehlerhaft eingefügten Audit-Journal-Query-Endpunkt entfernt und syntaktisch robust neu eingefügt.
- Queryparameter werden über HttpRequest gelesen, damit die Minimal-API-Signatur stabil bleibt.
- Release-Gate bleibt verpflichtend: Restore, Build, Tests, Frontend-Build und Portable-Paket.
'@
        $changelog = $entry.TrimEnd() + [Environment]::NewLine + $changelog
        Step 'CHANGELOG.md ergänzt'
    }
    else {
        Step 'CHANGELOG.md enthält 0.37.3 bereits'
    }
    Write-Utf8NoBom $changelogPath $changelog

    Write-Utf8NoBom 'docs/HANDOFF_0_37_3.md' (Read-Text 'docs/HANDOFF_0_37_3.md')
    Write-Utf8NoBom 'scripts/After-Apply-V0.37.3.ps1' (Read-Text 'scripts/After-Apply-V0.37.3.ps1')

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
