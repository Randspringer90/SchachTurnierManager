$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path "$PSScriptRoot\..\src\SchachTurnierManager.WebApp")
if (-not (Test-Path node_modules)) { npm install }
npm run dev
