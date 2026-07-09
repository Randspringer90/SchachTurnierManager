param(
    [switch]$SkipPublish,
    [string]$InnoSetupCompiler
)

# Baut die Installer-EXE (Inno Setup) aus dem Desktop-Paket.
# 1. scripts\Publish-DesktopApp.ps1 erzeugt output\desktop (self-contained + Frontend).
# 2. ISCC.exe kompiliert installer\SchachTurnierManager.iss nach output\installer.
# Inno Setup 6 muss lokal installiert sein: https://jrsoftware.org/isinfo.php

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$root = Resolve-Path "$PSScriptRoot\.."
$desktopRoot = Join-Path $root "output\desktop"
$issFile = Join-Path $root "installer\SchachTurnierManager.iss"
$packageJsonPath = Join-Path $root "src\SchachTurnierManager.WebApp\package.json"

$version = "0.0.0-dev"
if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
    if ($packageJson.version) {
        $version = [string]$packageJson.version
    }
}

if (-not $SkipPublish -or -not (Test-Path (Join-Path $desktopRoot "app"))) {
    & (Join-Path $PSScriptRoot "Publish-DesktopApp.ps1") -NoZip
    if ($LASTEXITCODE -ne 0) {
        throw "Publish-DesktopApp.ps1 fehlgeschlagen (ExitCode=$LASTEXITCODE)"
    }
}

if (-not [string]::IsNullOrWhiteSpace($InnoSetupCompiler)) {
    if (-not (Test-Path -LiteralPath $InnoSetupCompiler)) {
        Write-Error "Angegebener Inno-Setup-Compiler wurde nicht gefunden: $InnoSetupCompiler"
        exit 1
    }
    $isccCandidates = @((Resolve-Path -LiteralPath $InnoSetupCompiler).Path)
}
else {
    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    $isccCandidates = @()
    if ($command) { $isccCandidates += $command.Source }
    $isccCandidates += @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LocalAppData\Programs\Inno Setup 6\ISCC.exe"
    )
    $isccCandidates = @($isccCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
}

if (-not $isccCandidates) {
    Write-Error @"
ISCC.exe (Inno Setup 6) wurde nicht gefunden.
Installation (Open Source, kostenlos): https://jrsoftware.org/isinfo.php
Danach erneut ausfuehren:
    pwsh -File .\scripts\Build-Installer.ps1 -SkipPublish
Oder den Pfad explizit angeben:
    pwsh -File .\scripts\Build-Installer.ps1 -SkipPublish -InnoSetupCompiler "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
"@
    exit 1
}

$iscc = $isccCandidates | Select-Object -First 1
Write-Host "[Build-Installer] ISCC: $iscc"
Write-Host "[Build-Installer] Version: $version"

& $iscc "/DMyAppVersion=$version" $issFile
if ($LASTEXITCODE -ne 0) {
    throw "ISCC fehlgeschlagen (ExitCode=$LASTEXITCODE)"
}

Write-Host "[Build-Installer] Installer erstellt unter: $(Join-Path $root 'output\installer')"

$installerRoot = Join-Path $root 'output\installer'
$setupFiles = @(Get-ChildItem -LiteralPath $installerRoot -Filter 'SchachTurnierManager_Setup_*.exe' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
if ($setupFiles.Count -gt 0) {
    $latest = $setupFiles | Select-Object -First 1
    $hash = Get-FileHash -LiteralPath $latest.FullName -Algorithm SHA256
    Write-Host "[Build-Installer] Setup: $($latest.FullName)"
    Write-Host "[Build-Installer] SHA256: $($hash.Hash)"
}
