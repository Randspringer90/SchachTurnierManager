$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.14.0] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Set-TextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Content
    )
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$contractsPath = Join-Path $root 'src/SchachTurnierManager.WebApi/Contracts.cs'
$contracts = Get-Content -LiteralPath $contractsPath -Raw
if ($contracts -notmatch 'PreviewPlayersCsvRequest') {
    $contracts = $contracts.Replace(
        'public sealed record ImportPlayersCsvRequest(string Content, bool ReplaceExisting = false);',
        'public sealed record ImportPlayersCsvRequest(string Content, bool ReplaceExisting = false);' + [Environment]::NewLine + [Environment]::NewLine +
        'public sealed record PreviewPlayersCsvRequest(string Content, bool ReplaceExisting = false);'
    )
    Set-TextFile -Path $contractsPath -Content $contracts
    Write-Host '[v0.14.0] Contracts.cs um PreviewPlayersCsvRequest ergänzt.' -ForegroundColor Yellow
}

$tournamentServicePath = Join-Path $root 'src/SchachTurnierManager.Application/TournamentService.cs'
$tournamentService = Get-Content -LiteralPath $tournamentServicePath -Raw
if ($tournamentService -notmatch 'PlayerImportPreviewService _playerImportPreview') {
    $tournamentService = $tournamentService.Replace(
        '    private readonly ExternalPlayerImportService _externalPlayerImport = new();',
        '    private readonly ExternalPlayerImportService _externalPlayerImport = new();' + [Environment]::NewLine +
        '    private readonly PlayerImportPreviewService _playerImportPreview = new();'
    )
}
if ($tournamentService -notmatch 'PreviewPlayersCsv\(Guid tournamentId') {
    $method = @'
    public PlayerImportPreview PreviewPlayersCsv(Guid tournamentId, string csv, bool replaceExisting)
    {
        return _playerImportPreview.Preview(RequireTournament(tournamentId), csv, replaceExisting);
    }

'@
    $tournamentService = $tournamentService.Replace('    public IReadOnlyList<Player> ImportPlayersCsv', $method + '    public IReadOnlyList<Player> ImportPlayersCsv')
}
Set-TextFile -Path $tournamentServicePath -Content $tournamentService

$programPath = Join-Path $root 'src/SchachTurnierManager.WebApi/Program.cs'
$program = Get-Content -LiteralPath $programPath -Raw
$program = $program.Replace('version = "0.13.0"', 'version = "0.14.0"')
if ($program -notmatch 'preview-import\.csv') {
    $endpoint = @'
app.MapPost("/api/tournaments/{id:guid}/players/preview-import.csv", (Guid id, PreviewPlayersCsvRequest request, TournamentService service) =>
{
    try
    {
        return Results.Ok(service.PreviewPlayersCsv(id, request.Content, request.ReplaceExisting));
    }
    catch (Exception ex) when (ex is InvalidOperationException or ArgumentException)
    {
        return Results.BadRequest(new { error = ex.Message });
    }
});

'@
    $program = $program.Replace('app.MapPost("/api/tournaments/{id:guid}/players/import.csv"', $endpoint + 'app.MapPost("/api/tournaments/{id:guid}/players/import.csv"')
}
Set-TextFile -Path $programPath -Content $program

$packageJsonPath = Join-Path $root 'src/SchachTurnierManager.WebApp/package.json'
if (Test-Path $packageJsonPath) {
    $json = Get-Content -LiteralPath $packageJsonPath -Raw
    $json = [regex]::Replace($json, '"version"\s*:\s*"0\.13\.0"', '"version": "0.14.0"')
    Set-TextFile -Path $packageJsonPath -Content $json
}

$packageLockPath = Join-Path $root 'src/SchachTurnierManager.WebApp/package-lock.json'
if (Test-Path $packageLockPath) {
    $lock = Get-Content -LiteralPath $packageLockPath -Raw
    $lock = [regex]::Replace($lock, '"version"\s*:\s*"0\.13\.0"', '"version": "0.14.0"')
    Set-TextFile -Path $packageLockPath -Content $lock
}

$mainTsxPath = Join-Path $root 'src/SchachTurnierManager.WebApp/src/main.tsx'
if (Test-Path $mainTsxPath) {
    $main = Get-Content -LiteralPath $mainTsxPath -Raw
    $main = $main.Replace('Lokaler Turnierleiter · v0.13.0', 'Lokaler Turnierleiter · v0.14.0')
    Set-TextFile -Path $mainTsxPath -Content $main
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }

$webApp = Join-Path $root 'src/SchachTurnierManager.WebApp'
Set-Location $webApp
Invoke-Step 'npm install' { npm install }
Invoke-Step 'npm run build' { npm run build }

Set-Location $root
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/Pack-Portable.ps1') }

Write-Host '[v0.14.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
