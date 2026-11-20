@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo    MOCHILALISTA - COMPILADOR OFICIAL DE RELEASE COMERCIAL (1-CLIC)
echo =====================================================================
echo.

cd /d "%~dp0..\app_movil"
if not exist "pubspec.yaml" (
    echo [ERROR] No se encontro la carpeta app_movil.
    pause
    exit /b 1
)

echo [1/4] Ejecutando analisis estatico de codigo (flutter analyze)...
call flutter analyze --no-pub lib test
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] El analisis estatico detecto advertencias o errores.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Analisis de codigo completado con 0 errores.
echo.

if not exist "build\app_symbols" (
    mkdir "build\app_symbols"
)

echo [2/4] Compilando APK Release con ofuscacion de codigo y simbolos protegidos...
echo Comando: flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
call flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] La compilacion de Flutter fallo.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Compilacion Release exitosa.
echo.

set "APK_PATH=%~dp0..\app_movil\build\app\outputs\flutter-apk\app-release.apk"
if not exist "%APK_PATH%" (
    echo [ERROR] No se encontro el archivo APK en: %APK_PATH%
    pause
    exit /b 1
)

echo [3/4] Calculando huella criptografica SHA-256 y tamano...
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "(Get-FileHash -Path '%APK_PATH%' -Algorithm SHA256).Hash.ToLower()"`) do (
    set "APK_SHA256=%%A"
)

for /f "usebackq tokens=*" %%B in (`powershell -NoProfile -Command "[math]::Round((Get-Item '%APK_PATH%').Length / 1MB, 2)"`) do (
    set "APK_SIZE_MB=%%B"
)

echo.
echo =====================================================================
echo                    RESUMEN DE COMPILACION COMERCIAL
echo =====================================================================
echo Ubicacion del APK : %APK_PATH%
echo Tamano del APK    : %APK_SIZE_MB% MB
echo SHA-256 Oficial   : %APK_SHA256%
echo Simbolos Debug    : %~dp0..\app_movil\build\app_symbols\
echo =====================================================================
echo.
echo [4/4] Sincronizacion con Plataforma Admin:
echo En http://localhost:8080 - Pestana 'Release Manager', presiona:
echo   [Autodetectar APK Local Compilado]
echo para rellenar automaticamente el SHA-256 y registrar la nueva version.
echo.
pause
