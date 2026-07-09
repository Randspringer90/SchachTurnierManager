[CmdletBinding()]
param(
    [string]$RunName = 'STM_RUN08_PwaReadiness',
    [switch]$SkipReleaseGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunName $RunName -CreateOnly
$runDirectory = ($runDirectory | Select-Object -Last 1).Trim()
$summaryPath = Join-Path $runDirectory 'pwa-readiness-summary.txt'
$manifestReportPath = Join-Path $runDirectory 'pwa-manifest-report.txt'
$distRoot = Join-Path $root 'tmp\webapp-dist'

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

function Assert-File([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label fehlt: $Path"
    }
    $item = Get-Item -LiteralPath $Path
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    "OK  $Label  $($item.FullName)  Size=$($item.Length)  SHA256=$($hash.Hash)" | Add-Content -Encoding UTF8 -LiteralPath $manifestReportPath
}

@(
    'RUN-08 PWA-Readiness',
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
        Add-Summary 'ReleaseGate -SkipPack: übersprungen'
    }

    Invoke-Logged 'npm-build' 'pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-NpmSafe.ps1 -WorkingDirectory .\src\SchachTurnierManager.WebApp -NpmCommand run -NpmScript build'
    Add-Summary 'Frontend-Build: OK'

    if (-not (Test-Path -LiteralPath $distRoot)) {
        throw "Vite-Ausgabeordner fehlt: $distRoot"
    }

    @(
        "DistRoot: $distRoot",
        "Created: $(Get-Date -Format o)",
        ''
    ) | Set-Content -Encoding UTF8 -LiteralPath $manifestReportPath

    Assert-File (Join-Path $distRoot 'index.html') 'index.html'
    Assert-File (Join-Path $distRoot 'manifest.webmanifest') 'manifest.webmanifest'
    Assert-File (Join-Path $distRoot 'service-worker.js') 'service-worker.js'
    Assert-File (Join-Path $distRoot 'icons\stm-icon.svg') 'icon.svg'
    Assert-File (Join-Path $distRoot 'icons\stm-maskable.svg') 'maskable-icon.svg'

    $indexHtml = Get-Content -Raw -LiteralPath (Join-Path $distRoot 'index.html')
    if ($indexHtml -notmatch 'rel="manifest"') { throw 'index.html enthält keinen Manifest-Link.' }
    if ($indexHtml -notmatch 'theme-color') { throw 'index.html enthält keine theme-color-Meta-Angabe.' }

    $manifest = Get-Content -Raw -LiteralPath (Join-Path $distRoot 'manifest.webmanifest') | ConvertFrom-Json
    if ($manifest.name -ne 'SchachTurnierManager') { throw "Manifest.name unerwartet: $($manifest.name)" }
    if ($manifest.display -ne 'standalone') { throw "Manifest.display ist nicht standalone: $($manifest.display)" }
    if (-not $manifest.icons -or $manifest.icons.Count -lt 2) { throw 'Manifest enthält weniger als zwei Icons.' }

    $serviceWorker = Get-Content -Raw -LiteralPath (Join-Path $distRoot 'service-worker.js')
    if ($serviceWorker -notmatch "startsWith\('/api/'\)") { throw 'Service Worker muss /api/ bewusst vom Cache ausschließen.' }
    if ($serviceWorker -notmatch 'CACHE_NAME') { throw 'Service Worker enthält keinen Cache-Namen.' }

    Add-Summary 'PWA-Manifest: OK'
    Add-Summary 'Service Worker: OK (App-Shell cachebar, /api network-only)'
    Add-Summary "PWA-Report: $manifestReportPath"
}
finally {
    $zipPath = pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'New-RunLogBundle.ps1') -RunDirectory $runDirectory -RunName $RunName
    $zipPath = ($zipPath | Select-Object -Last 1).Trim()
    Write-Host "UPLOAD_ZIP=$zipPath"
}
