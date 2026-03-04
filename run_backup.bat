@echo off
cd /d "%~dp0"

REM Try PowerShell 7 first
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -ExecutionPolicy Bypass -File "scripts\run_menu.ps1"
) else (
    powershell.exe -ExecutionPolicy Bypass -File "scripts\run_menu.ps1"
)

pause