param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    Write-Host "[Commit-Checkpoint] $Label..."
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Checkpoint abgebrochen: Schritt fehlgeschlagen ($Label). ExitCode=$LASTEXITCODE"
    }
}

Write-Host '[Commit-Checkpoint] Prüfe Arbeitsstand...'
git status --short

Invoke-Checked 'dotnet restore' { dotnet restore }
Invoke-Checked 'dotnet build' { dotnet build --no-restore }
Invoke-Checked 'dotnet test' { dotnet test --no-build }

Push-Location (Join-Path $repoRoot 'src\SchachTurnierManager.WebApp')
try {
    Invoke-Checked 'npm install' { npm install }
    Invoke-Checked 'npm run build' { npm run build }
}
finally {
    Pop-Location
}

$status = git status --short
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host '[Commit-Checkpoint] Keine Änderungen zu committen.'
}
else {
    Invoke-Checked 'git add .' { git add . }
    Invoke-Checked "git commit: $Message" { git commit -m $Message }
}

if ($Push) {
    Invoke-Checked 'git push' { git push }
}
else {
    Write-Host '[Commit-Checkpoint] Nicht gepusht. Mit -Push erneut ausführen oder manuell git push starten.'
}
