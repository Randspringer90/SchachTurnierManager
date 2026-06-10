$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )
    Write-Host "[v0.6] $Name..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode $LASTEXITCODE)"
    }
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build --no-restore }
Invoke-Step 'dotnet test' { dotnet test --no-build }

$webApp = Join-Path $root 'src\SchachTurnierManager.WebApp'
Push-Location $webApp
try {
    Invoke-Step 'npm install' { npm install }
    Invoke-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

Write-Host '[v0.6] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
