@echo off
setlocal
rem Desktop-Variante: Daten und Logs liegen unter %LocalAppData%\SchachTurnierManager.
set "ROOT=%~dp0"
set "APP_DIR=%ROOT%app"
set "EXE=%APP_DIR%\SchachTurnierManager.WebApi.exe"
set "DATA_DIR=%LOCALAPPDATA%\SchachTurnierManager"
set "LOG_DIR=%DATA_DIR%\logs"

if not exist "%EXE%" (
  echo SchachTurnierManager.WebApi.exe wurde nicht gefunden:
  echo %EXE%
  echo.
  echo Bitte die Anwendung neu installieren oder vollstaendig entpacken.
  pause
  exit /b 1
)

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "ASPNETCORE_URLS=http://127.0.0.1:5088"
set "SchachTurnierManager__DataDirectory=%DATA_DIR%"
set "SchachTurnierManager__LogDirectory=%LOG_DIR%"

start "SchachTurnierManager" /min "%EXE%"

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$u='http://127.0.0.1:5088/api/health'; for($i=0; $i -lt 45; $i++){ try { $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){ exit 0 } } catch { Start-Sleep -Seconds 1 } }; exit 1"
if errorlevel 1 (
  echo Die Anwendung war nach 45 Sekunden noch nicht erreichbar.
  echo Pruefe das minimierte Backend-Fenster "SchachTurnierManager".
  echo Logs: %LOG_DIR%
  pause
  exit /b 1
)

echo Logs: %LOG_DIR%
start "" "http://127.0.0.1:5088/"
endlocal
