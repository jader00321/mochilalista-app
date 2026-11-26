part of '../google_drive_backup_sheet.dart';

class _GoogleDriveOAuthHelper {
  static Future<void> executeDirectRestore(
    BuildContext context, {
    required GoogleDriveBackupProvider driveProvider,
    required GoogleDriveBackupMetadata backup,
    Future<void> Function()? onRestoreSuccess,
  }) async {
    try {
      final res = await driveProvider.restoreBackup(backup);
      if (!context.mounted) return;

      if (res.isSuccess) {
        try {
          await InteractiveTourService.suppressAutomaticToursAfterRestore();
        } catch (_) {}
        if (!context.mounted) return;
        try {
          final authProv = Provider.of<AuthProvider?>(context, listen: false);
          await authProv?.checkInitialState();
        } catch (_) {}
        if (!context.mounted) return;
        try {
          final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
          await licenseProv?.checkLicense();
        } catch (_) {}
        if (onRestoreSuccess != null) {
          await onRestoreSuccess();
        }
        if (!context.mounted) return;
        CustomSnackBar.show(
          context,
          message: "¡Copia de seguridad restaurada con éxito! Todos tus perfiles y negocios están listos.",
          isError: false,
        );
      } else {
        CustomSnackBar.show(
          context,
          message: res.message,
          isError: true,
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(
          context,
          message: "Error restaurando copia: $e",
          isError: true,
        );
      }
    }
  }

  /// Diálogo humano para errores OAuth con opción de ver reporte técnico
  static Future<void> showOAuthErrorDialog(
    BuildContext context,
    dynamic error, {
    bool isDark = false,
    String? passedHardwareId,
  }) async {
    final hardwareId = passedHardwareId ?? await DeviceFingerprint.generate();
    final sha1 = await DeviceFingerprint.getAppSigningSha1();
    final appVersion = OwnerLegalIdentity.currentAppVersionWithBuild;
    const packageName = 'com.mochilalista.app';
    final errorStr = error.toString().replaceFirst('Exception: ', '');

    final technicalReport = """
=== REPORTE TÉCNICO GOOGLE DRIVE / OAUTH ===
Aplicación: ${OwnerLegalIdentity.appCommercialName}
Paquete: $packageName
Versión: $appVersion
Hardware ID: $hardwareId
Huella SHA-1 Activa: ${sha1 ?? 'No disponible (requiere Android físico)'}
Detalle del Error: $errorStr
Fecha: ${DateTime.now().toIso8601String()}
============================================
""".trim();

    if (!context.mounted) return;

    bool isTechnicalExpanded = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "No se pudo conectar con Google Drive",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "En este momento no fue posible vincular tu cuenta de Google. Verifica que tengas conexión a internet estable e intenta nuevamente.\n\nMientras tanto, puedes seguir respaldando tu información de forma segura usando la Copia Local en la memoria de tu teléfono.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    setDialogState(() {
                      isTechnicalExpanded = !isTechnicalExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Ver información técnica para soporte",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.blue[300] : Colors.blue[700],
                            ),
                          ),
                        ),
                        Icon(
                          isTechnicalExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isTechnicalExpanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF12121A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Datos Técnicos para Soporte:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.blue),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "• Paquete: $packageName\n"
                          "• Versión: $appVersion\n"
                          "• Hardware ID: $hardwareId\n"
                          "• Huella SHA-1: ${sha1 ?? 'No disponible'}\n"
                          "• Error: $errorStr",
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            fontFamily: 'monospace',
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text("Copiar Datos de Soporte", style: TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ClipboardHelper.copyWithFeedback(
                              context,
                              technicalReport,
                              feedbackMessage: "Datos técnicos copiados al portapapeles para soporte.",
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text("Entendido", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

}
