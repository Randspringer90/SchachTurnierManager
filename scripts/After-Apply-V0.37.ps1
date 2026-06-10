Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$Version = '0.37.0'

function Write-Step {
    param([string]$Message)
    Write-Host "[v$Version] $Message"
}

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { throw "Datei nicht gefunden: $RelativePath" }
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [Parameter(Mandatory = $true)][string]$Content)
    $path = Join-Path $Root $RelativePath
    $parent = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $Content, $Utf8NoBom)
}

function Normalize-TextFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $path = Join-Path $Root $RelativePath
    if (Test-Path -LiteralPath $path) {
        $content = [System.IO.File]::ReadAllText($path)
        [System.IO.File]::WriteAllText($path, $content, $Utf8NoBom)
        Write-Step "$RelativePath als UTF-8 ohne BOM gespeichert"
    }
}

function Set-VersionInFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $text = Read-Text $RelativePath
    $updated = $text
    foreach ($old in @('0.36.1','0.36.0','0.35.3','0.35.2','0.35.1','0.35.0')) {
        $updated = $updated.Replace($old, $Version)
    }
    if ($updated -ne $text) {
        Write-Text $RelativePath $updated
        Write-Step "$RelativePath auf $Version gesetzt"
    } elseif ($text.Contains($Version)) {
        Write-Step "$RelativePath ist bereits auf $Version"
    } else {
        Write-Step "$RelativePath enthielt keine bekannte Vorversion"
    }
}

function Ensure-Changelog {
    $relativePath = 'CHANGELOG.md'
    $text = Read-Text $relativePath
    $marker = '## 0.37.0 - Audit-Journal Query API'
    if ($text.Contains($marker)) {
        Write-Step 'CHANGELOG.md enthält 0.37.0 bereits'
        return
    }

    $entry = @'
## 0.37.0 - Audit-Journal Query API

- API-Endpunkt `/api/tournaments/{id}/audit-journal/query` ergänzt.
- Audit-Journal kann serverseitig nach Schweregrad, Aktion, Runde, Brett, Spieler, Freitext, Sortierung und Maximalanzahl gefiltert werden.
- Grundlage geschaffen, damit das Dashboard im nächsten Schritt echte Filter statt nur clientseitiger Listen nutzen kann.

'@
    Write-Text $relativePath ($entry + $text)
    Write-Step 'CHANGELOG.md ergänzt'
}

function Ensure-AuditQueryApi {
    $relativePath = 'src/SchachTurnierManager.WebApi/Program.cs'
    $text = Read-Text $relativePath

    if (-not $text.Contains('using SchachTurnierManager.Domain.Services;')) {
        $token = 'using SchachTurnierManager.Domain.Models;'
        if (-not $text.Contains($token)) { throw "Using-Anker nicht gefunden in $relativePath" }
        $text = $text.Replace($token, $token + ' using SchachTurnierManager.Domain.Services;')
        Write-Step 'Program.cs: using SchachTurnierManager.Domain.Services ergänzt'
    } else {
        Write-Step 'Program.cs: using SchachTurnierManager.Domain.Services bereits vorhanden'
    }

    if (-not $text.Contains('/api/tournaments/{id:guid}/audit-journal/query')) {
        $auditEndpoint = 'app.MapGet("/api/tournaments/{id:guid}/audit-journal", (Guid id, TournamentService service) => { try { return Results.Ok(service.GetAuditJournal(id)); } catch (InvalidOperationException ex) { return Results.NotFound(new { error = ex.Message }); } });'
        if (-not $text.Contains($auditEndpoint)) { throw "Audit-Journal-Endpunkt-Anker nicht gefunden in $relativePath" }

        $queryEndpoint = @'
 app.MapGet("/api/tournaments/{id:guid}/audit-journal/query", (Guid id, string? severity, string? action, int? roundNumber, int? boardNumber, Guid? playerId, string? search, int? maxResults, string? sort, TournamentService service) => { try { var query = new AuditJournalQuery { Severity = ParseNullableEnum<AuditJournalSeverity>(severity), Action = ParseNullableEnum<AuditJournalAction>(action), RoundNumber = roundNumber, BoardNumber = boardNumber, PlayerId = playerId, SearchText = search, MaxResults = maxResults, SortDirection = IsOldestFirst(sort) ? AuditJournalSortDirection.OldestFirst : AuditJournalSortDirection.NewestFirst }; return Results.Ok(new AuditJournalQueryService().Query(service.GetAuditJournal(id), query)); } catch (InvalidOperationException ex) { return Results.NotFound(new { error = ex.Message }); } });
'@
        $text = $text.Replace($auditEndpoint, $auditEndpoint + $queryEndpoint)
        Write-Step 'Program.cs: Audit-Journal Query API ergänzt'
    } else {
        Write-Step 'Program.cs: Audit-Journal Query API bereits vorhanden'
    }

    if (-not $text.Contains('static bool IsOldestFirst(string? value)')) {
        $helperAnchor = 'static bool TryParseExternalPlayerSource(string? value, out ExternalPlayerSource source)'
        if (-not $text.Contains($helperAnchor)) { throw "Helper-Anker nicht gefunden in $relativePath" }
        $helpers = @'
static TEnum? ParseNullableEnum<TEnum>(string? value) where TEnum : struct, Enum { if (string.IsNullOrWhiteSpace(value)) { return null; } return Enum.TryParse<TEnum>(value, ignoreCase: true, out var parsed) ? parsed : null; } static bool IsOldestFirst(string? value) { return string.Equals(value, "oldest", StringComparison.OrdinalIgnoreCase) || string.Equals(value, "oldestFirst", StringComparison.OrdinalIgnoreCase) || string.Equals(value, "OldestFirst", StringComparison.OrdinalIgnoreCase) || string.Equals(value, "asc", StringComparison.OrdinalIgnoreCase) || string.Equals(value, "ascending", StringComparison.OrdinalIgnoreCase); } 
'@
        $text = $text.Replace($helperAnchor, $helpers + $helperAnchor)
        Write-Step 'Program.cs: Audit-Journal Query Helper ergänzt'
    } else {
        Write-Step 'Program.cs: Audit-Journal Query Helper bereits vorhanden'
    }

    Write-Text $relativePath $text
}

function Invoke-Step {
    param([Parameter(Mandatory = $true)][string]$Name, [Parameter(Mandatory = $true)][scriptblock]$Command)
    Write-Step "$Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen mit Exitcode $LASTEXITCODE."
    }
}

try {
    Set-VersionInFile 'src/SchachTurnierManager.WebApi/Program.cs'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/package-lock.json'
    Set-VersionInFile 'src/SchachTurnierManager.WebApp/src/main.tsx'

    Ensure-AuditQueryApi
    Ensure-Changelog

    foreach ($file in @(
        'CHANGELOG.md',
        'src/SchachTurnierManager.WebApi/Program.cs',
        'src/SchachTurnierManager.WebApp/package.json',
        'src/SchachTurnierManager.WebApp/package-lock.json',
        'src/SchachTurnierManager.WebApp/src/main.tsx',
        'docs/HANDOFF_0_37_0.md',
        'scripts/After-Apply-V0.37.ps1'
    )) {
        Normalize-TextFile $file
    }

    Invoke-Step 'Release-Gate' { & (Join-Path $Root 'scripts/Invoke-ReleaseGate.ps1') }

    Write-Step 'Nachkontrolle abgeschlossen. Aktueller Git-Status:'
    git -C $Root status --short
}
catch {
    Write-Error $_
    exit 1
}
