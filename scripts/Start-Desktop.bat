@echo off
setlocal
rem Desktop-Variante: Daten liegen unter %LocalAppData%\SchachTurnierManager (Backend-Default).
set "ROOT=%~dp0"
set "APP_DIR=%ROOT%app"
set "EXE=%APP_DIR%\SchachTurnierManager.WebApi.exe"

if not exist "%EXE%" (
  echo SchachTurnierManager.WebApi.exe wurde nicht gefunden:
  echo %EXE%
  echo.
  echo Bitte die Anwendung neu installieren oder vollstaendig entpacken.
  pause
  exit /b 1
)

set "ASPNETCORE_URLS=http://127.0.0.1:5088"

start "SchachTurnierManager" /min "%EXE%"

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$u='http://127.0.0.1:5088/api/health'; for($i=0; $i -lt 45; $i++){ try { $r=Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 2; if($r.StatusCode -eq 200){ exit 0 } } catch { Start-Sleep -Seconds 1 } }; exit 1"
if errorlevel 1 (
  echo Die Anwendung war nach 45 Sekunden noch nicht erreichbar.
  echo Pruefe das minimierte Backend-Fenster "SchachTurnierManager".
  pause
  exit /b 1
)

start "" "http://127.0.0.1:5088/"
endlocal
