@echo off
chcp 65001 >nul
title MochilaLista Admin - Lanzador Oficial

echo ================================================================
echo       MOCHILALISTA ADMIN — LANZADOR OFICIAL DE ESCRITORIO
echo ================================================================
echo.

:: 1. Posicionarse en la carpeta mochilalista_admin usando ruta absoluta relativa al script
cd /d "%~dp0mochilalista_admin"
if errorlevel 1 (
    echo [ERROR] No se pudo acceder al directorio "%~dp0mochilalista_admin".
    echo Asegúrese de ejecutar este archivo desde la raíz de MochilaLista.
    echo.
    pause
    exit /b 1
)

:: 2. Validar que Dart SDK exista en el PATH
where dart >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se encontró el comando 'dart' en el PATH del sistema.
    echo Por favor instale Flutter/Dart SDK o agréguelo a las Variables de Entorno de Windows.
    echo.
    pause
    exit /b 1
)

:: 3. Verificar con precisión si el servidor ya está escuchando en el puerto 8080
netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul
if errorlevel 1 (
    echo [*] Iniciando servidor MochilaLista Admin en http://localhost:8080 ...
    start "MochilaLista Admin Server" /min cmd /k "dart run server.dart"
    timeout /t 2 /nobreak >nul
) else (
    echo [*] El servidor MochilaLista Admin ya está escuchando en el puerto 8080.
)

:: 5. Abrir automáticamente el navegador predeterminado
echo [*] Abriendo panel administrativo en http://localhost:8080 ...
start "" http://localhost:8080

echo.
echo ================================================================
echo Servidor en ejecución.
echo Para detenerlo, cierre la ventana 'MochilaLista Admin Server'
echo o presione Ctrl+C en su consola dedicada.
echo ================================================================
echo.
timeout /t 3 >nul
