$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.11.1] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }

$webApp = Join-Path $root 'src/SchachTurnierManager.WebApp'
Set-Location $webApp
Invoke-Step 'npm install' { npm install }
Invoke-Step 'npm run build' { npm run build }

Set-Location $root
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/Pack-Portable.ps1') }

Write-Host '[v0.11.1] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
