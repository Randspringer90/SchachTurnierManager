$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[v0.4.1] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen ($Label). ExitCode=$LASTEXITCODE"
    }
}

Set-Location $root
Invoke-Checked "dotnet restore" { dotnet restore }
Invoke-Checked "dotnet build" { dotnet build --no-restore }
Invoke-Checked "dotnet test" { dotnet test --no-build }

Set-Location (Join-Path $root "src\SchachTurnierManager.WebApp")
Invoke-Checked "npm install" { npm install }
Invoke-Checked "npm run build" { npm run build }

Set-Location $root
Write-Host "[v0.4.1] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen."
