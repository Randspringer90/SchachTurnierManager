$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$backend = Join-Path $root "src\SchachTurnierManager.WebApi"
$frontend = Join-Path $root "src\SchachTurnierManager.WebApp"

function Wait-HttpOk {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                return $true
            }
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    return $false
}

Write-Host "[Start-Dev] Starte Backend-Fenster..."
Start-Process pwsh -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Set-Location '$backend'; dotnet run")

Write-Host "[Start-Dev] Warte auf Backend http://localhost:5088/api/health ..."
if (-not (Wait-HttpOk -Url "http://localhost:5088/api/health" -TimeoutSeconds 45)) {
    Write-Warning "Backend war nach 45 Sekunden noch nicht erreichbar. Prüfe das Backend-Terminalfenster. Das Frontend wird trotzdem gestartet."
}

Write-Host "[Start-Dev] Starte Frontend-Fenster..."
Start-Process pwsh -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "Set-Location '$frontend'; if (-not (Test-Path node_modules)) { npm install }; npm run dev")

Write-Host "[Start-Dev] Warte auf Frontend http://localhost:5173 ..."
if (-not (Wait-HttpOk -Url "http://localhost:5173" -TimeoutSeconds 30)) {
    Write-Warning "Frontend war nach 30 Sekunden noch nicht erreichbar. Prüfe das Frontend-Terminalfenster."
}

Start-Process "http://localhost:5173"
Write-Host "[Start-Dev] Browser geöffnet. Backend: http://localhost:5088/api/health · Frontend: http://localhost:5173"
