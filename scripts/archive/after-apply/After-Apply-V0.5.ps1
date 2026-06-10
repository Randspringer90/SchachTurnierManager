$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[v0.5] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen ($Label). ExitCode=$LASTEXITCODE"
    }
}

Invoke-Checked 'dotnet restore' { dotnet restore }
Invoke-Checked 'dotnet build' { dotnet build --no-restore }
Invoke-Checked 'dotnet test' { dotnet test --no-build }

Push-Location '.\src\SchachTurnierManager.WebApp'
try {
    Invoke-Checked 'npm install' { npm install }
    Invoke-Checked 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

Write-Host '[v0.5] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
