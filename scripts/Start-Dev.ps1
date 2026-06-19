$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$backend = Join-Path $root "src\SchachTurnierManager.WebApi"
$frontend = Join-Path $root "src\SchachTurnierManager.WebApp"
$backendUrl = "http://localhost:5088"
$frontendUrl = "http://127.0.0.1:5173"
$frontendOpenUrl = "http://localhost:5173"

# Kindfenster bevorzugt mit PowerShell 7 (pwsh) starten, sonst Windows PowerShell.
$childShell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
Write-Host "[Start-Dev] Verwende Shell fuer Teilfenster: $childShell"

function Test-PortInUse {
    param([Parameter(Mandatory = $true)][int]$Port)
    try {
        $connections = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop
        return ($null -ne $connections)
    }
    catch {
        # Get-NetTCPConnection liefert einen Fehler, wenn nichts lauscht -> Port frei.
        return $false
    }
}

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
    Start-Process $childShell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $windowCommand)
}

# --- Backend ---
if (Test-PortInUse -Port 5088) {
    Write-Host "[Start-Dev] Port 5088 ist bereits belegt - Backend wird als laufend angenommen, kein Neustart."
}
else {
    Write-Host "[Start-Dev] Starte Backend-Fenster..."
    Start-DevWindow -Title "STM Backend :5088" -WorkingDirectory $backend -Command "dotnet run"
}

Write-Host "[Start-Dev] Warte auf Backend $backendUrl/api/health ..."
if (-not (Wait-HttpOk -Url "$backendUrl/api/health" -TimeoutSeconds 60 -Label "Backend")) {
    Write-Warning "Backend war nach 60 Sekunden noch nicht erreichbar. Pruefe das Backend-Terminalfenster. Das Frontend wird trotzdem gestartet."
}

# --- Frontend ---
if (Test-PortInUse -Port 5173) {
    Write-Host "[Start-Dev] Port 5173 ist bereits belegt - Frontend wird als laufend angenommen, kein Neustart."
}
else {
    Write-Host "[Start-Dev] Starte Frontend-Fenster..."
    Start-DevWindow -Title "STM Frontend :5173" -WorkingDirectory $frontend -Command "if (-not (Test-Path node_modules)) { npm install }; npm run dev"
}

Write-Host "[Start-Dev] Warte auf Frontend $frontendUrl ..."
if (-not (Wait-HttpOk -Url $frontendUrl -TimeoutSeconds 60 -Label "Frontend")) {
    Write-Warning "Frontend war nach 60 Sekunden noch nicht erreichbar. Pruefe das Frontend-Terminalfenster. Browser wird trotzdem geoeffnet."
}

Start-Process $frontendOpenUrl
Write-Host ""
Write-Host "[Start-Dev] Browser geoeffnet."
Write-Host "  Backend:  $backendUrl"
Write-Host "  Frontend: $frontendOpenUrl"
Write-Host "  Health:   $backendUrl/api/health"
