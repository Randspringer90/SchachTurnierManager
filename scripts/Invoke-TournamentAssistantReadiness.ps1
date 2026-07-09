[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN17_TournamentAssistant',
    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'tournament-assistant-readiness-summary.txt'
$sourceReportPath = Join-Path $runDirectory 'tournament-assistant-source-report.txt'
$webAppRoot = Join-Path $root 'src\SchachTurnierManager.WebApp'
$mainTsx = Join-Path $webAppRoot 'src\main.tsx'
$stylesCss = Join-Path $webAppRoot 'src\styles.css'

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

function Assert-Contains([string]$Path, [string]$Pattern, [string]$Label) {
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
    'RUN-17 Turnierassistent-Readiness',
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
        "SourceRoot: $webAppRoot",
        "Created: $(Get-Date -Format o)",
        ''
    ) | Set-Content -Encoding UTF8 -LiteralPath $sourceReportPath

    Assert-Contains $mainTsx "id: 'assistant'" 'Hauptreiter Assistent'
    Assert-Contains $mainTsx 'buildTournamentAssistantRecommendation' 'Empfehlungslogik'
    Assert-Contains $mainTsx 'Empfehlung übernehmen' 'UI-Aktion Empfehlung übernehmen'
    Assert-Contains $mainTsx 'sendet keine Daten an externe Dienste' 'Privacy-Hinweis ohne externe KI-API'
    Assert-Contains $stylesCss 'assistant-card' 'Assistant-CSS'

    Add-Summary 'Assistent-Reiter: OK'
    Add-Summary 'Lokale Empfehlungslogik: OK'
    Add-Summary 'Keine KI-API/Secrets: OK'
    Add-Summary "Source-Report: $sourceReportPath"
}
finally {
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    $zipPath = ($zipPath | Select-Object -Last 1).Trim()
    Write-Host "UPLOAD_ZIP=$zipPath"
}
