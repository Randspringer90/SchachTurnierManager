$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
Set-Location $root
dotnet restore
dotnet build --no-restore
dotnet test --no-build
Set-Location (Join-Path $root "src\SchachTurnierManager.WebApp")
if (-not (Test-Path node_modules)) { npm install }
npm run build
