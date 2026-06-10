$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$ScriptBlock
    )
    Write-Host "[v0.7] $Name..."
    & $ScriptBlock
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }

Set-Location (Join-Path $root 'src\SchachTurnierManager.WebApp')
Invoke-Step 'npm install' { npm install }
Invoke-Step 'npm run build' { npm run build }

Set-Location $root
Write-Host '[v0.7] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
