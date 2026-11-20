@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo    MOCHILALISTA - COMPILADOR OFICIAL APK ARM64 LIGERO (1-CLIC)
echo    Optimizada para 99%% de celulares Android modernos (64 bits)
echo    Tamano ultraligero (~25-35 MB) ideal para envio directo por WhatsApp
echo =====================================================================
echo.

:: 1. Posicionarse en la carpeta app_movil
cd /d "%~dp0app_movil"
if not exist "pubspec.yaml" (
    echo [ERROR] No se encontro la carpeta app_movil.
    pause
    exit /b 1
)

echo [1/4] Ejecutando analisis estatico de codigo (flutter analyze)...
call flutter analyze --no-pub lib test
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] El analisis estatico detecto advertencias o errores. Corrijalos antes de compilar.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Analisis de codigo completado con 0 errores.
echo.

:: 2. Crear carpeta para guardar mapas de simbolos de ofuscacion
if not exist "build\app_symbols" (
    mkdir "build\app_symbols"
)

echo [2/4] Compilando APK ARM64 con ofuscacion de codigo y division por arquitectura...
echo Comando: flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
call flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] La compilacion de Flutter fallo.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] Compilacion Release exitosa.
echo.

:: 3. Localizar el APK ARM64 generado
set "APK_ARM64=%~dp0app_movil\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if not exist "%APK_ARM64%" (
    echo [ERROR] No se encontro el archivo APK ARM64 en: %APK_ARM64%
    pause
    exit /b 1
)

echo [3/4] Calculando huella criptografica SHA-256 y tamano de APK ligero...
for /f "usebackq tokens=*" %%A in (`powershell -NoProfile -Command "(Get-FileHash -Path '%APK_ARM64%' -Algorithm SHA256).Hash.ToLower()"`) do (
    set "APK_SHA256=%%A"
)

for /f "usebackq tokens=*" %%B in (`powershell -NoProfile -Command "[math]::Round((Get-Item '%APK_ARM64%').Length / 1MB, 2)"`) do (
    set "APK_SIZE_MB=%%B"
)

echo.
echo =====================================================================
echo              RESUMEN DE COMPILACION ARM64 (LIGERO WHATSAPP)
echo =====================================================================
echo Ubicacion del APK : %APK_ARM64%
echo Tamano Ultraligero: %APK_SIZE_MB% MB (vs. 114 MB universal)
echo SHA-256 Oficial   : %APK_SHA256%
echo Arquitectura      : arm64-v8a
echo Simbolos Debug    : %~dp0app_movil\build\app_symbols\
echo =====================================================================
echo.
echo [4/4] Sincronizacion con Plataforma Admin MochilaLista:
echo Puedes abrir la Plataforma Admin (http://localhost:8080), ir a la
echo pestana 'Gestor de Versiones' y presionar el boton:
echo   [Autodetectar APK de app_movil]
echo El sistema detectara de inmediato el APK arm64-v8a (%APK_SIZE_MB% MB)
echo y su SHA-256 oficial para importarlo en 1 solo clic.
echo.
echo =====================================================================
echo Compilacion finalizada exitosamente para distribucion comercial rapida.
echo =====================================================================
pause
