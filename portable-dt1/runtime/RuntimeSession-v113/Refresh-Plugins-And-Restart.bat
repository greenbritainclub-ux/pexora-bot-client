@echo off
setlocal
cd /d C:\PreparedRuntime
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\PreparedRuntime\SwapProbeAndRefreshV3.ps1"
set "exitCode=%ERRORLEVEL%"
echo.
if not "%exitCode%"=="0" echo Refresh failed with exit code %exitCode%.
if not "%exitCode%"=="0" pause
exit /b %exitCode%
