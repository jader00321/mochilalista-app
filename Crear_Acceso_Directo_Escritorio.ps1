# ==============================================================================
# MochilaLista Admin - Creador Oficial de Acceso Directo de Escritorio
# Compatible con Microsoft OneDrive y carpetas redirigidas de usuario
# ==============================================================================

$ErrorActionPreference = 'Stop'

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  CREADOR DE ACCESO DIRECTO OFICIAL: MOCHILALISTA ADMIN" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Determinar la raiz del proyecto desde el script
$projectRoot = $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = (Get-Location).Path
}

# 2. Rutas criticas
$batLauncher = Join-Path $projectRoot "Iniciar_MochilaLista_Admin.bat"
$iconPath = Join-Path $projectRoot "mochilalista_admin\web\favicon.ico"

# 3. Validar existencia de archivos fuente
if (-not (Test-Path $batLauncher)) {
    Write-Error "No se encontro el lanzador Iniciar_MochilaLista_Admin.bat en: $batLauncher"
}
if (-not (Test-Path $iconPath)) {
    Write-Error "No se encontro el icono oficial en: $iconPath"
}

Write-Host "[OK] Lanzador verificado: $batLauncher" -ForegroundColor Green
Write-Host "[OK] Icono oficial verificado: $iconPath" -ForegroundColor Green

# 4. Resolver la ruta real del Escritorio
$desktopPath = [Environment]::GetFolderPath('Desktop')
if (-not (Test-Path $desktopPath)) {
    Write-Error "No se pudo acceder a la carpeta de Escritorio: $desktopPath"
}
Write-Host "[OK] Ruta de Escritorio detectada: $desktopPath" -ForegroundColor Green

# 5. Crear el Acceso Directo (.lnk)
$shortcutPath = Join-Path $desktopPath "MochilaLista Admin.lnk"

try {
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $batLauncher
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.WindowStyle = 7 # 7 = Minimized window
    $shortcut.IconLocation = "$iconPath,0"
    $shortcut.Description = "MochilaLista Admin - Centro Ejecutivo de Licencias y Versiones"
    $shortcut.Save()

    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wshShell) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host " [EXITO] Acceso directo creado exitosamente en tu Escritorio:" -ForegroundColor Green
    Write-Host " Ruta: $shortcutPath" -ForegroundColor White
    Write-Host " Target: $batLauncher" -ForegroundColor White
    Write-Host " Icono: $iconPath,0" -ForegroundColor White
    Write-Host " Modo: Ventana CMD Minimizada (Estilo 7)" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Error "Error al crear el acceso directo: $_"
}
