[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN11_KnowledgeBaseExternalized',
    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'knowledge-base-readiness-summary.txt'
$sourceReportPath = Join-Path $runDirectory 'knowledge-base-source-report.txt'
$webAppRoot = Join-Path $root 'src\SchachTurnierManager.WebApp'
$mainTsx = Join-Path $webAppRoot 'src\main.tsx'
$knowledgeJson = Join-Path $webAppRoot 'src\knowledge\localKnowledgeBase.json'
$knowledgeReadme = Join-Path $webAppRoot 'src\knowledge\README.md'
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

function Assert-KnowledgeBase([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Wissensbasis fehlt: $Path"
    }

    $json = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    if ($json.providerMode -ne 'local-only') {
        throw "providerMode muss local-only sein. Ist: $($json.providerMode)"
    }
    if (-not $json.privacyNotice -or $json.privacyNotice -notmatch 'keine|Keine') {
        throw 'privacyNotice fehlt oder ist zu schwach.'
    }
    if (-not $json.quickQuestions -or $json.quickQuestions.Count -lt 6) {
        throw 'Zu wenige Schnellfragen in der Wissensbasis.'
    }
    if (-not $json.topics -or $json.topics.Count -lt 8) {
        throw 'Zu wenige Wissensartikel in der Wissensbasis.'
    }

    $index = 0
    foreach ($topic in $json.topics) {
        $index++
        foreach ($field in @('id','title','answer')) {
            if (-not $topic.$field) {
                throw "Topic ${index}: Feld ${field} fehlt."
            }
        }
        if (-not $topic.keywords -or $topic.keywords.Count -lt 3) {
            throw "Topic $($topic.id): mindestens 3 Keywords erforderlich."
        }
        if (-not $topic.steps -or $topic.steps.Count -lt 2) {
            throw "Topic $($topic.id): mindestens 2 Schritte erforderlich."
        }
        if (-not $topic.sources -or $topic.sources.Count -lt 1) {
            throw "Topic $($topic.id): mindestens 1 Quelle erforderlich."
        }
    }

    "OK  JSON-Wissensbasis  $Path" | Add-Content -Encoding UTF8 -LiteralPath $sourceReportPath
    "Topics: $($json.topics.Count)" | Add-Content -Encoding UTF8 -LiteralPath $sourceReportPath
    "QuickQuestions: $($json.quickQuestions.Count)" | Add-Content -Encoding UTF8 -LiteralPath $sourceReportPath
    "SourceVersion: $($json.sourceVersion)" | Add-Content -Encoding UTF8 -LiteralPath $sourceReportPath
}

@(
    'RUN-11 Knowledge-Base-Readiness',
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

    Assert-KnowledgeBase $knowledgeJson
    Assert-FileContains $knowledgeReadme 'Keine echten Turnierdaten' 'Knowledge-README mit Datenschutzregel'
    Assert-FileContains $mainTsx 'rawLocalKnowledgeBase' 'JSON-Import im UI'
    Assert-FileContains $mainTsx 'localKnowledgeBase\.topics' 'Topics aus JSON statt Inline-Monolith'
    Assert-FileContains $mainTsx 'localKnowledgeBase\.privacyNotice' 'Privacy Notice aus Wissensbasis'
    Assert-FileContains $stylesCss 'knowledge-source-meta' 'Knowledge-Source-Meta-CSS'

    Add-Summary 'Externe JSON-Wissensbasis: OK'
    Add-Summary 'Lokale Provider-Grenze: OK'
    Add-Summary "Source-Report: $sourceReportPath"
}
finally {
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    $zipPath = ($zipPath | Select-Object -Last 1).Trim()
    Write-Host "UPLOAD_ZIP=$zipPath"
}
