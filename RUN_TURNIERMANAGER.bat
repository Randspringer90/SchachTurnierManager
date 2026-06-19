@echo off
setlocal

rem ============================================================
rem  SchachTurnierManager - Ein-Klick-Start fuer den Turniertag
rem  Doppelklick startet Backend, Frontend und Browser.
rem  Aendert NICHT die globale PowerShell-ExecutionPolicy.
rem  Benoetigt KEINE Adminrechte.
rem ============================================================

rem In das Repo-Verzeichnis wechseln (Ordner dieser BAT-Datei).
cd /d "%~dp0"

echo(
echo ============================================================
echo   SchachTurnierManager wird gestartet ...
echo ------------------------------------------------------------
echo   Backend:  http://localhost:5088
echo   Frontend: http://localhost:5173
echo   Health:   http://localhost:5088/api/health
echo ============================================================
echo(

set "STARTSCRIPT=%~dp0scripts\Start-Dev.ps1"

if not exist "%STARTSCRIPT%" (
    echo [FEHLER] Startskript nicht gefunden:
    echo          "%STARTSCRIPT%"
    echo          Bitte sicherstellen, dass die BAT im Repo-Root liegt.
    echo(
    pause
    exit /b 1
)

rem PowerShell 7 (pwsh) bevorzugen, sonst Windows PowerShell (powershell).
rem -ExecutionPolicy Bypass gilt nur fuer diesen Prozess, nicht systemweit.
where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
    echo [INFO] Verwende PowerShell 7 ^(pwsh^).
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%STARTSCRIPT%"
) else (
    echo [INFO] pwsh nicht gefunden - verwende Windows PowerShell.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%STARTSCRIPT%"
)

if %ERRORLEVEL% NEQ 0 (
    echo(
    echo [HINWEIS] Der Start ist mit einem Fehler beendet worden.
    echo           Bitte die Meldungen oben pruefen.
)

echo(
echo Dieses Fenster kann geschlossen werden. Backend- und Frontend-Fenster
echo laufen separat weiter. Browser: http://localhost:5173
echo(
pause
endlocal
