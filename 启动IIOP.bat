@echo off
chcp 65001 >nul
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dev\start-iiop-all.ps1"
set "IIOP_EXIT=%ERRORLEVEL%"

echo.
if "%IIOP_EXIT%"=="0" (
    echo IIOP READY
) else (
    echo IIOP START FAILED
)
echo.
pause
exit /b %IIOP_EXIT%
