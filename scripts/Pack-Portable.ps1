# CmdletBinding ist Absicht: ohne das nimmt PowerShell unbekannte benannte
# Argumente stillschweigend entgegen. Test-PortablePackageGate.ps1 hat darum
# lange in das echte output/ gebaut statt in seinen tmp-Ordner, ohne Fehler.
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [switch]$SelfContained,
    [switch]$NoZip,

    # Zielwurzel fuer das portable Paket. Standard ist output/ im Repo; Gates
    # bauen damit hermetisch nach tmp/, ohne das echte Paket zu ueberschreiben.
    [string]$OutputRoot,
    [switch]$SignArtifacts,
    [string]$SigningCertificateThumbprint,
    [string]$TimestampServer
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$root = Resolve-Path "$PSScriptRoot\.."
$outputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) { Join-Path $root "output" } else { $OutputRoot }
# The package folder below is deleted recursively, so the target must resolve to the
# repository's own output\ or tmp\ tree (Test-PortablePackageGate uses tmp\).
$outputRoot = [System.IO.Path]::GetFullPath([string]$outputRoot)
$allowedRoots = @('output', 'tmp') | ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path ([string]$root) $_)).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar }
$candidate = $outputRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not ($allowedRoots | Where-Object { $candidate.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })) {
    throw "OutputRoot muss innerhalb von output\ oder tmp\ des Repositorys liegen: $outputRoot"
}
$portableRoot = Join-Path $outputRoot "portable"
$appOutput = Join-Path $portableRoot "app"
$dataDir = Join-Path $portableRoot "data"
$webApp = Join-Path $root "src\SchachTurnierManager.WebApp"
$webAppDist = Join-Path $root "tmp\webapp-dist"
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
# The lexical check above is not enough: a junction or symlink anywhere between the
# allowed root (output\ or tmp\) and the delete target could redirect the recursive
# delete outside the repository. Every existing component on that path, including the
# allowed root itself, must therefore be a real directory.
$allowedBase = ($allowedRoots | Where-Object { $candidate.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1).TrimEnd('\', '/')
$cursor = [System.IO.Path]::GetFullPath($portableRoot).TrimEnd('\', '/')
while ($true) {
    if (Test-Path -LiteralPath $cursor) {
        if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Pfadkomponente ist ein Link/Reparse-Point; Paketziel wird nicht geloescht: $cursor"
        }
    }
    if ($cursor -ieq $allowedBase) { break }
    $parent = Split-Path -Parent $cursor
    if ([string]::IsNullOrEmpty($parent) -or $parent -eq $cursor) { throw "Paketziel liegt nicht unter $allowedBase" }
    $cursor = $parent.TrimEnd('\', '/')
}
if (Test-Path -LiteralPath $portableRoot) {
    Remove-Item -LiteralPath $portableRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $appOutput, $dataDir | Out-Null

Push-Location $webApp
try {
    # npm ci installs exactly the checked lockfile (STM-SEC-002); npm install could rewrite it.
    $npmInstallCommand = "ci"
    Invoke-Checked "npm $npmInstallCommand" { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\Invoke-NpmSafe.ps1") -WorkingDirectory $webApp -NpmCommand $npmInstallCommand -NoAudit -NoFund }
    Invoke-Checked "npm run build" { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\Invoke-NpmSafe.ps1") -WorkingDirectory $webApp -NpmCommand run -NpmScript build }
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
Copy-Item -Path (Join-Path $webAppDist "*") -Destination $wwwroot -Recurse -Force
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
- Laufzeitlogs liegen im portablen Ordner `logs\`.
- Keine Dateien aus app\ manuell bearbeiten.
- Für Backups im Dashboard JSON-Export verwenden.
"@ | Set-Content -Encoding UTF8 (Join-Path $portableRoot "README-Portable.md")

if ($SignArtifacts) {
    if ([string]::IsNullOrWhiteSpace($SigningCertificateThumbprint)) {
        throw '-SignArtifacts verlangt -SigningCertificateThumbprint.'
    }

    $signArgs = @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass',
        '-File',(Join-Path $PSScriptRoot 'Sign-ReleaseArtifacts.ps1'),
        '-ArtifactPath',(Join-Path $appOutput 'SchachTurnierManager.WebApi.exe'),
        '-CertificateThumbprint',$SigningCertificateThumbprint,
        '-ApproveSigning'
    )
    if (-not [string]::IsNullOrWhiteSpace($TimestampServer)) {
        $signArgs += @('-TimestampServer',$TimestampServer)
    }

    & pwsh.exe @signArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Sign-ReleaseArtifacts.ps1 fehlgeschlagen (ExitCode=$LASTEXITCODE)."
    }
}

if (-not $NoZip) {
    $zipPath = Join-Path $outputRoot "SchachTurnierManager_Portable_$version.zip"
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $portableRoot "*") -DestinationPath $zipPath -Force
    Write-Host "[Pack-Portable] ZIP erstellt: $zipPath"
}

Write-Host "[Pack-Portable] Portable Paket erstellt: $portableRoot"
Write-Host "[Pack-Portable] Start: $portableRoot\Start-SchachTurnierManager.bat"
