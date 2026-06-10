$ErrorActionPreference = 'Stop'

function Invoke-Step {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Command
    )

    Write-Host "[v0.13.0] $Name..." -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Schritt fehlgeschlagen: $Name (ExitCode=$LASTEXITCODE)"
    }
}

function Update-TextFile {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][scriptblock]$Transform
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $content = Get-Content -LiteralPath $Path -Raw
    $updated = & $Transform $content
    if ($updated -ne $content) {
        Set-Content -LiteralPath $Path -Value $updated -Encoding utf8NoBOM
    }
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Update-TextFile -Path (Join-Path $root 'src/SchachTurnierManager.WebApi/Program.cs') -Transform {
    param($content)
    $content -replace 'version = "0\.\d+\.\d+"', 'version = "0.13.0"'
}

Update-TextFile -Path (Join-Path $root 'src/SchachTurnierManager.WebApp/src/main.tsx') -Transform {
    param($content)
    $content -replace 'Lokaler Turnierleiter · v0\.\d+\.\d+', 'Lokaler Turnierleiter · v0.13.0'
}

Update-TextFile -Path (Join-Path $root 'src/SchachTurnierManager.WebApp/package-lock.json') -Transform {
    param($content)
    $content -replace '"version": "0\.\d+\.\d+"', '"version": "0.13.0"'
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

Write-Host '[v0.13.0] Nachkontrolle abgeschlossen. Bitte danach git status prüfen und committen.' -ForegroundColor Green
git status --short
