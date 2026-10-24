import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

/// 🏆 MODAL ANIMADO DE DESCARGA CON FEEDBACK HÁPTICO Y APERTURA DIRECTA
/// Provee una experiencia visual ejecutiva al descargar archivos (imágenes o reportes PDF):
/// 1. Estado de carga fluido con micro-animaciones.
/// 2. Transición animada a Checkmark verde con vibración háptica.
/// 3. Confirmación de ruta en Descargas y botón de acción inmediata "Abrir Archivo".
class DownloadFeedbackModal extends StatefulWidget {
  final String title;
  final String loadingMessage;
  final Future<File> Function() downloadTask;
  final VoidCallback? onSuccess;

  const DownloadFeedbackModal({
    super.key,
    required this.title,
    required this.loadingMessage,
    required this.downloadTask,
    this.onSuccess,
  });

  /// Método estático para invocar el modal con 1 sola línea de código
  static Future<File?> show(
    BuildContext context, {
    required String title,
    required String loadingMessage,
    required Future<File> Function() downloadTask,
    VoidCallback? onSuccess,
  }) {
    return showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DownloadFeedbackModal(
        title: title,
        loadingMessage: loadingMessage,
        downloadTask: downloadTask,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<DownloadFeedbackModal> createState() => _DownloadFeedbackModalState();
}

class _DownloadFeedbackModalState extends State<DownloadFeedbackModal>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  File? _savedFile;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.elasticOut,
    );
    _executeTask();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeTask() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = await widget.downloadTask();
      if (!mounted) return;

      // Disparo de feedback háptico táctil en dispositivo físico
      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {}

      setState(() {
        _isLoading = false;
        _savedFile = file;
      });

      _animCtrl.forward(from: 0.0);
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _openFile() async {
    if (_savedFile == null) return;
    try {
      final result = await OpenFilex.open(_savedFile!.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El archivo se guardó correctamente en Descargas: ${_savedFile!.path}',
            ),
            backgroundColor: Colors.blueGrey[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir automáticamente: $e'),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E28) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ESTADO 1: CARGANDO
            if (_isLoading) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.tealAccent : Colors.teal.shade700,
                      ),
                    ),
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 26,
                      color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.loadingMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ESTADO 2: ÉXITO
            if (!_isLoading && _savedFile != null) ...[
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.green.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.greenAccent : Colors.green.shade600,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 38,
                    color: isDark ? Colors.greenAccent : Colors.green.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Descarga Exitosa!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.greenAccent : Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _savedFile!.path.endsWith('.pdf')
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      size: 22,
                      color: _savedFile!.path.endsWith('.pdf')
                          ? Colors.redAccent
                          : Colors.blueAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _savedFile!.path.split(Platform.pathSeparator).last,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_special_rounded,
                    size: 15,
                    color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Guardado en la carpeta Descargas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(_savedFile),
                      child: Text(
                        'Cerrar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? Colors.blue.shade700 : Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _openFile,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text(
                        'Abrir Archivo',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ESTADO 3: ERROR
            if (!_isLoading && _errorMessage != null) ...[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No se pudo completar la descarga',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _executeTask,
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
