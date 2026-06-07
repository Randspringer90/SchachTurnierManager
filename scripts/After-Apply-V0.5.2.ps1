$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [scriptblock] $Action
    )
    Write-Host "[v0.5.2] $Name..."
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode $LASTEXITCODE)"
    }
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build --no-restore }
Invoke-Step 'dotnet test' { dotnet test --no-build }

Push-Location (Join-Path $root 'src/SchachTurnierManager.WebApp')
try {
    Invoke-Step 'npm install' { npm install }
    Invoke-Step 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

Write-Host '[v0.5.2] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
