@echo off
title MochilaLista Admin Platform - Julio Angello Vasquez Navarro
color 0B
echo ================================================================
echo   MOCHILALISTA ADMIN - SERVIDOR LOCAL Y GESTOR DE LICENCIAS
echo   Autor: Julio Angello Vasquez Navarro
echo ================================================================
echo.

cd /d "%~dp0"

echo [1/3] Verificando entorno Dart...
where dart >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo [ERROR] No se encontro 'dart' en el PATH del sistema.
  echo Asegurate de tener Flutter o Dart instalado.
  pause
  exit /b 1
)

echo [2/3] Verificando dependencias...
if not exist .dart_tool (
  echo Descargando paquetes necesarios...
  call dart pub get
)

echo [3/3] Iniciando servidor y abriendo navegador en http://localhost:8080 ...
start "" http://localhost:8080

dart run server.dart

pause
