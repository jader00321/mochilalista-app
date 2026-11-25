import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:app_movil/core/providers/commercial_catalog_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';
import 'package:app_movil/core/services/sync/client_sync_service.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';

/// Pantalla de Bloqueo Estricto o Espera de Migración.
/// Garantiza SIEMPRE la posibilidad de exportar copias de seguridad (.mlbg)
/// para que el comerciante jamás quede secuestrado de su información histórica.
class LicenseLockedScreen extends StatefulWidget {
  final bool isPendingMigration;

  const LicenseLockedScreen({super.key, this.isPendingMigration = false});

  @override
  State<LicenseLockedScreen> createState() => _LicenseLockedScreenState();
}

class _LicenseLockedScreenState extends State<LicenseLockedScreen> {
  bool _isExporting = false;
  bool _isSharingMlsync = false;
  bool _includeLicenseRef = true;

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
    } catch (e, stack) {
      debugPrint('DEBUG EXCEPTION EN _shareMigrationMlsync: $e\n$stack');
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

  Future<String?> _buildMigrationSyncToken(
    String fingerprint,
    String? boundHw, {
    required bool isMigration,
  }) async {
    try {
      LicenseProvider? licenseProv;
      try {
        licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
      } catch (_) {}
      GoogleDriveBackupProvider? driveProv;
      try {
        driveProv = Provider.of<GoogleDriveBackupProvider?>(
          context,
          listen: false,
        );
      } catch (_) {}
      final syncService = ClientSyncService();
      final snapshot = await syncService.buildCurrentSnapshot(
        licenseProv: licenseProv,
        driveProv: driveProv,
        overrideHw: fingerprint,
        overrideBhw: boundHw,
        overrideSt: isMigration
            ? 'PENDIENTE_MIGRACION'
            : (licenseProv?.license?.estadoActual ?? 'ACTIVA'),
      );
      return syncService.generateSyncToken(snapshot);
    } catch (_) {
      return null;
    }
  }

  EffectiveCommercialConfig _resolveEffectiveCommercialConfig({
    bool listen = false,
  }) {
    try {
      final prov = Provider.of<CommercialCatalogProvider?>(
        context,
        listen: listen,
      );
      if (prov != null) return prov.effectiveConfig;
    } catch (_) {}
    return EffectiveCommercialConfig.defaults();
  }

  Future<void> _launchWhatsApp(
    String fingerprint, {
    required bool isMigration,
    String? boundHw,
  }) async {
    final effectiveConfig = _resolveEffectiveCommercialConfig();
    final cleanDigits = effectiveConfig.supportPhone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    String msg;
    if (isMigration) {
      msg =
          "Hola Julio Angello, solicito reactivación por migración de equipo para MochilaLista. Mi nuevo ID es: $fingerprint";
      if (_includeLicenseRef) {
        final token = await _buildMigrationSyncToken(
          fingerprint,
          boundHw,
          isMigration: true,
        );
        if (token != null) {
          msg = ClientSyncService().appendSyncTokenToMessage(msg, token);
        }
      }
    } else {
      msg =
          "Hola Julio Angello, solicito renovar mi suscripción para MochilaLista. Mi ID de equipo es: $fingerprint";
      if (_includeLicenseRef) {
        final token = await _buildMigrationSyncToken(
          fingerprint,
          null,
          isMigration: false,
        );
        if (token != null) {
          msg = ClientSyncService().appendSyncTokenToMessage(msg, token);
        }
      }
    }

    final baseUri = cleanDigits.length >= 8
        ? "https://wa.me/$cleanDigits"
        : effectiveConfig.supportWhatsAppUrl;
    final uri = Uri.parse("$baseUri?text=${Uri.encodeComponent(msg)}");
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "Soporte: ${effectiveConfig.supportPhone}",
            isError: false,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Soporte: ${effectiveConfig.supportPhone}",
          isError: false,
        );
      }
    }
  }

  Future<void> _shareMigrationMlsync(
    String fingerprint,
    String? boundHw,
  ) async {
    if (_isSharingMlsync) return;
    setState(() => _isSharingMlsync = true);
    try {
      LicenseProvider? licenseProv;
      try {
        licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
      } catch (_) {}
      GoogleDriveBackupProvider? driveProv;
      try {
        driveProv = Provider.of<GoogleDriveBackupProvider?>(
          context,
          listen: false,
        );
      } catch (_) {}
      final syncService = ClientSyncService();
      final snapshot = await syncService.buildCurrentSnapshot(
        licenseProv: licenseProv,
        driveProv: driveProv,
        overrideHw: fingerprint,
        overrideBhw: boundHw,
        overrideSt: 'PENDIENTE_MIGRACION',
      );
      final file = await syncService.createMlsyncTempFile(snapshot);
      final shared = await syncService.shareMlsyncFile(
        file,
        hardwareId: fingerprint,
      );
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: shared
              ? "Ficha de migración generada y compartida exitosamente"
              : "Menú de compartir cerrado",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo compartir la ficha de migración: $e",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingMlsync = false);
    }
  }

  Widget _buildLicenseRefSwitch(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _includeLicenseRef
              ? Colors.green.withValues(alpha: 0.35)
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (_includeLicenseRef ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: _includeLicenseRef ? Colors.green[700] : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Incluir datos de mi licencia para atención rápida",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ayuda a verificar tu plan y agilizar tu solicitud",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey("switch_locked_include_license_ref"),
            value: _includeLicenseRef,
            activeThumbColor: Colors.green,
            activeTrackColor: Colors.green.withValues(alpha: 0.3),
            onChanged: (val) => setState(() => _includeLicenseRef = val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final licenseProv = Provider.of<LicenseProvider?>(context);
    final fingerprint = licenseProv?.deviceFingerprint ?? 'ML-DISP';
    final boundHw = licenseProv?.license?.migratedFromDeviceId;

    final isMigration =
        widget.isPendingMigration || (licenseProv?.isPendingMigration ?? false);

    final title = isMigration
        ? "Migración de Dispositivo"
        : "Licencia Concluida";
    final desc = isMigration
        ? "Se ha detectado una base de datos proveniente de otro dispositivo o restaurada en un hardware nuevo. Por protección de tu cuenta, ingresa tu nuevo código de activación autorizado."
        : "Tu periodo de suscripción y días de gracia han culminado. Tus registros comerciales están 100% seguros y respaldados. Renueva tu licencia para continuar registrando ventas.";

    final iconData = isMigration
        ? Icons.phonelink_lock_rounded
        : Icons.lock_clock_rounded;
    final iconColor = isMigration ? Colors.orange : Colors.red;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF14141C)
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
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
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.fingerprint_rounded,
                              size: 22,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "ID de este dispositivo:",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
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
                                Clipboard.setData(
                                  ClipboardData(text: fingerprint),
                                );
                                CustomSnackBar.show(
                                  context,
                                  message: "ID copiado al portapapeles",
                                  isError: false,
                                );
                              },
                            ),
                          ],
                        ),
                        if (isMigration &&
                            boundHw != null &&
                            boundHw.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Divider(height: 1),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.history_toggle_off_rounded,
                                size: 16,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Equipo anterior vinculado: $boundHw",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.orange[300]
                                        : Colors.orange[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Switch amigable para incluir referencia de soporte
                  _buildLicenseRefSwitch(isDark),
                  const SizedBox(height: 14),

                  // Botón 1: WhatsApp (Reactivación por Migración o Renovación)
                  ElevatedButton.icon(
                    key: const ValueKey("btn_locked_whatsapp"),
                    onPressed: () => _launchWhatsApp(
                      fingerprint,
                      isMigration: isMigration,
                      boundHw: boundHw,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(
                      isMigration
                          ? "Enviar solicitud de migración por WhatsApp"
                          : "Contactar a Soporte por WhatsApp",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Botón 2: Compartir ficha de migración (.mlsync) sólo si es migración
                  if (isMigration) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const ValueKey("btn_locked_share_mlsync"),
                      onPressed: _isSharingMlsync
                          ? null
                          : () => _shareMigrationMlsync(fingerprint, boundHw),
                      icon: _isSharingMlsync
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        "Compartir ficha de migración (.mlsync)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.lightGreen[300]
                            : Colors.green[800],
                        side: BorderSide(
                          color: isDark
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Botón 3: Ingresar Código de Activación
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const LicenseStatusAndActivationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.vpn_key_rounded, size: 18),
                    label: const Text(
                      "Ingresar Código de Activación",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.grey[300]
                          : Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
