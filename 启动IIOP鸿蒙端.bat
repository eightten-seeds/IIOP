@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\harmony\start-iiop-harmony.ps1"
if errorlevel 1 (
  echo.
  echo 启动未完成，请根据上方提示处理后重试。
  pause
  exit /b 1
)
pause
