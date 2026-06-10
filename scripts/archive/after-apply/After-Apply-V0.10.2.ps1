Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string] $Name,
        [scriptblock] $Action
    )

    Write-Host "[v0.10.2] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Invoke-Step "dotnet restore" { dotnet restore }
Invoke-Step "dotnet build" { dotnet build }
Invoke-Step "dotnet test" { dotnet test }

Push-Location "src\SchachTurnierManager.WebApp"
try {
    Invoke-Step "npm install" { npm install }
    Invoke-Step "npm run build" { npm run build }
}
finally {
    Pop-Location
}

Invoke-Step "Pack-Portable" {
    pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Pack-Portable.ps1"
}

Write-Host "[v0.10.2] Optionaler Live-Test:"
Write-Host "  Backend starten: .\scripts\Start-Dev.ps1"
Write-Host "  Smoke-Test:      .\scripts\Run-ExternalLookupSmoke.ps1 -FideId 4610563"
Write-Host "  Live-xUnit:      .\scripts\Run-ExternalLookupSmoke.ps1 -FideId 4610563 -RunLiveTests"
Write-Host "[v0.10.2] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen."
