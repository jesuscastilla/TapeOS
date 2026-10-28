@echo off
setlocal
cd /d "%~dp0"
echo ========================================================
echo Iniciando TapeOS Installer con privilegios elevados...
echo ========================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0TapeOS-Installer.ps1\"' -Verb RunAs"
exit /b
