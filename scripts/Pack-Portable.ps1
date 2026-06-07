$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$output = Join-Path $root "output\portable"
Remove-Item -Recurse -Force $output -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $output | Out-Null
Set-Location $root
dotnet publish .\src\SchachTurnierManager.WebApi\SchachTurnierManager.WebApi.csproj -c Release -o (Join-Path $output "backend")
Copy-Item .\scripts\Start-Portable.bat (Join-Path $output "Start-SchachTurnierManager.bat") -Force
Write-Host "Portable Backend erstellt: $output"
