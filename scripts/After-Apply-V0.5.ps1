$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host '[v0.5] dotnet restore...'
dotnet restore
Write-Host '[v0.5] dotnet build...'
dotnet build
Write-Host '[v0.5] dotnet test...'
dotnet test
Write-Host '[v0.5] npm install/build frontend...'
Push-Location '.\src\SchachTurnierManager.WebApp'
npm install
npm run build
Pop-Location
Write-Host '[v0.5] Nachkontrolle abgeschlossen. Danach git status prüfen und committen.'
