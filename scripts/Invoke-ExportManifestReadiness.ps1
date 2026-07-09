[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN15_ExportManifest',
    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'export-manifest-readiness-summary.txt'
$sourceReportPath = Join-Path $runDirectory 'export-manifest-source-report.txt'
$formatter = Join-Path $root 'src\SchachTurnierManager.Domain\Services\TournamentExportFormatter.cs'
$service = Join-Path $root 'src\SchachTurnierManager.Application\TournamentService.cs'
$program = Join-Path $root 'src\SchachTurnierManager.WebApi\Program.cs'
$mainTsx = Join-Path $root 'src\SchachTurnierManager.WebApp\src\main.tsx'
$domainTest = Join-Path $root 'tests\SchachTurnierManager.Domain.Tests\TournamentExportFormatterTests.cs'

function Add-Summary([string]$Line) {
    $Line | Add-Content -Encoding UTF8 -LiteralPath $summaryPath
}

function Invoke-Logged([string]$Name, [string]$CommandLine) {
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-LoggedCommand.ps1') `
        -RunDirectory $runDirectory `
        -Name $Name `
        -WorkingDirectory $root `
        -CommandLine $CommandLine
    if ($LASTEXITCODE -ne 0) {
        throw "$Name ist fehlgeschlagen (ExitCode=$LASTEXITCODE). Details im Run-ZIP."
    }
}

function Assert-FileContains([string]$Path, [string]$Pattern, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Datei fehlt: $Path"
    }

    $content = Get-Content -Raw -LiteralPath $Path
    if ($content -notmatch $Pattern) {
        throw "$Label nicht gefunden in $Path"
    }

    "OK  $Label  $Path" | Add-Content -Encoding UTF8 -LiteralPath $sourceReportPath
}

@(
    'RUN-15 Exportmanifest-Readiness',
    "Created: $(Get-Date -Format o)",
    "RepositoryRoot: $root",
    "RunDirectory: $runDirectory",
    ''
) | Set-Content -Encoding UTF8 -LiteralPath $summaryPath

try {
    if (-not $SkipReleaseGate) {
        Invoke-Logged 'releasegate-skip-pack' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-ReleaseGate.ps1 -SkipPack'
        Add-Summary 'ReleaseGate -SkipPack: OK'
    }
    else {
        Add-Summary 'ReleaseGate -SkipPack: uebersprungen'
    }

    Invoke-Logged 'npm-build' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NpmSafe.ps1 -WorkingDirectory .\src\SchachTurnierManager.WebApp -NpmCommand run -NpmScript build'
    Add-Summary 'Frontend-Build: OK'

    @(
        "Created: $(Get-Date -Format o)",
        "Root: $root",
        ''
    ) | Set-Content -Encoding UTF8 -LiteralPath $sourceReportPath

    Assert-FileContains $formatter 'ExportDownloadManifestJson' 'Domain-Exportmanifest'
    Assert-FileContains $formatter 'schach-turnier-manager\.export-manifest\.v1' 'Manifest-Schema'
    Assert-FileContains $formatter 'local-only' 'Privacy-Grenze im Manifest'
    Assert-FileContains $service 'ExportDownloadManifestJson' 'Application-Service-Methode'
    Assert-FileContains $program 'exports/manifest\.json' 'API-Endpunkt'
    Assert-FileContains $mainTsx 'Exportmanifest JSON' 'UI-Button'
    Assert-FileContains $domainTest 'ExportDownloadManifestJson_ContainsDownloadsAndChecks' 'Domain-Test'

    Add-Summary 'Exportmanifest-Quellmerkmale: OK'
    Add-Summary "Source-Report: $sourceReportPath"
}
finally {
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    $zipPath = ($zipPath | Select-Object -Last 1).Trim()
    Write-Host "UPLOAD_ZIP=$zipPath"
}
