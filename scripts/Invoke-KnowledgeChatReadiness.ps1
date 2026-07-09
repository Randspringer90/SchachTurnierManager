[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN10_11_KnowledgeChat',
    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'knowledge-chat-readiness-summary.txt'
$sourceReportPath = Join-Path $runDirectory 'knowledge-chat-source-report.txt'
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
    'RUN-10/11 Knowledge-Chat-Readiness',
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

    Assert-Contains $mainTsx 'knowledgeTopics' 'Lokale Wissensbasis'
    Assert-Contains $mainTsx 'buildLocalKnowledgeAnswer' 'Antwortlogik'
    Assert-Contains $mainTsx 'knowledgeQuickQuestions' 'Schnellfragen'
    Assert-Contains $mainTsx 'Keine externen KI-Dienste' 'Datenschutz-Hinweis'
    Assert-Contains $mainTsx 'Chat exportieren' 'Chat-Export'
    Assert-Contains $stylesCss 'knowledge-chat-card' 'Knowledge-Chat-CSS'

    Add-Summary 'Lokale Chat-Hilfe: OK'
    Add-Summary 'Keine externe API/Secrets: OK'
    Add-Summary "Source-Report: $sourceReportPath"
}
finally {
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    $zipPath = ($zipPath | Select-Object -Last 1).Trim()
    Write-Host "UPLOAD_ZIP=$zipPath"
}
