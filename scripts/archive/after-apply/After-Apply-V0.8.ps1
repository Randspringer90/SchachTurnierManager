$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = Resolve-Path "$PSScriptRoot\.."

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[v0.8] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Label (ExitCode=$LASTEXITCODE)"
    }
}

Set-Location $root
Invoke-Checked "dotnet restore" { dotnet restore }
Invoke-Checked "dotnet build" { dotnet build --no-restore }
Invoke-Checked "dotnet test" { dotnet test --no-build }

Push-Location (Join-Path $root "src\SchachTurnierManager.WebApp")
try {
    Invoke-Checked "npm install" { npm install }
    Invoke-Checked "npm run build" { npm run build }
}
finally {
    Pop-Location
}

Invoke-Checked "Pack-Portable" { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\Pack-Portable.ps1") -NoZip }

Write-Host "[v0.8] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen."
