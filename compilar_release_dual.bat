@echo off
setlocal
chcp 65001 >nul

set "SCRIPT_PS1=%~dp0scripts\compilar_release_dual.ps1"
if not exist "%SCRIPT_PS1%" (
    echo [ERROR] No se encontro scripts\compilar_release_dual.ps1 en "%~dp0scripts\".
    echo Verifique que el repositorio este completo y vuelva a intentarlo.
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" %*
set "EXIT_CODE=%ERRORLEVEL%"
exit /b %EXIT_CODE%
