@echo off
setlocal
cd /d "%~dp0backend"
start "SchachTurnierManager Backend" SchachTurnierManager.WebApi.exe
start http://localhost:5088/api/health
endlocal
