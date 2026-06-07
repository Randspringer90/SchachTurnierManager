$ErrorActionPreference = 'Stop'

Write-Host '[v0.4] Clean generated files...'
& "$PSScriptRoot\Clean-Generated.ps1"

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $root

Write-Host '[v0.4] dotnet restore...'
dotnet restore

Write-Host '[v0.4] dotnet build...'
dotnet build

Write-Host '[v0.4] dotnet test...'
dotnet test

Write-Host '[v0.4] npm install/build frontend...'
Set-Location (Join-Path $root 'src\SchachTurnierManager.WebApp')
npm install
npm run build

Set-Location $root
Write-Host '[v0.4] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
