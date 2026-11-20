import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

/// Pantalla de Bloqueo Estricto o Espera de Migración.
/// Garantiza SIEMPRE la posibilidad de exportar copias de seguridad (.mlbg)
/// para que el comerciante jamás quede secuestrado de su información histórica.
class LicenseLockedScreen extends StatefulWidget {
  final bool isPendingMigration;

  const LicenseLockedScreen({
    super.key,
    this.isPendingMigration = false,
  });

  @override
  State<LicenseLockedScreen> createState() => _LicenseLockedScreenState();
}

class _LicenseLockedScreenState extends State<LicenseLockedScreen> {
  bool _isExporting = false;

  Future<void> _exportBackup() async {
    setState(() => _isExporting = true);
    try {
      final success = await BackupManager.exportToDownloads();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: success
              ? "Copia exportada exitosamente en Descargas"
              : "No se pudo completar la exportación",
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al exportar respaldo: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _launchWhatsApp(String fingerprint) async {
    final cleanDigits = OwnerLegalIdentity.supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final msg = widget.isPendingMigration
        ? "Hola Julio Angello, solicito reactivación por migración de equipo para MochilaLista. Mi nuevo ID es: $fingerprint"
        : "Hola Julio Angello, solicito renovar mi suscripción para MochilaLista. Mi ID de equipo es: $fingerprint";
    final baseUri = cleanDigits.length >= 8
        ? "https://wa.me/$cleanDigits"
        : OwnerLegalIdentity.supportWhatsAppUrl;
    final uri = Uri.parse("$baseUri?text=${Uri.encodeComponent(msg)}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "Soporte: ${OwnerLegalIdentity.supportPhone}",
            isError: false,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Soporte: ${OwnerLegalIdentity.supportPhone}",
          isError: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final fingerprint = licenseProv?.deviceFingerprint ?? 'ML-DISP';

    final isMigration = widget.isPendingMigration || (licenseProv?.isPendingMigration ?? false);

    final title = isMigration ? "Migración de Dispositivo" : "Licencia Concluida";
    final desc = isMigration
        ? "Se ha detectado una base de datos proveniente de otro dispositivo o restaurada en un hardware nuevo. Por protección de tu cuenta, ingresa tu nuevo código de activación autorizado."
        : "Tu periodo de suscripción y días de gracia han culminado. Tus registros comerciales están 100% seguros y respaldados. Renueva tu licencia para continuar registrando ventas.";

    final iconData = isMigration ? Icons.phonelink_lock_rounded : Icons.lock_clock_rounded;
    final iconColor = isMigration ? Colors.orange : Colors.red;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ícono de bloqueo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Icon(iconData, size: 54, color: iconColor),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Descripción explicativa
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Caja de Hardware ID
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 22, color: Colors.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ID de este dispositivo:",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              Text(
                                fingerprint,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: "Copiar ID",
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: fingerprint));
                            CustomSnackBar.show(context, message: "ID copiado al portapapeles", isError: false);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón 1: Contactar a Julio Angello por WhatsApp
                  ElevatedButton.icon(
                    onPressed: () => _launchWhatsApp(fingerprint),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text(
                      "Contactar a Soporte por WhatsApp",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Botón 2: Ingresar Código de Activación
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LicenseStatusAndActivationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.vpn_key_rounded, size: 18),
                    label: const Text(
                      "Ingresar Código de Activación",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // REGLA DE ORO DE PRIVACIDAD: Botón SIEMPRE visible para exportar backup
                  Text(
                    "Tus datos te pertenecen. Puedes exportar tu respaldo local en cualquier momento:",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportBackup,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined, size: 18),
                    label: const Text(
                      "Exportar Copia de Seguridad (.mlbg)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
