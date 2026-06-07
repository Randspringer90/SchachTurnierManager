$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[v0.3.1] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen ($Label). ExitCode=$LASTEXITCODE"
    }
}

Invoke-Checked 'Clean generated files' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Clean-Generated.ps1' }
Invoke-Checked 'dotnet restore' { dotnet restore }
Invoke-Checked 'dotnet build' { dotnet build }
Invoke-Checked 'dotnet test' { dotnet test }

Set-Location '.\src\SchachTurnierManager.WebApp'
Invoke-Checked 'npm install' { npm install }
Invoke-Checked 'npm run build' { npm run build }

Set-Location '..\..\..'
Write-Host '[v0.3.1] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
