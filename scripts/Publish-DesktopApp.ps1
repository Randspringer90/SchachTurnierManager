param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [switch]$NoZip
)

# Erzeugt die Desktop-Variante: self-contained Backend (kein .NET beim Endnutzer noetig),
# eingebettetes Frontend in wwwroot, Klick-Start ueber SchachTurnierManager.bat.
# Daten liegen unter %LocalAppData%\SchachTurnierManager (Backend-Default, kein Override).
# Ausgabe: output\desktop  (dient auch als Quellordner fuer den Inno-Setup-Installer).

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$root = Resolve-Path "$PSScriptRoot\.."
$outputRoot = Join-Path $root "output"
$desktopRoot = Join-Path $outputRoot "desktop"
$appOutput = Join-Path $desktopRoot "app"
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

    Write-Host "[Publish-Desktop] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Label (ExitCode=$LASTEXITCODE)"
    }
}

Write-Host "[Publish-Desktop] Ziel: $desktopRoot"
Remove-Item -Recurse -Force $desktopRoot -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $appOutput | Out-Null

Push-Location $webApp
try {
    $npmInstallCommand = "install"
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
    "--self-contained", "true",
    "-o", $appOutput,
    "/p:PublishSingleFile=false",
    "/p:UseAppHost=true"
)
Invoke-Checked "dotnet publish (self-contained)" { dotnet @publishArgs }

$wwwroot = Join-Path $appOutput "wwwroot"
New-Item -ItemType Directory -Force -Path $wwwroot | Out-Null
Copy-Item -Path (Join-Path $webAppDist "*") -Destination $wwwroot -Recurse -Force
Copy-Item -Path (Join-Path $root "scripts\Start-Desktop.bat") -Destination (Join-Path $desktopRoot "SchachTurnierManager.bat") -Force

@"
# SchachTurnierManager Desktop $version

Start (Doppelklick):

    SchachTurnierManager.bat

Dashboard (oeffnet sich automatisch):

    http://127.0.0.1:5088/

Daten und Datenbank:

    %LocalAppData%\SchachTurnierManager\

Hinweise:

- Diese Version ist self-contained: es muss kein .NET installiert sein.
- Beim Beenden das minimierte Fenster "SchachTurnierManager" schliessen.
- Laufzeitlogs liegen unter `%LocalAppData%\SchachTurnierManager\logs`.
- Backups im Dashboard ueber den JSON-Export erstellen.
- Keine Dateien in app\ manuell bearbeiten.
"@ | Set-Content -Encoding UTF8 (Join-Path $desktopRoot "README-Desktop.md")

if (-not $NoZip) {
    $zipPath = Join-Path $outputRoot "SchachTurnierManager_Desktop_$version.zip"
    Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
    Compress-Archive -Path (Join-Path $desktopRoot "*") -DestinationPath $zipPath -Force
    Write-Host "[Publish-Desktop] ZIP erstellt: $zipPath"
}

Write-Host "[Publish-Desktop] Desktop-Paket erstellt: $desktopRoot"
Write-Host "[Publish-Desktop] Start: $desktopRoot\SchachTurnierManager.bat"
