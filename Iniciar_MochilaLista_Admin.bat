@echo off
title MochilaLista Admin - Lanzador Oficial

echo ================================================================
echo       MOCHILALISTA ADMIN - EXPERIENCIA NATIVA DE ESCRITORIO
echo ================================================================
echo.

set "ADMIN_DIR=%~dp0mochilalista_admin"
cd /d "%ADMIN_DIR%"
if errorlevel 1 goto ERR_NO_ADMIN_DIR

where dart >nul 2>&1
if errorlevel 1 goto ERR_NO_DART

set "BROWSER_MODE=0"
if /i "%~1"=="--browser" set "BROWSER_MODE=1"
if /i "%~1"=="-b" set "BROWSER_MODE=1"

:: Verificacion rapida de socket en puerto 8080
netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul 2>&1

set "SERVER_HEALTHY=0"
for /f "tokens=*" %%H in ('curl.exe -s -o nul -w "%%{http_code}" http://localhost:8080/api/vault/health 2^>nul') do if "%%H"=="200" set "SERVER_HEALTHY=1"
if not "%SERVER_HEALTHY%"=="1" for /f "usebackq tokens=*" %%H in (`powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://127.0.0.1:8080/api/vault/health' -UseBasicParsing -TimeoutSec 2).StatusCode } catch { 0 }" 2^>nul`) do if "%%H"=="200" set "SERVER_HEALTHY=1"

if "%SERVER_HEALTHY%"=="1" goto SERVER_ALREADY_ACTIVE

echo [*] Iniciando servidor MochilaLista Admin en segundo plano...
start "MochilaLista Admin Server" /min /D "%ADMIN_DIR%" cmd /c "dart run server.dart || pause"

set /a TRIES=0
:HEALTH_LOOP
timeout /t 1 /nobreak >nul 2>&1 || ping 127.0.0.1 -n 2 >nul 2>&1
set /a TRIES+=1
set "CHECK_CODE=0"
for /f "tokens=*" %%H in ('curl.exe -s -o nul -w "%%{http_code}" http://localhost:8080/api/vault/health 2^>nul') do set "CHECK_CODE=%%H"
if not "%CHECK_CODE%"=="200" for /f "usebackq tokens=*" %%H in (`powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://127.0.0.1:8080/api/vault/health' -UseBasicParsing -TimeoutSec 2).StatusCode } catch { 0 }" 2^>nul`) do set "CHECK_CODE=%%H"

if "%CHECK_CODE%"=="200" goto SERVER_READY
if %TRIES% geq 20 goto ERR_TIMEOUT
goto HEALTH_LOOP

:SERVER_ALREADY_ACTIVE
echo [*] Servidor MochilaLista Admin ya esta activo y respondiendo [HTTP 200 OK].
goto DETECT_BROWSER

:SERVER_READY
echo [*] Servidor confirmado respondiendo en http://localhost:8080 [HTTP 200 OK tras %TRIES%s].
goto DETECT_BROWSER

:DETECT_BROWSER
set "CHROME_BIN="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME_BIN=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME_BIN if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME_BIN=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME_BIN if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME_BIN=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined CHROME_BIN for /f "tokens=*" %%C in ('where chrome.exe 2^>nul') do if not defined CHROME_BIN set "CHROME_BIN=%%C"

set "EDGE_BIN="
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "EDGE_BIN=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined EDGE_BIN if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "EDGE_BIN=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not defined EDGE_BIN for /f "tokens=*" %%E in ('where msedge.exe 2^>nul') do if not defined EDGE_BIN set "EDGE_BIN=%%E"

if "%BROWSER_MODE%"=="1" goto LAUNCH_TAB_MODE
goto LAUNCH_APP_MODE

:LAUNCH_TAB_MODE
echo [*] Modo Pestana de Navegador solicitado [--browser]...
if defined CHROME_BIN goto OPEN_TAB_CHROME
if defined EDGE_BIN goto OPEN_TAB_EDGE
goto OPEN_TAB_DEFAULT

:OPEN_TAB_CHROME
echo [*] Abriendo en Google Chrome [Pestana]: "%CHROME_BIN%"
start "" "%CHROME_BIN%" "http://localhost:8080"
goto LAUNCH_DONE

:OPEN_TAB_EDGE
echo [*] Abriendo en Microsoft Edge [Pestana]: "%EDGE_BIN%"
start "" "%EDGE_BIN%" "http://localhost:8080"
goto LAUNCH_DONE

:OPEN_TAB_DEFAULT
echo [*] Abriendo en navegador predeterminado...
start "" "http://localhost:8080"
goto LAUNCH_DONE

:LAUNCH_APP_MODE
echo [*] Abriendo en Modo Aplicacion de Escritorio...
if defined CHROME_BIN goto OPEN_APP_CHROME
if defined EDGE_BIN goto OPEN_APP_EDGE
goto OPEN_APP_DEFAULT

:OPEN_APP_CHROME
echo [*] Prioridad 1: Abriendo como App en Google Chrome: "%CHROME_BIN%"
start "" "%CHROME_BIN%" --app=http://localhost:8080/?mode=app
goto LAUNCH_DONE

:OPEN_APP_EDGE
echo [*] Prioridad 2: Abriendo como App en Microsoft Edge: "%EDGE_BIN%"
start "" "%EDGE_BIN%" --app=http://localhost:8080/?mode=app
goto LAUNCH_DONE

:OPEN_APP_DEFAULT
echo [*] Prioridad 3: Abriendo en navegador del sistema...
start "" "http://localhost:8080"
goto LAUNCH_DONE

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
timeout /t 2 /nobreak >nul 2>&1 || ping 127.0.0.1 -n 3 >nul 2>&1
exit /b 0

:ERR_NO_ADMIN_DIR
echo [ERROR] No se pudo acceder a la carpeta mochilalista_admin.
echo Asegurese de ejecutar este archivo desde la raiz de MochilaLista.
echo.
pause
exit /b 1

:ERR_NO_DART
echo [ERROR] No se encontro el comando 'dart' en el PATH del sistema.
echo Por favor instale Flutter o Dart SDK y agreguelo a las Variables de Entorno.
echo.
pause
exit /b 1

:ERR_TIMEOUT
echo [ERROR] Tiempo de espera agotado - 20 segundos.
echo El servidor MochilaLista Admin no respondio en http://localhost:8080/api/vault/health.
echo Revise la ventana minimizada 'MochilaLista Admin Server' para ver el diagnostico.
echo.
pause
exit /b 1
