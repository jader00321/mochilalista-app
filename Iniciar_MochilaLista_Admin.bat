@echo off
chcp 65001 >nul
title MochilaLista Admin - Lanzador Oficial

echo ================================================================
echo       MOCHILALISTA ADMIN — EXPERIENCIA NATIVA DE ESCRITORIO
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

:: 3. Verificar si el servidor ya está escuchando en el puerto 8080
netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul
if errorlevel 1 (
    echo [*] Iniciando servidor MochilaLista Admin en segundo plano...
    start "MochilaLista Admin Server" /min cmd /k "dart run server.dart"

    :: Bucle inteligente de espera hasta que el puerto 8080 esté escuchando (máximo ~10 segundos)
    set /a TRIES=0
    :WAIT_LOOP
    timeout /t 1 /nobreak >nul
    set /a TRIES+=1
    netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul
    if not errorlevel 1 (
        echo [*] Servidor activo y respondiendo en el puerto 8080.
        goto SERVER_READY
    )
    if %TRIES% geq 10 (
        echo [!] Tiempo de espera agotado, procediendo a abrir la interfaz...
        goto SERVER_READY
    )
    goto WAIT_LOOP
) else (
    echo [*] El servidor MochilaLista Admin ya está escuchando en el puerto 8080.
)

:SERVER_READY
echo [*] Abriendo interfaz en modo aplicación de escritorio (--app=http://localhost:8080)...

:: Prioridad 1: Microsoft Edge
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --app=http://localhost:8080
    goto LAUNCH_DONE
)
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --app=http://localhost:8080
    goto LAUNCH_DONE
)
where msedge >nul 2>&1
if not errorlevel 1 (
    start "" msedge --app=http://localhost:8080
    goto LAUNCH_DONE
)

:: Prioridad 2: Google Chrome
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" --app=http://localhost:8080
    goto LAUNCH_DONE
)
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" --app=http://localhost:8080
    goto LAUNCH_DONE
)
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
    start "" "%LocalAppData%\Google\Chrome\Application\chrome.exe" --app=http://localhost:8080
    goto LAUNCH_DONE
)
where chrome >nul 2>&1
if not errorlevel 1 (
    start "" chrome --app=http://localhost:8080
    goto LAUNCH_DONE
)

:: Prioridad 3: Fallback estándar
start "" "http://localhost:8080"

:LAUNCH_DONE
echo.
echo ================================================================
echo MochilaLista Admin iniciado exitosamente.
echo Para apagar el servidor, cierre la ventana 'MochilaLista Admin Server'
echo o ejecute: Stop-Process -Name dart (en PowerShell)
echo ================================================================
echo.
timeout /t 2 /nobreak >nul
