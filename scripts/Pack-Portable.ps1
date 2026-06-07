$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$output = Join-Path $root "output\portable"
Remove-Item -Recurse -Force $output -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $output | Out-Null
Set-Location (Join-Path $root "src\SchachTurnierManager.WebApp")
if (-not (Test-Path node_modules)) { npm install }
npm run build
Set-Location $root
dotnet publish .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj -c Release -o (Join-Path $output "backend")
Copy-Item .\scripts\Start-Portable.bat (Join-Path $output "Start-SchachTurnierManager.bat") -Force
Write-Host "Portable Backend erstellt: $output"
Write-Host "Hinweis: Frontend-Hosting im Backend folgt in einer späteren Version; aktuell Dashboard per npm run dev starten."
