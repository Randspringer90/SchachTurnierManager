param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host '[Commit-Checkpoint] Prüfe Arbeitsstand...'
git status --short

Write-Host '[Commit-Checkpoint] Führe Backend-Checks aus...'
dotnet build
dotnet test

Write-Host '[Commit-Checkpoint] Führe Frontend-Checks aus...'
Push-Location (Join-Path $repoRoot 'src\SchachTurnierManager.WebApp')
npm install
npm run build
Pop-Location

Write-Host '[Commit-Checkpoint] Committe Änderungen...'
git add .
git commit -m $Message

if ($Push) {
    Write-Host '[Commit-Checkpoint] Push...'
    git push
}
else {
    Write-Host '[Commit-Checkpoint] Nicht gepusht. Mit -Push erneut ausführen oder manuell git push starten.'
}
