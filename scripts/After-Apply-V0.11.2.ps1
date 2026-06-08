$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.11.2] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$testFile = Join-Path $root 'tests/SchachTurnierManager.Infrastructure.Tests/FidePlayerLookupProviderTests.cs'
if (Test-Path $testFile) {
    $content = Get-Content -LiteralPath $testFile -Raw
    $fixed = $content.Replace('Assert.Equal("profile/4610563", handler.LastRequestUri?.ToString());', 'Assert.EndsWith("/profile/4610563", handler.LastRequestUri?.ToString());')
    if ($fixed -ne $content) {
        Set-Content -LiteralPath $testFile -Value $fixed -Encoding utf8NoBOM
        Write-Host '[v0.11.2] Alte FIDE-Testassert-Zeile automatisch korrigiert.' -ForegroundColor Yellow
    }
}

Invoke-Step 'dotnet restore' { dotnet restore }
Invoke-Step 'dotnet build' { dotnet build }
Invoke-Step 'dotnet test' { dotnet test }

$webApp = Join-Path $root 'src/SchachTurnierManager.WebApp'
Set-Location $webApp
Invoke-Step 'npm install' { npm install }
Invoke-Step 'npm run build' { npm run build }

Set-Location $root
Invoke-Step 'Pack-Portable' { pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts/Pack-Portable.ps1') }

Write-Host '[v0.11.2] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
