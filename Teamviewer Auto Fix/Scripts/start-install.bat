@echo off
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

powershell.exe -ExecutionPolicy Bypass -File "%~dp0install-teamviewer.ps1"
pause