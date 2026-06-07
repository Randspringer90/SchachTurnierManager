$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$backend = Join-Path $root "src\SchachTurnierManager.WebApi"
$frontend = Join-Path $root "src\SchachTurnierManager.WebApp"
Start-Process pwsh -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Set-Location '$backend'; dotnet run")
Start-Process pwsh -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Set-Location '$frontend'; if (-not (Test-Path node_modules)) { npm install }; npm run dev")
Start-Process "http://localhost:5173"
