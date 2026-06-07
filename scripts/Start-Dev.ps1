$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$backend = Join-Path $root "src\SchachTurnierManager.WebApi"
$frontend = Join-Path $root "src\SchachTurnierManager.WebApp"
$backendUrl = "http://localhost:5088"
$frontendUrl = "http://127.0.0.1:5173"

function Wait-HttpOk {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSeconds = 45,
        [string]$Label = $Url
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null
    do {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                Write-Host "[Start-Dev] Erreichbar: $Label ($($response.StatusCode))"
                return $true
            }
        }
        catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    if ($lastError) {
        Write-Warning "Nicht erreichbar: $Label. Letzter Fehler: $lastError"
    }
    return $false
}

function Start-DevWindow {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Command
    )

    $escapedTitle = $Title.Replace('"', '\"')
    $escapedDir = $WorkingDirectory.Replace("'", "''")
    $escapedCommand = $Command.Replace("'", "''")
    $windowCommand = "`$Host.UI.RawUI.WindowTitle = '$escapedTitle'; Set-Location '$escapedDir'; $escapedCommand"
    Start-Process pwsh -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $windowCommand)
}

Write-Host "[Start-Dev] Starte Backend-Fenster..."
Start-DevWindow -Title "STM Backend :5088" -WorkingDirectory $backend -Command "dotnet run"

Write-Host "[Start-Dev] Warte auf Backend $backendUrl/api/health ..."
if (-not (Wait-HttpOk -Url "$backendUrl/api/health" -TimeoutSeconds 60 -Label "Backend")) {
    Write-Warning "Backend war nach 60 Sekunden noch nicht erreichbar. Prüfe das Backend-Terminalfenster. Das Frontend wird trotzdem gestartet."
}

Write-Host "[Start-Dev] Starte Frontend-Fenster..."
Start-DevWindow -Title "STM Frontend :5173" -WorkingDirectory $frontend -Command "if (-not (Test-Path node_modules)) { npm install }; npm run dev"

Write-Host "[Start-Dev] Warte auf Frontend $frontendUrl ..."
if (-not (Wait-HttpOk -Url $frontendUrl -TimeoutSeconds 60 -Label "Frontend")) {
    Write-Warning "Frontend war nach 60 Sekunden noch nicht erreichbar. Prüfe das Frontend-Terminalfenster. Browser wird trotzdem geöffnet."
}

Start-Process $frontendUrl
Write-Host "[Start-Dev] Browser geöffnet. Backend: $backendUrl/api/health · Frontend: $frontendUrl"
