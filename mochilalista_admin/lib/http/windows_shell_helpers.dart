import 'dart:convert';
import 'dart:io';

/// Construye argumentos seguros de PowerShell `-NoProfile -STA` con UTF-8 y `Dispose()`
/// para abrir el selector nativo de carpetas de Windows sin ocultar ni colgar el diálogo.
List<String> buildWindowsFolderPickerPsArgs({
  String? initialPath,
  String? description,
}) {
  final safeInitial = (initialPath ?? '').trim().replaceAll("'", "''");
  final safeDescription = (description ??
          'Selecciona una carpeta donde guardas tus archivos .APK de MochilaLista')
      .trim()
      .replaceAll("'", "''");
  final lines = <String>[
    '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8',
    'Add-Type -AssemblyName System.Windows.Forms',
    r'$topForm = New-Object System.Windows.Forms.Form',
    r'$topForm.TopMost = $true',
    r'$topForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual',
    r'$topForm.Location = New-Object System.Drawing.Point(-32000, -32000)',
    r'$topForm.Size = New-Object System.Drawing.Size(1, 1)',
    r'$topForm.ShowInTaskbar = $false',
    r'$dialog = New-Object System.Windows.Forms.FolderBrowserDialog',
    "\$dialog.Description = '$safeDescription'",
    r'$dialog.ShowNewFolderButton = $false',
    if (safeInitial.isNotEmpty)
      "if (Test-Path -LiteralPath '$safeInitial') { \$dialog.SelectedPath = '$safeInitial' }",
    r'try {',
    r'  $topForm.Show()',
    r'  $topForm.Activate()',
    r'  $result = $dialog.ShowDialog($topForm)',
    r'  if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {',
    r'    [Console]::Out.WriteLine($dialog.SelectedPath)',
    r'  }',
    r'} finally {',
    r'  if ($dialog) { $dialog.Dispose() }',
    r'  if ($topForm) { $topForm.Dispose() }',
    r'}',
  ];
  return ['-NoProfile', '-STA', '-Command', lines.join('\n')];
}

/// Construye argumentos seguros de PowerShell `-NoProfile -STA` para copiar
/// un archivo real como `CF_HDROP` (`FileDrop` + `Preferred DropEffect` COPY)
/// compatible con WhatsApp Desktop / Chromium / Explorador de Windows.
List<String> buildWindowsClipboardPsArgs(String fullPath) {
  final escaped = fullPath.replaceAll("'", "''");
  final psScript = [
    'Add-Type -AssemblyName System.Windows.Forms',
    r"$p = '" + escaped + "'",
    r"if (-not (Test-Path -LiteralPath $p)) { Write-Error ('Archivo no encontrado: ' + $p); exit 2 }",
    r'$dataObj = New-Object System.Windows.Forms.DataObject',
    r'$col = New-Object System.Collections.Specialized.StringCollection',
    r'[void]$col.Add($p)',
    r'$dataObj.SetFileDropList($col)',
    r'$dropEffect = New-Object System.IO.MemoryStream(, [byte[]](5,0,0,0))',
    r"$dataObj.SetData('Preferred DropEffect', $dropEffect)",
    r'[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true, 10, 50)',
  ].join('; ');
  return ['-NoProfile', '-STA', '-Command', psScript];
}

class FolderPickResult {
  final bool supported;
  final bool failed;
  final String? path;
  final String? error;

  const FolderPickResult({
    required this.supported,
    this.failed = false,
    this.path,
    this.error,
  });
}

/// Helpers asíncronos de integración con navegador y PowerShell STA en Windows.
class WindowsShellHelpers {
  WindowsShellHelpers._();

  static Future<void> launchBrowserDetached(String url) async {
    if (Platform.isWindows) {
      final programFiles =
          Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ??
          r'C:\Program Files (x86)';
      final localAppData = Platform.environment['LocalAppData'] ?? '';

      final chromeCandidates = [
        '$programFiles\\Google\\Chrome\\Application\\chrome.exe',
        '$programFilesX86\\Google\\Chrome\\Application\\chrome.exe',
        if (localAppData.isNotEmpty)
          '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
      ];

      String? chromeBin;
      for (final cand in chromeCandidates) {
        if (await File(cand).exists()) {
          chromeBin = cand;
          break;
        }
      }

      if (chromeBin != null) {
        await Process.start(chromeBin, [url], mode: ProcessStartMode.detached);
        return;
      }

      final edgeCandidates = [
        '$programFilesX86\\Microsoft\\Edge\\Application\\msedge.exe',
        '$programFiles\\Microsoft\\Edge\\Application\\msedge.exe',
      ];
      String? edgeBin;
      for (final cand in edgeCandidates) {
        if (await File(cand).exists()) {
          edgeBin = cand;
          break;
        }
      }

      if (edgeBin != null) {
        await Process.start(edgeBin, [url], mode: ProcessStartMode.detached);
        return;
      }

      await Process.start('cmd.exe', ['/c', 'start', '""', url],
          mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
    }
  }

  static Future<FolderPickResult> pickFolder({
    String? initialPath,
    String? description,
    Future<String?> Function()? onBrowseFolderOverride,
  }) async {
    if (onBrowseFolderOverride != null) {
      return FolderPickResult(
        supported: true,
        path: await onBrowseFolderOverride(),
      );
    }
    if (!Platform.isWindows) {
      return const FolderPickResult(supported: false);
    }
    try {
      final psArgs = buildWindowsFolderPickerPsArgs(
        initialPath: initialPath,
        description: description,
      );
      final proc = await Process.run(
        'powershell',
        psArgs,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 90));
      if (proc.exitCode == 0) {
        final out = proc.stdout.toString().trim();
        final picked = out.isNotEmpty
            ? out.split(RegExp(r'\r?\n')).first.trim()
            : null;
        return FolderPickResult(supported: true, path: picked);
      }
      final err = proc.stderr.toString().trim();
      return FolderPickResult(
        supported: true,
        failed: true,
        error: err.isNotEmpty
            ? err
            : 'No se pudo abrir el selector de carpetas de Windows.',
      );
    } catch (e) {
      return FolderPickResult(
        supported: true,
        failed: true,
        error: 'Error al abrir selector de carpetas: $e',
      );
    }
  }
}
