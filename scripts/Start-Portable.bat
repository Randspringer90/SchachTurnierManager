@echo off
setlocal
set "ROOT=%~dp0"
set "APP_DIR=%ROOT%app"
set "DATA_DIR=%ROOT%data"
set "EXE=%APP_DIR%\SchachTurnierManager.WebApi.exe"
set "DLL=%APP_DIR%\SchachTurnierManager.WebApi.dll"
set "START_CMD="
set "START_ARG="

if exist "%EXE%" (
  set "START_CMD=%EXE%"
) else if exist "%DLL%" (
  set "START_CMD=dotnet"
  set "START_ARG=%DLL%"
) else (
  echo SchachTurnierManager.WebApi.exe/.dll wurde nicht gefunden:
  echo %EXE%
  echo %DLL%
  echo.
  echo Bitte das portable Paket neu erstellen oder vollstaendig entpacken.
  exit /b 1
)

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"
set "ASPNETCORE_URLS=http://127.0.0.1:5088"
set "SchachTurnierManager__DataDirectory=%DATA_DIR%"

if defined START_ARG (
  start "SchachTurnierManager Backend" /D "%APP_DIR%" "%START_CMD%" "%START_ARG%"
) else (
  start "SchachTurnierManager Backend" /D "%APP_DIR%" "%START_CMD%"
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$u='http://127.0.0.1:5088/api/health'; $deadline=(Get-Date).AddSeconds(60); while((Get-Date) -lt $deadline){ try { $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){ exit 0 } } catch { Start-Sleep -Seconds 1 } }; exit 1"
if errorlevel 1 (
  echo Backend war nach 60 Sekunden noch nicht erreichbar.
  echo Pruefe das Backend-Fenster.
  exit /b 1
)

start "" "http://127.0.0.1:5088/"
endlocal
