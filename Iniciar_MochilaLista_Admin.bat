@echo off
title MochilaLista Admin - Lanzador Oficial

echo ================================================================
echo       MOCHILALISTA ADMIN - EXPERIENCIA NATIVA DE ESCRITORIO
echo ================================================================
echo.

set "ADMIN_DIR=%~dp0mochilalista_admin"
cd /d "%ADMIN_DIR%"
if errorlevel 1 (
    echo [ERROR] No se pudo acceder a la carpeta mochilalista_admin.
    echo Asegurese de ejecutar este archivo desde la raiz de MochilaLista.
    echo.
    pause
    exit /b 1
)

where dart >nul 2>&1
if errorlevel 1 (
    echo [ERROR] No se encontro el comando 'dart' en el PATH del sistema.
    echo Por favor instale Flutter o Dart SDK y agreguelo a las Variables de Entorno.
    echo.
    pause
    exit /b 1
)

set "BROWSER_MODE=0"
if /i "%~1"=="--browser" set "BROWSER_MODE=1"
if /i "%~1"=="-b" set "BROWSER_MODE=1"

:: Verificacion rapida de socket en puerto 8080
netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul 2>&1

set "SERVER_HEALTHY=0"
for /f "usebackq tokens=*" %%H in (`powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://localhost:8080/api/vault/health' -UseBasicParsing -TimeoutSec 1).StatusCode } catch { 0 }" 2^>nul`) do (
    if "%%H"=="200" set "SERVER_HEALTHY=1"
)

if "%SERVER_HEALTHY%"=="1" (
    echo [*] Servidor MochilaLista Admin ya esta activo y respondiendo (HTTP 200 OK).
    goto LAUNCH_BROWSER
)

echo [*] Iniciando servidor MochilaLista Admin en segundo plano...
start "MochilaLista Admin Server" /min cmd /c "cd /d "%ADMIN_DIR%" && dart run server.dart || pause"

set /a TRIES=0
:HEALTH_LOOP
timeout /t 1 /nobreak >nul
set /a TRIES+=1
set "CHECK_CODE=0"
for /f "usebackq tokens=*" %%H in (`powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://localhost:8080/api/vault/health' -UseBasicParsing -TimeoutSec 1).StatusCode } catch { 0 }" 2^>nul`) do (
    set "CHECK_CODE=%%H"
)
if "%CHECK_CODE%"=="200" (
    echo [*] Servidor confirmado respondiendo en http://localhost:8080 (HTTP 200 OK tras %TRIES%s).
    goto LAUNCH_BROWSER
)
if %TRIES% geq 20 (
    echo [ERROR] Tiempo de espera agotado (20 segundos).
    echo El servidor MochilaLista Admin no respondio en http://localhost:8080/api/vault/health.
    echo Revise la ventana minimizada 'MochilaLista Admin Server' para ver el diagnostico.
    echo.
    pause
    exit /b 1
)
goto HEALTH_LOOP

:LAUNCH_BROWSER
set "CHROME_BIN="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
    set "CHROME_BIN=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
)
if not defined CHROME_BIN if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
    set "CHROME_BIN=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
)
if not defined CHROME_BIN if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" (
    set "CHROME_BIN=%LocalAppData%\Google\Chrome\Application\chrome.exe"
)
if not defined CHROME_BIN (
    for /f "tokens=*" %%C in ('where chrome.exe 2^>nul') do (
        if not defined CHROME_BIN set "CHROME_BIN=%%C"
    )
)

set "EDGE_BIN="
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    set "EDGE_BIN=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
)
if not defined EDGE_BIN if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
    set "EDGE_BIN=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
)
if not defined EDGE_BIN (
    for /f "tokens=*" %%E in ('where msedge.exe 2^>nul') do (
        if not defined EDGE_BIN set "EDGE_BIN=%%E"
    )
)

if "%BROWSER_MODE%"=="1" (
    echo [*] Modo Pestana de Navegador solicitado (--browser)...
    if defined CHROME_BIN (
        echo [*] Abriendo en Google Chrome (Pestana): "%CHROME_BIN%"
        start "" "%CHROME_BIN%" "http://localhost:8080"
        goto LAUNCH_DONE
    )
    if defined EDGE_BIN (
        echo [*] Abriendo en Microsoft Edge (Pestana): "%EDGE_BIN%"
        start "" "%EDGE_BIN%" "http://localhost:8080"
        goto LAUNCH_DONE
    )
    echo [*] Abriendo en navegador predeterminado...
    start "" "http://localhost:8080"
    goto LAUNCH_DONE
)

echo [*] Abriendo en Modo Aplicacion de Escritorio...
if defined CHROME_BIN (
    echo [*] Prioridad 1: Abriendo como App en Google Chrome: "%CHROME_BIN%"
    start "" "%CHROME_BIN%" --app=http://localhost:8080
    goto LAUNCH_DONE
)
if defined EDGE_BIN (
    echo [*] Prioridad 2: Abriendo como App en Microsoft Edge: "%EDGE_BIN%"
    start "" "%EDGE_BIN%" --app=http://localhost:8080
    goto LAUNCH_DONE
)
echo [*] Prioridad 3: Abriendo en navegador del sistema...
start "" "http://localhost:8080"

:LAUNCH_DONE
echo.
echo ================================================================
echo MochilaLista Admin iniciado exitosamente.
echo URL de acceso local: http://localhost:8080
echo.
echo Para apagar el servidor:
echo   - Use el boton 'Apagar Servidor' en la barra lateral web, o
echo   - Cierre la ventana minimizada 'MochilaLista Admin Server'
echo ================================================================
echo.
timeout /t 2 /nobreak >nul
exit /b 0
