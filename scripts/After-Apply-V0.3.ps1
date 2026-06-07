$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

Write-Host '[v0.3] Clean generated files...'
& pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File '.\scripts\Clean-Generated.ps1'

Write-Host '[v0.3] Restore/build/test backend...'
dotnet restore
dotnet build
dotnet test

Write-Host '[v0.3] Install/build frontend...'
Set-Location '.\src\SchachTurnierManager.WebApp'
npm install
npm run build

Set-Location '..\..\..'
Write-Host '[v0.3] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.'
