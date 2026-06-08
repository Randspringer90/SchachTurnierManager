param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [switch]$SelfContained,
    [switch]$NoZip
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$root = Resolve-Path "$PSScriptRoot\.."
$outputRoot = Join-Path $root "output"
$portableRoot = Join-Path $outputRoot "portable"
$appOutput = Join-Path $portableRoot "app"
$dataDir = Join-Path $portableRoot "data"
$webApp = Join-Path $root "src\SchachTurnierManager.WebApp"
$webApiProject = Join-Path $root "src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj"
$packageJsonPath = Join-Path $webApp "package.json"
$version = "dev"
if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) {
        $version = [string]$packageJson.version
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[Pack-Portable] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Label (ExitCode=$LASTEXITCODE)"
    }
}

Write-Host "[Pack-Portable] Ziel: $portableRoot"
Remove-Item -Recurse -Force $portableRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $appOutput, $dataDir | Out-Null

Push-Location $webApp
try {
    Invoke-Checked "npm install" { npm install }
    Invoke-Checked "npm run build" { npm run build }
}
finally {
    Pop-Location
}

$publishArgs = @(
    "publish",
    $webApiProject,
    "-c", $Configuration,
    "-r", $Runtime,
    "--self-contained", $SelfContained.IsPresent.ToString().ToLowerInvariant(),
    "-o", $appOutput,
    "/p:PublishSingleFile=false",
    "/p:UseAppHost=true"
)
Invoke-Checked "dotnet publish" { dotnet @publishArgs }

$wwwroot = Join-Path $appOutput "wwwroot"
New-Item -ItemType Directory -Force -Path $wwwroot | Out-Null
Copy-Item -Path (Join-Path $webApp "dist\*") -Destination $wwwroot -Recurse -Force
Copy-Item -Path (Join-Path $root "scripts\Start-Portable.bat") -Destination (Join-Path $portableRoot "Start-SchachTurnierManager.bat") -Force

@"
# SchachTurnierManager Portable $version

Start:

    Start-SchachTurnierManager.bat

Dashboard:

    http://127.0.0.1:5088/

API-Healthcheck:

    http://127.0.0.1:5088/api/health

Datenbank:

    data\SchachTurnierManager.sqlite

Hinweise:

- Dieses Paket ist eine portable lokale Version.
- Es benötigt bei framework-dependent Publish ein installiertes .NET 10 Runtime/SDK.
- Für ein paketiertes .NET kann Pack-Portable.ps1 mit -SelfContained ausgeführt werden.
- Keine Dateien aus app\ manuell bearbeiten.
- Für Backups im Dashboard JSON-Export verwenden.
"@ | Set-Content -Encoding UTF8 (Join-Path $portableRoot "README-Portable.md")

if (-not $NoZip) {
    $zipPath = Join-Path $outputRoot "SchachTurnierManager_Portable_$version.zip"
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $portableRoot "*") -DestinationPath $zipPath -Force
    Write-Host "[Pack-Portable] ZIP erstellt: $zipPath"
}

Write-Host "[Pack-Portable] Portable Paket erstellt: $portableRoot"
Write-Host "[Pack-Portable] Start: $portableRoot\Start-SchachTurnierManager.bat"
