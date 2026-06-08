@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Cleanup-WeeklyDuplicates.ps1"
echo.
echo === Script finished. Press any key to close this window. ===
pause >nul
