$ErrorActionPreference = "Stop"
Set-Location (Resolve-Path "$PSScriptRoot\..")
dotnet restore
dotnet build --no-restore
dotnet test --no-build
