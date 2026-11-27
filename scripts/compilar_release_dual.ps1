# ==============================================================================
# MochilaLista - Compilador Dual Oficial Único y Guiado (Universal + ARM64)
# Plan Maestro 23.5 - Fase 3
# ==============================================================================

$ErrorActionPreference = 'Stop'

# Salvaguarda 3: UTF-8 limpio en consola de Windows sin exponer secretos
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Detecta si PowerShell 5.1 leyó literales UTF-8 (sin BOM) con codificación ANSI del sistema
$script:NeedsUtf8LiteralFix = ('ó'.Length -ne 1)

function ConvertTo-Utf8DisplayText {
    param([string]$Text)
    if (-not $script:NeedsUtf8LiteralFix -or [string]::IsNullOrEmpty($Text)) {
        return $Text
    }
    try {
        $bytes = [System.Text.Encoding]::Default.GetBytes($Text)
        return [System.Text.Encoding]::UTF8.GetString($bytes)
    } catch {
        return $Text
    }
}

$DefaultOutDir = 'C:\Users\vjuli\Documents\v-app-offline apks'
$ExpectedPackageName = 'com.mochilalista.app'
$DefaultSignerSha256 = '7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$RepoRoot = Split-Path -Parent $ScriptDir

$ShowHelp = $false
$DryRun = $false
$VerifyOnly = $false
$SkipAnalyze = $false
$NoPause = $false
$InitNotes = $false
$OutDir = $DefaultOutDir

function Wait-IfInteractive {
    param([bool]$ForceNoPause)
    if ($ForceNoPause) { return }
    try {
        if (-not [Environment]::UserInteractive) { return }
        if ([Console]::IsInputRedirected) { return }
        Write-Host ""
        Write-Host (ConvertTo-Utf8DisplayText "Presiona ENTER para cerrar esta ventana...") -ForegroundColor DarkGray
        [void][Console]::ReadLine()
    } catch {
        # En consolas no interactivas no bloquear nunca
    }
}

function Stop-WithGuidance {
    param(
        [string]$WhatFailed,
        [string]$HowToFix,
        [int]$ExitCode = 1
    )
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host (ConvertTo-Utf8DisplayText "  ERROR EN COMPILADOR DUAL OFICIAL") -ForegroundColor Red
    Write-Host "========================================================================" -ForegroundColor Red
    Write-Host ((ConvertTo-Utf8DisplayText "QUÉ FALL") + [char]0x00D3 + ": " + $WhatFailed) -ForegroundColor Red
    Write-Host ("C" + [char]0x00D3 + (ConvertTo-Utf8DisplayText "MO SOLUCIONARLO: ") + $HowToFix) -ForegroundColor Yellow
    Write-Host "========================================================================" -ForegroundColor Red
    Wait-IfInteractive -ForceNoPause $NoPause
    exit $ExitCode
}

function Show-UsageHelp {
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host (ConvertTo-Utf8DisplayText "  MOCHILALISTA - COMPILADOR DUAL OFICIAL ÚNICO Y GUIADO") -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "QUÉ GENERA ESTE SCRIPT:") -ForegroundColor White
    Write-Host (ConvertTo-Utf8DisplayText "  1. APK Universal (~71 MB) -> mochilalista_v<tag>_atp.apk") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "     Compatible con teléfonos y tablets Android ARM físicos (arm64-v8a y") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "     armeabi-v7a, sin x86_64). Ideal como respaldo o envío directo (< 100 MB).") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  2. APK ARM64 Ligero (~39 MB) -> mochilalista_v<tag>_arm64_atp.apk") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "     Optimizado para el 99 % de celulares Android modernos (64 bits)") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "     e ideal para enviar directo por WhatsApp Web (< 100 MB).") -ForegroundColor Gray
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "CARPETA OFICIAL DE ENTREGA POR DEFECTO:") -ForegroundColor White
    Write-Host "  $DefaultOutDir" -ForegroundColor Green
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "PARÁMETROS DISPONIBLES:") -ForegroundColor White
    Write-Host (ConvertTo-Utf8DisplayText "  (sin flags)      Ejecuta los 6 pasos: pre-chequeo, análisis,") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "                   compilación Universal + ARM64, certificación y resumen.") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --help, -h, /?   Muestra esta guía rápida y termina sin compilar.") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --dry-run        Valida entorno y muestra comandos/rutas sin compilar.") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --verify-only    Audita con aapt2 + apksigner los APKs ya generados") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "                   de la versión actual sin recompilar Flutter.") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --skip-analyze   Omite el análisis estático (flutter analyze --no-pub).") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --no-pause       Finaliza sin esperar ENTER (ideal para automatización).") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --init-notes     Crea *_atp.txt y *_atp_cambios.txt en UTF-8 sin BOM solo") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "                   si faltan; jamás sobrescribe notas existentes en disco.") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  --out-dir <ruta> Cambia la carpeta destino donde se entregan los APKs.") -ForegroundColor Gray
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "EJEMPLOS LISTOS PARA COPIAR Y PEGAR:") -ForegroundColor White
    Write-Host "  compilar_release_dual.bat" -ForegroundColor Cyan
    Write-Host "  compilar_release_dual.bat --verify-only --no-pause" -ForegroundColor Cyan
    Write-Host "  compilar_release_dual.bat --verify-only --init-notes --no-pause" -ForegroundColor Cyan
    Write-Host "  compilar_release_dual.bat --dry-run --no-pause" -ForegroundColor Cyan
    Write-Host "  compilar_release_dual.bat --skip-analyze --no-pause" -ForegroundColor Cyan
    Write-Host "  compilar_release_dual.bat --out-dir `"D:\Entregas\MochilaLista`"" -ForegroundColor Cyan
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "FLUJO GUIADO DE 6 ETAPAS:") -ForegroundColor White
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 1/6] Pre-chequeos (pubspec.yaml, key.properties + .jks, Flutter y SDK)") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 2/6] Análisis estático (flutter analyze --no-pub)") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 3/6] Compilación Universal ofuscada + símbolos debug") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 4/6] Compilación ARM64 Ligero ofuscada (--split-per-abi)") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 5/6] Certificación forense aapt2 (anti-debug) + apksigner RSA-4096") -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 6/6] Resumen ejecutivo (MB, ahorro %, SHA-256, notas y checklist)") -ForegroundColor Gray
    Write-Host "========================================================================" -ForegroundColor Cyan
}

# ------------------------------------------------------------------------------
# Parseo tolerante de argumentos CLI y PowerShell
# ------------------------------------------------------------------------------
for ($i = 0; $i -lt $args.Count; $i++) {
    $rawArg = [string]$args[$i]
    if ([string]::IsNullOrWhiteSpace($rawArg)) { continue }
    $norm = $rawArg.Trim()

    if ($norm -eq '--help' -or $norm -eq '-h' -or $norm -eq '/?' -or $norm -ieq '-Help') {
        $ShowHelp = $true
        continue
    }
    if ($norm -eq '--dry-run' -or $norm -ieq '-DryRun') {
        $DryRun = $true
        continue
    }
    if ($norm -eq '--verify-only' -or $norm -ieq '-VerifyOnly') {
        $VerifyOnly = $true
        continue
    }
    if ($norm -eq '--skip-analyze' -or $norm -ieq '-SkipAnalyze') {
        $SkipAnalyze = $true
        continue
    }
    if ($norm -eq '--no-pause' -or $norm -ieq '-NoPause') {
        $NoPause = $true
        continue
    }
    if ($norm -eq '--init-notes' -or $norm -ieq '-InitNotes') {
        $InitNotes = $true
        continue
    }
    if ($norm -eq '--out-dir' -or $norm -ieq '-OutDir') {
        if ($i + 1 -ge $args.Count) {
            Stop-WithGuidance `
                -WhatFailed (ConvertTo-Utf8DisplayText "El parámetro '$norm' requiere una ruta de carpeta destino.") `
                -HowToFix (ConvertTo-Utf8DisplayText "Especifica la carpeta entre comillas, por ejemplo: compilar_release_dual.bat --out-dir `"C:\apks`"")
        }
        $nextVal = [string]$args[$i + 1]
        if ([string]::IsNullOrWhiteSpace($nextVal) -or $nextVal.StartsWith('--')) {
            Stop-WithGuidance `
                -WhatFailed (ConvertTo-Utf8DisplayText "Falta la ruta destino después de '$norm'.") `
                -HowToFix (ConvertTo-Utf8DisplayText "Proporciona una ruta válida o ejecuta compilar_release_dual.bat --help para ver ejemplos.")
        }
        $OutDir = $nextVal.Trim()
        $i++
        continue
    }
    if ($norm -like '--out-dir=*') {
        $val = $norm.Substring('--out-dir='.Length).Trim().Trim('"')
        if ([string]::IsNullOrWhiteSpace($val)) {
            Stop-WithGuidance `
                -WhatFailed (ConvertTo-Utf8DisplayText "La ruta en '--out-dir=' está vacía.") `
                -HowToFix (ConvertTo-Utf8DisplayText "Indica una carpeta destino válida o consulta compilar_release_dual.bat --help.")
        }
        $OutDir = $val
        continue
    }

    Stop-WithGuidance `
        -WhatFailed ((ConvertTo-Utf8DisplayText "Parámetro desconocido o no soportado: ") + $norm) `
        -HowToFix (ConvertTo-Utf8DisplayText "Ejecuta 'compilar_release_dual.bat --help' para consultar los parámetros válidos.")
}

if ($ShowHelp) {
    Show-UsageHelp
    exit 0
}

# ------------------------------------------------------------------------------
# Funciones auxiliares de descubrimiento y auditoría forense
# ------------------------------------------------------------------------------
function ConvertFrom-PubspecVersion {
    param([string]$PubspecPath)
    if (-not (Test-Path -LiteralPath $PubspecPath)) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "No se encontró el archivo pubspec.yaml en: ") + $PubspecPath) `
            -HowToFix (ConvertTo-Utf8DisplayText "Ejecuta el script desde la raíz de mochilalista-app o verifica que exista app_movil\pubspec.yaml.")
    }
    $lines = Get-Content -LiteralPath $PubspecPath -Encoding UTF8
    foreach ($line in $lines) {
        $cleanLine = ($line -replace '#.*$', '').Trim()
        if ($cleanLine -match '^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            $patch = [int]$matches[3]
            $build = [int]$matches[4]
            $versionName = "$major.$minor.$patch"
            $tag = if ($patch -eq 0) { "$major.$minor" } else { "$major.$minor.$patch" }
            return [PSCustomObject]@{
                Major       = $major
                Minor       = $minor
                Patch       = $patch
                BuildCode   = $build
                VersionName = $versionName
                Tag         = $tag
                FullVersion = "$versionName+$build"
            }
        }
    }
    Stop-WithGuidance `
        -WhatFailed ((ConvertTo-Utf8DisplayText "No se pudo leer una línea 'version: X.Y.Z+B' válida en: ") + $PubspecPath) `
        -HowToFix (ConvertTo-Utf8DisplayText "Verifica que pubspec.yaml contenga el formato SemVer completo, por ejemplo: version: 9.41.0+85")
}

function Test-KeystoreConfigSafe {
    param([string]$KeyPropertiesPath)
    if (-not (Test-Path -LiteralPath $KeyPropertiesPath)) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "No existe el archivo de configuración de firma android\key.properties en: ") + $KeyPropertiesPath) `
            -HowToFix (ConvertTo-Utf8DisplayText "Crea app_movil\android\key.properties con storeFile, keyAlias, storePassword y keyPassword antes de compilar.")
    }

    # Lectura segura: solo inspecciona la línea storeFile= sin almacenar ni imprimir contraseñas
    $storeFileValue = $null
    $lines = Get-Content -LiteralPath $KeyPropertiesPath -Encoding UTF8
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('#') -or [string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^storeFile\s*=\s*(.+)$') {
            $storeFileValue = $matches[1].Trim()
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($storeFileValue)) {
        Stop-WithGuidance `
            -WhatFailed (ConvertTo-Utf8DisplayText "El archivo key.properties no define la propiedad obligatoria 'storeFile='.") `
            -HowToFix (ConvertTo-Utf8DisplayText "Agrega 'storeFile=mochilalista-release-key.jks' (o la ruta a tu keystore) dentro de app_movil\android\key.properties.")
    }

    $androidDir = Split-Path -Parent $KeyPropertiesPath
    $resolvedStorePath = if ([System.IO.Path]::IsPathRooted($storeFileValue)) {
        $storeFileValue
    } else {
        Join-Path $androidDir $storeFileValue
    }

    if (-not (Test-Path -LiteralPath $resolvedStorePath)) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "El archivo keystore (.jks) configurado en storeFile no existe en disco: ") + $resolvedStorePath) `
            -HowToFix (ConvertTo-Utf8DisplayText "Coloca tu keystore oficial .jks en la ruta esperada o corrige la propiedad storeFile en app_movil\android\key.properties.")
    }

    return $resolvedStorePath
}

function Get-VersionSortKey {
    param([string]$FolderName)
    $parts = $FolderName -split '\.'
    $nums = @(0, 0, 0, 0)
    for ($k = 0; $k -lt [Math]::Min(4, $parts.Count); $k++) {
        $parsed = 0
        if ([int]::TryParse(($parts[$k] -replace '[^0-9]', ''), [ref]$parsed)) {
            $nums[$k] = $parsed
        }
    }
    return ([int64]$nums[0] * 1000000000) + ([int64]$nums[1] * 1000000) + ([int64]$nums[2] * 1000) + [int64]$nums[3]
}

function Resolve-AndroidBuildTools {
    $envAapt2 = $env:ML_DUAL_AAPT2_PATH
    $envSigner = $env:ML_DUAL_APKSIGNER_PATH

    if (-not [string]::IsNullOrWhiteSpace($envAapt2) -or -not [string]::IsNullOrWhiteSpace($envSigner)) {
        if ([string]::IsNullOrWhiteSpace($envAapt2) -or -not (Test-Path -LiteralPath $envAapt2)) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "La herramienta aapt2 configurada no existe: ") + $envAapt2) `
                -HowToFix (ConvertTo-Utf8DisplayText "Verifica Android SDK build-tools o la ruta configurada.")
        }
        if ([string]::IsNullOrWhiteSpace($envSigner) -or -not (Test-Path -LiteralPath $envSigner)) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "La herramienta apksigner configurada no existe: ") + $envSigner) `
                -HowToFix (ConvertTo-Utf8DisplayText "Verifica Android SDK build-tools o la ruta configurada.")
        }
        return [PSCustomObject]@{
            Version   = 'custom'
            Aapt2     = $envAapt2
            ApkSigner = $envSigner
        }
    }

    $rawRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($env:ML_DUAL_SDK_ROOT)) {
        $rawRoots = $env:ML_DUAL_SDK_ROOT -split ';'
    } else {
        $rawRoots = @(
            $env:ANDROID_HOME,
            $env:ANDROID_SDK_ROOT,
            (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
        )
    }

    $uniqueRoots = @()
    foreach ($r in $rawRoots) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $trimmed = $r.Trim()
        if ((Test-Path -LiteralPath $trimmed) -and ($uniqueRoots -notcontains $trimmed)) {
            $uniqueRoots += $trimmed
        }
    }

    foreach ($sdkRoot in $uniqueRoots) {
        $btRoot = Join-Path $sdkRoot 'build-tools'
        if (-not (Test-Path -LiteralPath $btRoot)) { continue }
        $verDirs = Get-ChildItem -LiteralPath $btRoot -Directory |
            Sort-Object -Property @{ Expression = { Get-VersionSortKey $_.Name }; Descending = $true }
        foreach ($dir in $verDirs) {
            $aapt2 = @('aapt2.exe', 'aapt2.cmd', 'aapt2.bat') |
                ForEach-Object { Join-Path $dir.FullName $_ } |
                Where-Object { Test-Path -LiteralPath $_ } |
                Select-Object -First 1
            $signer = @('apksigner.bat', 'apksigner.cmd', 'apksigner.exe') |
                ForEach-Object { Join-Path $dir.FullName $_ } |
                Where-Object { Test-Path -LiteralPath $_ } |
                Select-Object -First 1
            if ($aapt2 -and $signer) {
                return [PSCustomObject]@{
                    Version   = $dir.Name
                    Aapt2     = $aapt2
                    ApkSigner = $signer
                }
            }
        }
    }

    Stop-WithGuidance `
        -WhatFailed (ConvertTo-Utf8DisplayText "No se encontraron las herramientas 'aapt2' y 'apksigner' en Android SDK build-tools.") `
        -HowToFix (ConvertTo-Utf8DisplayText "Instala Android SDK Build-Tools desde Android Studio SDK Manager o configura ANDROID_HOME / ANDROID_SDK_ROOT.")
}

function Invoke-ProcessCaptured {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $outputLines = & $Executable @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevPref
    }
    $text = ($outputLines | ForEach-Object { "$_" }) -join "`n"
    return [PSCustomObject]@{
        ExitCode = $code
        Output   = $text
    }
}

function ConvertFrom-ApkSignerSummary {
    param([string]$RawOutput)
    $shaRegex = '^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+SHA-256\s+digest:\s*([0-9a-fA-F:]+)'
    $dnRegex = '^(?:V\d+(?:\.\d+)?\s+Signer:|Signer\s*#\d+)\s*certificate\s+DN:\s*(.+)$'

    $signers = @()
    $currentDn = $null
    $firstDn = $null

    foreach ($rawLine in ($RawOutput -split "`r?`n")) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.ToLowerInvariant().Contains('sourcestamp')) { continue }

        if ($line -match $dnRegex) {
            $currentDn = $matches[1].Trim()
            if (-not $firstDn) { $firstDn = $currentDn }
            continue
        }
        if ($line -match $shaRegex) {
            $cleanSha = ($matches[1] -replace ':', '').Trim().ToLowerInvariant()
            $signers += [PSCustomObject]@{
                Sha256 = $cleanSha
                Dn     = if ($currentDn) { $currentDn } else { $firstDn }
            }
        }
    }

    return $signers
}

function Test-ApkForensic {
    param(
        [string]$ApkPath,
        [string]$VariantLabel,
        [bool]$IsArm64Split,
        $VersionMeta,
        $BuildTools,
        [string]$ExpectedSha256
    )

    if (-not (Test-Path -LiteralPath $ApkPath)) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "No se encontró el archivo APK de ") + $VariantLabel + ": $ApkPath") `
            -HowToFix (ConvertTo-Utf8DisplayText "Verifica la ruta de salida (--out-dir) o ejecuta el script sin --verify-only para compilarlo.")
    }

    Write-Host ((ConvertTo-Utf8DisplayText "  -> Inspeccionando binario [") + $VariantLabel + "]: $ApkPath") -ForegroundColor Cyan

    # 1. Inspección con aapt2 dump badging
    $aaptRes = Invoke-ProcessCaptured -Executable $BuildTools.Aapt2 -Arguments @('dump', 'badging', $ApkPath)
    if ($aaptRes.ExitCode -ne 0) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "aapt2 dump badging falló sobre ") + $VariantLabel + (ConvertTo-Utf8DisplayText " (código ") + $aaptRes.ExitCode + ").") `
            -HowToFix ((ConvertTo-Utf8DisplayText "Verifica que el archivo .apk no esté corrupto ni bloqueado por antivirus. Detalle: ") + $aaptRes.Output)
    }

    $badging = $aaptRes.Output
    if ($badging -match 'application-debuggable') {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "El APK ") + $VariantLabel + (ConvertTo-Utf8DisplayText " contiene la bandera 'application-debuggable' (NO APTO PARA PRODUCCI") + [char]0x00D3 + "N).") `
            -HowToFix (ConvertTo-Utf8DisplayText "Recompila en modo --release sin flags de depuración y verifica app_movil/android/app/build.gradle.kts.")
    }

    if ($badging -notmatch "package:\s*name='([^']+)'") {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "aapt2 no devolvió el identificador 'package: name=...' en ") + $VariantLabel + ".") `
            -HowToFix (ConvertTo-Utf8DisplayText "Asegúrate de usar un Android SDK build-tools válido y un APK íntegro.")
    }
    $pkgName = $matches[1]
    if ($pkgName -ne $ExpectedPackageName) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "El packageName del APK (") + $pkgName + (ConvertTo-Utf8DisplayText ") no coincide con ") + $ExpectedPackageName + ".") `
            -HowToFix (ConvertTo-Utf8DisplayText "Verifica que el binario pertenezca al proyecto MochilaLista oficial.")
    }

    $apkVerName = $null
    if ($badging -match "versionName='([^']+)'") { $apkVerName = $matches[1] }
    if ($apkVerName -ne $VersionMeta.VersionName) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "versionName del APK (") + $apkVerName + (ConvertTo-Utf8DisplayText ") difiere de pubspec.yaml (") + $VersionMeta.VersionName + ").") `
            -HowToFix (ConvertTo-Utf8DisplayText "Recompila ambos APKs tras actualizar pubspec.yaml para mantener la paridad exacta de versión.")
    }

    $apkVerCode = $null
    if ($badging -match "versionCode='(\d+)'") { $apkVerCode = [int]$matches[1] }
    $expectedArmCode = 2000 + $VersionMeta.BuildCode
    $isVerCodeValid = if ($IsArm64Split) {
        ($apkVerCode -eq $expectedArmCode) -or ($apkVerCode -eq $VersionMeta.BuildCode)
    } else {
        ($apkVerCode -eq $VersionMeta.BuildCode)
    }
    if (-not $isVerCodeValid) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "versionCode del APK ") + $VariantLabel + " ($apkVerCode) " + (ConvertTo-Utf8DisplayText "no corresponde al build esperado de pubspec.yaml (") + $VersionMeta.BuildCode + ").") `
            -HowToFix (ConvertTo-Utf8DisplayText "Recompila ambos binarios sin artefactos antiguos en build/.")
    }

    $abisText = ''
    if ($badging -match "native-code:\s*([^\r\n]+)") {
        $abisText = $matches[1].Trim()
    }
    $minSdk = '24'
    if ($badging -match "sdkVersion:'([^']+)'") {
        $minSdk = $matches[1].Trim()
    }
    $targetSdk = '36'
    if ($badging -match "targetSdkVersion:'([^']+)'") {
        $targetSdk = $matches[1].Trim()
    }
    if ($IsArm64Split) {
        if (-not $abisText.Contains('arm64-v8a') -or $abisText.Contains('armeabi-v7a') -or $abisText.Contains('x86_64')) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "El APK ARM64 Ligero reporta ABIs inesperadas: ") + $abisText) `
                -HowToFix (ConvertTo-Utf8DisplayText "Asegúrate de compilar el binario ligero con --split-per-abi y copiar app-arm64-v8a-release.apk.")
        }
    } else {
        if (-not $abisText.Contains('arm64-v8a') -or -not $abisText.Contains('armeabi-v7a') -or $abisText.Contains('x86_64')) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "El APK Universal reporta ABIs inesperadas (se exige arm64-v8a + armeabi-v7a sin x86_64): ") + $abisText) `
                -HowToFix (ConvertTo-Utf8DisplayText "Compila el APK Universal con --target-platform android-arm64,android-arm y sin --split-per-abi.")
        }
    }

    # 2. Certificación criptográfica con apksigner (compatible SDK <=36 y 37+)
    $sigRes = Invoke-ProcessCaptured -Executable $BuildTools.ApkSigner -Arguments @('verify', '--verbose', '--print-certs', $ApkPath)
    if ($sigRes.ExitCode -ne 0) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "apksigner verify rechazó la firma digital de ") + $VariantLabel + (ConvertTo-Utf8DisplayText " (código ") + $sigRes.ExitCode + ").") `
            -HowToFix ((ConvertTo-Utf8DisplayText "Firma nuevamente con el keystore oficial RSA-4096. Detalle: ") + $sigRes.Output)
    }

    $signers = @(ConvertFrom-ApkSignerSummary -RawOutput $sigRes.Output)
    if ($signers.Count -eq 0) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "apksigner verify finalizó sin reportar una huella SHA-256 legible para ") + $VariantLabel + ".") `
            -HowToFix (ConvertTo-Utf8DisplayText "Actualiza Android SDK build-tools y verifica la integridad del binario.")
    }

    $normalizedExpected = $ExpectedSha256.Trim().ToLowerInvariant()
    $matchedSigner = $signers | Where-Object { $_.Sha256 -eq $normalizedExpected } | Select-Object -First 1
    if (-not $matchedSigner) {
        $foundSha = $signers[0].Sha256
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "FIRMA NO OFICIAL en ") + $VariantLabel + (ConvertTo-Utf8DisplayText ". Huella detectada: ") + $foundSha + (ConvertTo-Utf8DisplayText " | Esperada: ") + $normalizedExpected) `
            -HowToFix (ConvertTo-Utf8DisplayText "El binario no fue firmado con el keystore oficial de Julio Angello Vasquez Navarro (posible debug.apk). Revisa app_movil\android\key.properties.")
    }

    $item = Get-Item -LiteralPath $ApkPath
    $fileSha256 = (Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $sizeMb = [math]::Round($item.Length / 1MB, 2).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)

    Write-Host ((ConvertTo-Utf8DisplayText "     [OK] aapt2: ") + "$pkgName v$apkVerName (code $apkVerCode) | ABIs: $abisText | debuggable: AUSENTE") -ForegroundColor Green
    Write-Host ((ConvertTo-Utf8DisplayText "     [OK] apksigner: RSA-4096 oficial verificado (") + $matchedSigner.Sha256.Substring(0, 16) + "...)") -ForegroundColor Green

    return [PSCustomObject]@{
        Variant      = $VariantLabel
        Path         = $ApkPath
        FileName     = $item.Name
        SizeBytes    = $item.Length
        SizeMb       = $sizeMb
        FileSha256   = $fileSha256
        VersionCode  = $apkVerCode
        Abis         = $abisText
        MinSdk       = $minSdk
        TargetSdk    = $targetSdk
        SignerSha256 = $matchedSigner.Sha256
        SignerDn     = $matchedSigner.Dn
    }
}

function Get-LimaTimestampString {
    try {
        $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('SA Pacific Standard Time')
        $limaNow = [System.TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $tz)
    } catch {
        $limaNow = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(-5))
    }
    return $limaNow.ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture) + ' (America/Lima GMT-5)'
}

function New-CompanionAtpTechnicalTemplate {
    param(
        $VersionMeta,
        $CertUniv,
        $CertArm64,
        [string]$SavingsPct,
        [string]$LimaTimestamp
    )
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $univBytesFmt = ([int64]$CertUniv.SizeBytes).ToString('N0', $inv)
    $armBytesFmt = ([int64]$CertArm64.SizeBytes).ToString('N0', $inv)
    $univDisplayAbis = (($CertUniv.Abis -replace "'", '') -replace '\s+', ', ').Trim(', ')
    if ([string]::IsNullOrWhiteSpace($univDisplayAbis)) { $univDisplayAbis = 'arm64-v8a, armeabi-v7a' }

    $atpBulletVer = (ConvertTo-Utf8DisplayText "Versión: ") + "v$($VersionMeta.FullVersion) (Build Code $($VersionMeta.BuildCode) | ARM64 split code $($CertArm64.VersionCode))"
    $atpBulletDate = (ConvertTo-Utf8DisplayText "Fecha de Compilación: ") + $LimaTimestamp
    $atpBulletEnv = (ConvertTo-Utf8DisplayText "Ambiente: Producción Comercial Oficial (Ofuscado con --dart-define=PRODUCTION=true)")
    $atpSecIdent = (ConvertTo-Utf8DisplayText "IDENTIFICACI") + [char]0x00D3 + (ConvertTo-Utf8DisplayText "N DE BINARIOS (RELEASE DUAL UNIVERSAL + ARM64 LIGERO)")
    $atpSecFirm = (ConvertTo-Utf8DisplayText "CERTIFICACI") + [char]0x00D3 + (ConvertTo-Utf8DisplayText "N CRIPTOGR") + [char]0x00C1 + (ConvertTo-Utf8DisplayText "FICA Y FIRMA DIGITAL (AMBOS BINARIOS)")
    $emDash = [char]0x2014

    $lines = @(
        ((ConvertTo-Utf8DisplayText "FICHA T") + [char]0x00C9 + "CNICA DE LANZAMIENTO OFICIAL - MOCHILALISTA POS"),
        $atpBulletVer,
        $atpBulletDate,
        $atpBulletEnv,
        "",
        "================================================================================",
        $atpSecIdent,
        "================================================================================",
        (ConvertTo-Utf8DisplayText "[1] APK UNIVERSAL (Compatibilidad Completa)"),
        "Archivo: $($CertUniv.FileName)",
        "Ruta de Entrega: $($CertUniv.Path)",
        ((ConvertTo-Utf8DisplayText "Tamaño: ") + "$($CertUniv.SizeMb) MB ($univBytesFmt bytes)"),
        "Hash SHA-256: $($CertUniv.FileSha256)",
        "Package Name: $ExpectedPackageName",
        "Version Name / Code: $($VersionMeta.VersionName) (versionCode $($CertUniv.VersionCode))",
        "Native Code ABIs: $univDisplayAbis",
        "Target SDK: $($CertUniv.TargetSdk) | Min SDK: $($CertUniv.MinSdk)",
        "Esquema de Base de Datos SQLite: v36",
        (ConvertTo-Utf8DisplayText "Inspección aapt2: application-debuggable AUSENTE (0 ocurrencias)"),
        "",
        ((ConvertTo-Utf8DisplayText "[2] APK ARM64 LIGERO (Optimizado para Descarga R") + [char]0x00E1 + "pida por WhatsApp)"),
        "Archivo: $($CertArm64.FileName)",
        "Ruta de Entrega: $($CertArm64.Path)",
        ((ConvertTo-Utf8DisplayText "Tamaño: ") + "$($CertArm64.SizeMb) MB ($armBytesFmt bytes) $emDash Ahorro del -$SavingsPct % frente al Universal ($($CertUniv.SizeMb) MB)"),
        "Hash SHA-256: $($CertArm64.FileSha256)",
        "Package Name: $ExpectedPackageName",
        ("Version Name / Code: $($VersionMeta.VersionName) (versionCode $($CertArm64.VersionCode) $emDash split ARM64)"),
        "Native Code ABI Exclusiva: arm64-v8a",
        "Target SDK: $($CertArm64.TargetSdk) | Min SDK: $($CertArm64.MinSdk)",
        "Esquema de Base de Datos SQLite: v36",
        (ConvertTo-Utf8DisplayText "Inspección aapt2: application-debuggable AUSENTE (0 ocurrencias)"),
        "",
        "================================================================================",
        $atpSecFirm,
        "================================================================================",
        (ConvertTo-Utf8DisplayText "Herramienta de Auditoría: ") + "Android SDK build-tools $($BuildTools.Version) apksigner (APK Signature Scheme v2 verified: true)",
        "Titular del Certificado: $($CertUniv.SignerDn)",
        "Algoritmo de Firma: RSA 4096 bits",
        "Huella Digital SHA-256 Oficial: $($CertUniv.SignerSha256)",
        (ConvertTo-Utf8DisplayText "Estado de Inspección Anti-debug: OFICIAL CERTIFICADO (Verificación exitosa exit code 0 en ambos binarios)"),
        "",
        "================================================================================",
        ((ConvertTo-Utf8DisplayText "ALCANCE T") + [char]0x00C9 + "CNICO DEL RELEASE v$($VersionMeta.FullVersion)"),
        "================================================================================",
        (ConvertTo-Utf8DisplayText "1. Mejoras y Alcance Principal:"),
        (ConvertTo-Utf8DisplayText "   - [Completa aquí el resumen técnico principal de v$($VersionMeta.FullVersion)]."),
        (ConvertTo-Utf8DisplayText "   - [Integridad verificada con esquema SQLite v36 sin migraciones destructivas]."),
        ""
    )
    return ($lines -join "`r`n")
}

function New-CompanionChangesTemplate {
    param($VersionMeta)
    $bullet = [char]0x2022
    $lines = @(
        ($bullet + (ConvertTo-Utf8DisplayText " Mejora Principal v$($VersionMeta.VersionName): Actualización oficial certificada con optimizaciones de estabilidad y rendimiento diario.")),
        ($bullet + (ConvertTo-Utf8DisplayText " Compatibilidad y Seguridad Offline: Edición Universal y edición Ligera ARM64 listas para instalar por WhatsApp conservando intactos tus negocios, catálogo y respaldos."))
    )
    return ($lines -join "`r`n") + "`r`n"
}

# ==============================================================================
# EJECUCION PRINCIPAL EN 6 PASOS GUIADOS
# ==============================================================================
$PubspecPath = if ($env:ML_DUAL_PUBSPEC_PATH) { $env:ML_DUAL_PUBSPEC_PATH } else { Join-Path $RepoRoot 'app_movil\pubspec.yaml' }
$KeyPropertiesPath = if ($env:ML_DUAL_KEY_PROPERTIES_PATH) { $env:ML_DUAL_KEY_PROPERTIES_PATH } else { Join-Path $RepoRoot 'app_movil\android\key.properties' }
$AppMovilDir = Join-Path $RepoRoot 'app_movil'
$BuildOutputDir = if ($env:ML_DUAL_BUILD_OUTPUT_DIR) { $env:ML_DUAL_BUILD_OUTPUT_DIR } else { Join-Path $AppMovilDir 'build\app\outputs\flutter-apk' }
$ExpectedSignerSha256 = if ($env:ML_DUAL_EXPECTED_SIGNER_SHA256) { $env:ML_DUAL_EXPECTED_SIGNER_SHA256 } else { $DefaultSignerSha256 }
$FlutterCmd = if ($env:ML_DUAL_FLUTTER_CMD) { $env:ML_DUAL_FLUTTER_CMD } else { 'flutter' }

Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host (ConvertTo-Utf8DisplayText "  MOCHILALISTA - COMPILADOR DUAL OFICIAL (UNIVERSAL + ARM64 LIGERO)") -ForegroundColor Cyan
Write-Host "========================================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# [Paso 1/6] Pre-chequeos de entorno y herramientas
# ------------------------------------------------------------------------------
Write-Host (ConvertTo-Utf8DisplayText "[Paso 1/6] Validando entorno, pubspec.yaml, firma y Android SDK...") -ForegroundColor Yellow

$VersionMeta = ConvertFrom-PubspecVersion -PubspecPath $PubspecPath
$ResolvedKeystore = Test-KeystoreConfigSafe -KeyPropertiesPath $KeyPropertiesPath

if (-not $VerifyOnly) {
    $flutterFound = Get-Command $FlutterCmd -ErrorAction SilentlyContinue
    if (-not $flutterFound) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "No se encontró el ejecutable '") + $FlutterCmd + (ConvertTo-Utf8DisplayText "' en el PATH del sistema.")) `
            -HowToFix (ConvertTo-Utf8DisplayText "Instala Flutter SDK o agrega flutter\bin a las Variables de Entorno del sistema y abre una nueva consola.")
    }
}

$BuildTools = Resolve-AndroidBuildTools

$UniversalTargetName = "mochilalista_v$($VersionMeta.Tag)_atp.apk"
$Arm64TargetName = "mochilalista_v$($VersionMeta.Tag)_arm64_atp.apk"
$UniversalTargetPath = Join-Path $OutDir $UniversalTargetName
$Arm64TargetPath = Join-Path $OutDir $Arm64TargetName
$NotesAtpPath = Join-Path $OutDir "mochilalista_v$($VersionMeta.Tag)_atp.txt"
$NotesChangesPath = Join-Path $OutDir "mochilalista_v$($VersionMeta.Tag)_atp_cambios.txt"

if (-not $DryRun -and -not $VerifyOnly) {
    if (-not (Test-Path -LiteralPath $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
}

Write-Host ((ConvertTo-Utf8DisplayText "  [OK] Versión detectada  : v") + "$($VersionMeta.FullVersion) (tag: v$($VersionMeta.Tag))") -ForegroundColor Green
Write-Host ((ConvertTo-Utf8DisplayText "  [OK] Keystore verificado: ") + $ResolvedKeystore) -ForegroundColor Green
Write-Host ((ConvertTo-Utf8DisplayText "  [OK] SDK build-tools    : ") + "$($BuildTools.Version) (aapt2 + apksigner listos)") -ForegroundColor Green
Write-Host ((ConvertTo-Utf8DisplayText "  [OK] Carpeta destino    : ") + $OutDir) -ForegroundColor Green
Write-Host ""

if ($DryRun) {
    Write-Host ((ConvertTo-Utf8DisplayText "[MODO SIMULACI") + [char]0x00D3 + (ConvertTo-Utf8DisplayText "N --dry-run] Pre-chequeos superados. No se compilará ni escribirá en disco.")) -ForegroundColor Cyan
    Write-Host ""
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 2/6] Análisis estático : ") -NoNewline; Write-Host $(if ($SkipAnalyze) { ConvertTo-Utf8DisplayText "Omitido por --skip-analyze" } else { "$FlutterCmd analyze --no-pub" }) -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 3/6] Build Universal   : ") -NoNewline; Write-Host "$FlutterCmd build apk --release --target-platform android-arm64,android-arm --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true" -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "             Entrega Universal : ") -NoNewline; Write-Host $UniversalTargetPath -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 4/6] Build ARM64       : ") -NoNewline; Write-Host "$FlutterCmd build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true" -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "             Entrega ARM64     : ") -NoNewline; Write-Host $Arm64TargetPath -ForegroundColor Gray
    Write-Host (ConvertTo-Utf8DisplayText "  [Paso 5/6] Certificación     : ") -NoNewline; Write-Host "aapt2 dump badging + apksigner verify (SHA-256 $ExpectedSignerSha256)" -ForegroundColor Gray
    if ($InitNotes) {
        $dryAtp = if (Test-Path -LiteralPath $NotesAtpPath) { ConvertTo-Utf8DisplayText "Ya existe en disco (se respetará sin sobrescribir)" } else { ConvertTo-Utf8DisplayText "Creará plantilla técnica (UTF-8 sin BOM)" }
        $dryChg = if (Test-Path -LiteralPath $NotesChangesPath) { ConvertTo-Utf8DisplayText "Ya existe en disco (se respetará sin sobrescribir)" } else { ConvertTo-Utf8DisplayText "Creará plantilla de cambios (UTF-8 sin BOM)" }
        Write-Host (ConvertTo-Utf8DisplayText "  [Paso 6/6] Notas (--init-notes): ") -NoNewline; Write-Host "$NotesAtpPath [$dryAtp] | $NotesChangesPath [$dryChg]" -ForegroundColor Gray
    } else {
        Write-Host (ConvertTo-Utf8DisplayText "  [Paso 6/6] Notas compañeras  : ") -NoNewline; Write-Host "$NotesAtpPath | $NotesChangesPath" -ForegroundColor Gray
    }
    Write-Host ""
    Wait-IfInteractive -ForceNoPause $NoPause
    exit 0
}

# ------------------------------------------------------------------------------
# [Paso 2/6], [Paso 3/6], [Paso 4/6] Análisis y Compilación (o salto en --verify-only)
# ------------------------------------------------------------------------------
if ($VerifyOnly) {
    Write-Host (ConvertTo-Utf8DisplayText "[Paso 2/6] Análisis estático omitido (modo --verify-only).") -ForegroundColor DarkGray
    Write-Host (ConvertTo-Utf8DisplayText "[Paso 3/6] Compilación Universal omitida (auditando APK existente en destino).") -ForegroundColor DarkGray
    Write-Host (ConvertTo-Utf8DisplayText "[Paso 4/6] Compilación ARM64 omitida (auditando APK existente en destino).") -ForegroundColor DarkGray
    Write-Host ""
} else {
    if (-not (Test-Path -LiteralPath $AppMovilDir)) {
        Stop-WithGuidance `
            -WhatFailed ((ConvertTo-Utf8DisplayText "No se encontró el directorio app_movil en: ") + $AppMovilDir) `
            -HowToFix (ConvertTo-Utf8DisplayText "Ejecuta el script desde la raíz del proyecto MochilaLista.")
    }

    Push-Location -LiteralPath $AppMovilDir
    try {
        # [Paso 2/6] Análisis estático
        if ($SkipAnalyze) {
            Write-Host (ConvertTo-Utf8DisplayText "[Paso 2/6] Análisis estático omitido por --skip-analyze.") -ForegroundColor DarkGray
        } else {
            Write-Host (ConvertTo-Utf8DisplayText "[Paso 2/6] Ejecutando análisis estático (flutter analyze --no-pub)...") -ForegroundColor Yellow
            & $FlutterCmd analyze --no-pub
            if ($LASTEXITCODE -ne 0) {
                Stop-WithGuidance `
                    -WhatFailed ((ConvertTo-Utf8DisplayText "flutter analyze --no-pub detectó errores o advertencias (código ") + $LASTEXITCODE + ").") `
                    -HowToFix (ConvertTo-Utf8DisplayText "Corrige los errores reportados arriba en app_movil/ antes de emitir un release comercial.")
            }
            Write-Host (ConvertTo-Utf8DisplayText "  [OK] Análisis estático limpio.") -ForegroundColor Green
        }
        Write-Host ""

        $symbolsDir = Join-Path $AppMovilDir 'build\app_symbols'
        if (-not (Test-Path -LiteralPath $symbolsDir)) {
            New-Item -ItemType Directory -Path $symbolsDir -Force | Out-Null
        }

        # [Paso 3/6] Compilación APK Universal ARM físico
        Write-Host (ConvertTo-Utf8DisplayText "[Paso 3/6] Compilando APK Universal ARM físico ofuscado (arm64-v8a + armeabi-v7a)...") -ForegroundColor Yellow
        & $FlutterCmd build apk --release --target-platform android-arm64,android-arm --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
        if ($LASTEXITCODE -ne 0) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "La compilación del APK Universal falló (código ") + $LASTEXITCODE + ").") `
                -HowToFix (ConvertTo-Utf8DisplayText "Revisa el error de Gradle/Flutter arriba (SDK, dependencias o key.properties) y vuelve a intentar.")
        }
        $srcUniv = Join-Path $BuildOutputDir 'app-release.apk'
        if (-not (Test-Path -LiteralPath $srcUniv)) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "No se generó app-release.apk en: ") + $srcUniv) `
                -HowToFix (ConvertTo-Utf8DisplayText "Verifica la salida de Gradle/Flutter y permisos de escritura en app_movil\build.")
        }
        Copy-Item -LiteralPath $srcUniv -Destination $UniversalTargetPath -Force
        Write-Host ((ConvertTo-Utf8DisplayText "  [OK] Universal entregado en: ") + $UniversalTargetPath) -ForegroundColor Green
        Write-Host ""

        # [Paso 4/6] Compilación APK ARM64 Ligero
        Write-Host (ConvertTo-Utf8DisplayText "[Paso 4/6] Compilando APK ARM64 Ligero ofuscado (--split-per-abi para WhatsApp)...") -ForegroundColor Yellow
        & $FlutterCmd build apk --release --split-per-abi --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
        if ($LASTEXITCODE -ne 0) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "La compilación del APK ARM64 Ligero falló (código ") + $LASTEXITCODE + ").") `
                -HowToFix (ConvertTo-Utf8DisplayText "Revisa el error de Gradle/Flutter arriba y vuelve a intentar.")
        }
        $srcArm64 = Join-Path $BuildOutputDir 'app-arm64-v8a-release.apk'
        if (-not (Test-Path -LiteralPath $srcArm64)) {
            Stop-WithGuidance `
                -WhatFailed ((ConvertTo-Utf8DisplayText "No se generó app-arm64-v8a-release.apk en: ") + $srcArm64) `
                -HowToFix (ConvertTo-Utf8DisplayText "Confirma que --split-per-abi haya producido el APK arm64-v8a.")
        }
        Copy-Item -LiteralPath $srcArm64 -Destination $Arm64TargetPath -Force
        Write-Host ((ConvertTo-Utf8DisplayText "  [OK] ARM64 Ligero entregado en: ") + $Arm64TargetPath) -ForegroundColor Green
        Write-Host ""
    } finally {
        Pop-Location
    }
}

# ------------------------------------------------------------------------------
# [Paso 5/6] Certificación forense obligatoria sobre AMBOS APKs
# ------------------------------------------------------------------------------
Write-Host (ConvertTo-Utf8DisplayText "[Paso 5/6] Ejecutando certificación forense (aapt2 + apksigner) sobre ambos APKs...") -ForegroundColor Yellow

$CertUniv = Test-ApkForensic `
    -ApkPath $UniversalTargetPath `
    -VariantLabel 'Universal' `
    -IsArm64Split $false `
    -VersionMeta $VersionMeta `
    -BuildTools $BuildTools `
    -ExpectedSha256 $ExpectedSignerSha256

$CertArm64 = Test-ApkForensic `
    -ApkPath $Arm64TargetPath `
    -VariantLabel 'ARM64 Ligero' `
    -IsArm64Split $true `
    -VersionMeta $VersionMeta `
    -BuildTools $BuildTools `
    -ExpectedSha256 $ExpectedSignerSha256

Write-Host ""

# ------------------------------------------------------------------------------
# [Paso 6/6] Resumen Ejecutivo y Checklist de Siguientes Pasos
# ------------------------------------------------------------------------------
Write-Host (ConvertTo-Utf8DisplayText "[Paso 6/6] Generando resumen ejecutivo oficial...") -ForegroundColor Yellow

$SavingsPct = if ($CertUniv.SizeBytes -gt 0) {
    [math]::Round((1.0 - ($CertArm64.SizeBytes / [double]$CertUniv.SizeBytes)) * 100.0, 2).ToString('0.00', [System.Globalization.CultureInfo]::InvariantCulture)
} else {
    '0.00'
}

if ($InitNotes) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $limaNowStr = Get-LimaTimestampString
    $alreadyRespectedMsg = (ConvertTo-Utf8DisplayText "Ya existe en disco ") + [char]0x2014 + (ConvertTo-Utf8DisplayText " respetada sin sobrescribir")

    if (Test-Path -LiteralPath $NotesAtpPath) {
        $AtpTxtStatus = $alreadyRespectedMsg
    } else {
        if (-not (Test-Path -LiteralPath $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        }
        $atpBody = New-CompanionAtpTechnicalTemplate `
            -VersionMeta $VersionMeta `
            -CertUniv $CertUniv `
            -CertArm64 $CertArm64 `
            -SavingsPct $SavingsPct `
            -LimaTimestamp $limaNowStr
        [System.IO.File]::WriteAllText($NotesAtpPath, $atpBody, $utf8NoBom)
        $AtpTxtStatus = ConvertTo-Utf8DisplayText "Creada plantilla técnica en UTF-8 sin BOM"
    }

    if (Test-Path -LiteralPath $NotesChangesPath) {
        $CambiosTxtStatus = $alreadyRespectedMsg
    } else {
        if (-not (Test-Path -LiteralPath $OutDir)) {
            New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
        }
        $changesBody = New-CompanionChangesTemplate -VersionMeta $VersionMeta
        [System.IO.File]::WriteAllText($NotesChangesPath, $changesBody, $utf8NoBom)
        $CambiosTxtStatus = ConvertTo-Utf8DisplayText "Creada plantilla de cambios en UTF-8 sin BOM"
    }
} else {
    $AtpTxtStatus = if (Test-Path -LiteralPath $NotesAtpPath) { ConvertTo-Utf8DisplayText "Presente en disco (respetada)" } else { ConvertTo-Utf8DisplayText "No encontrada (opcional crear antes de publicar)" }
    $CambiosTxtStatus = if (Test-Path -LiteralPath $NotesChangesPath) { ConvertTo-Utf8DisplayText "Presente en disco (respetada)" } else { ConvertTo-Utf8DisplayText "No encontrada (opcional crear antes de publicar)" }
}

Write-Host ""
Write-Host "========================================================================" -ForegroundColor Green
Write-Host ((ConvertTo-Utf8DisplayText "  CERTIFICACI") + [char]0x00D3 + "N DUAL COMPLETA " + [char]0x2014 + " MOCHILALISTA v" + $VersionMeta.FullVersion) -ForegroundColor Green
Write-Host "========================================================================" -ForegroundColor Green
Write-Host (ConvertTo-Utf8DisplayText "[1] APK UNIVERSAL (Compatibilidad completa Android):") -ForegroundColor White
Write-Host ((ConvertTo-Utf8DisplayText "    Archivo   : ") + $CertUniv.Path) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    Tamaño    : ") + "$($CertUniv.SizeMb) MB ($($CertUniv.SizeBytes) bytes)") -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    SHA-256   : ") + $CertUniv.FileSha256) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    Metadatos : ") + "versionCode=$($CertUniv.VersionCode) | ABIs=$($CertUniv.Abis)") -ForegroundColor Gray
Write-Host ""
Write-Host (ConvertTo-Utf8DisplayText "[2] APK ARM64 LIGERO (Recomendado para envío directo por WhatsApp):") -ForegroundColor White
Write-Host ((ConvertTo-Utf8DisplayText "    Archivo   : ") + $CertArm64.Path) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    Tamaño    : ") + "$($CertArm64.SizeMb) MB ($($CertArm64.SizeBytes) bytes) " + ([char]0x2014 + (ConvertTo-Utf8DisplayText " Ahorro del ") + "$SavingsPct % ") + (ConvertTo-Utf8DisplayText "frente al Universal")) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    SHA-256   : ") + $CertArm64.FileSha256) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    Metadatos : ") + "versionCode=$($CertArm64.VersionCode) | ABIs=$($CertArm64.Abis)") -ForegroundColor Gray
Write-Host ""
Write-Host ((ConvertTo-Utf8DisplayText "[3] FIRMA OFICIAL Y NOTAS COMPA") + [char]0x00D1 + "ERAS:") -ForegroundColor White
Write-Host ((ConvertTo-Utf8DisplayText "    Certificado    : ") + $CertUniv.SignerDn) -ForegroundColor Gray
Write-Host ((ConvertTo-Utf8DisplayText "    Huella RSA-4096: ") + $CertUniv.SignerSha256) -ForegroundColor Green
Write-Host ("    mochilalista_v$($VersionMeta.Tag)_atp.txt        : $AtpTxtStatus") -ForegroundColor Gray
Write-Host ("    mochilalista_v$($VersionMeta.Tag)_atp_cambios.txt: $CambiosTxtStatus") -ForegroundColor Gray
Write-Host ""
Write-Host (ConvertTo-Utf8DisplayText "CHECKLIST DE SIGUIENTES PASOS (MochilaLista Admin > Versiones APK):") -ForegroundColor Cyan
Write-Host (ConvertTo-Utf8DisplayText "  1. Abre MochilaLista Admin (http://localhost:8080) -> pestaña 'Versiones APK'.") -ForegroundColor White
Write-Host ((ConvertTo-Utf8DisplayText "  2. Pulsa 'Subir / Registrar Nueva Versión del APK' y selecciona ") + $CertUniv.FileName + (ConvertTo-Utf8DisplayText " en Biblioteca Oficial.")) -ForegroundColor White
Write-Host (ConvertTo-Utf8DisplayText "  3. Revisa que los metadatos, changelog y firma 'Oficial RSA-4096' se carguen y guarda el lanzamiento.") -ForegroundColor White
Write-Host ((ConvertTo-Utf8DisplayText "  4. Abre 'Editar Versión' sobre v") + $VersionMeta.VersionName + (ConvertTo-Utf8DisplayText " y vincula la variante ARM64 Ligero (") + $CertArm64.FileName + ").") -ForegroundColor White
Write-Host "========================================================================" -ForegroundColor Green

Wait-IfInteractive -ForceNoPause $NoPause
exit 0
