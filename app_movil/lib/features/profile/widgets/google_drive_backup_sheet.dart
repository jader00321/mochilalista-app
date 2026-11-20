import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

/// Componente modular y hoja de gestión para Copias de Seguridad en Google Drive
class GoogleDriveBackupSheet extends StatefulWidget {
  final IGoogleDriveBackupService? backupService;
  final bool isDark;
  final bool showHeader;

  const GoogleDriveBackupSheet({
    super.key,
    this.backupService,
    this.isDark = false,
    this.showHeader = true,
  });

  /// Abre la hoja modal de respaldo en Google Drive
  static Future<void> show(
    BuildContext context, {
    IGoogleDriveBackupService? backupService,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (sheetCtx, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: GoogleDriveBackupSheet(
              backupService: backupService,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }

  /// Diálogo opcional de bienvenida en instalación limpia (Onboarding)
  static Future<bool> showOnboardingInvitation(
    BuildContext context, {
    IGoogleDriveBackupService? backupService,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_download_rounded, color: Colors.blue, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Restaurar Respaldo",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¿Ya utilizabas MochilaLista en otro teléfono y guardaste copias en tu cuenta de Google Drive?",
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              "Puedes restaurar tu catálogo, clientes y ventas anteriores ahora mismo, o empezar desde cero.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Omitir por ahora"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_sync_rounded, size: 18),
            label: const Text("Restaurar desde Google Drive"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  State<GoogleDriveBackupSheet> createState() => _GoogleDriveBackupSheetState();
}

class _GoogleDriveBackupSheetState extends State<GoogleDriveBackupSheet> {
  late IGoogleDriveBackupService _service;
  GoogleDriveUser? _user;
  DriveBackupConfig _config = const DriveBackupConfig(isEnabled: false);
  List<GoogleDriveBackupMetadata> _backups = [];

  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _service = widget.backupService ?? GoogleDriveBackupService.instance;
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    try {
      final user = await _service.getCurrentUser();
      final config = await _service.getConfig();
      List<GoogleDriveBackupMetadata> backups = [];

      if (user != null) {
        backups = await _service.listBackups();
      }

      if (mounted) {
        setState(() {
          _user = user;
          _config = config;
          _backups = backups;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn() async {
    final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
    setState(() => _isLoading = true);
    try {
      final user = await _service.signIn();
      if (user != null) {
        final config = await _service.getConfig();
        final backups = await _service.listBackups();
        if (mounted) {
          setState(() {
            _user = user;
            _config = config;
            _backups = backups;
            _isLoading = false;
          });
          CustomSnackBar.show(
            context,
            message: "Conectado a Google Drive como ${user.email}",
          );

          // Conexión silenciosa y no bloqueante del Marcador de Trial (Fase 2)
          if (licenseHardwareId != null && licenseHardwareId.isNotEmpty) {
            unawaited(_service.registerTrialMarker(licenseHardwareId));
          }

          // Si se encontraron copias previas en la nube, desplegar modal guiado estilo WhatsApp
          if (backups.isNotEmpty) {
            await _showGuidedWhatsAppRestoreModal(backups, user.email);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showOAuthErrorDialog(e, passedHardwareId: licenseHardwareId);
      }
    }
  }

  Future<void> _showGuidedWhatsAppRestoreModal(
    List<GoogleDriveBackupMetadata> allBackups,
    String userEmail,
  ) async {
    final isDark = widget.isDark;
    final recentBackups = allBackups.take(5).toList();
    if (recentBackups.isEmpty) return;

    int selectedIndex = 0;

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final bottomSafety = math.max(
              MediaQuery.viewInsetsOf(modalCtx).bottom,
              math.max(
                MediaQuery.viewPaddingOf(modalCtx).bottom,
                MediaQuery.paddingOf(modalCtx).bottom,
              ),
            ) + 12.0;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_download_rounded,
                            color: Color(0xFF25D366),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Copias de seguridad encontradas",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Cuenta: $userEmail",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Se encontraron respaldos de tu negocio en Google Drive. Selecciona la copia que deseas recuperar en este dispositivo.",
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: recentBackups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final backup = recentBackups[index];
                        final isSelected = (index == selectedIndex);
                        final isNewest = (index == 0);

                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF232E27) : const Color(0xFFE8F8EE))
                                  : (isDark ? const Color(0xFF14141C) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF25D366)
                                    : (isDark ? Colors.white12 : Colors.black12),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: isSelected
                                      ? const Color(0xFF25D366)
                                      : (isDark ? Colors.grey[500] : Colors.grey[400]),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              backup.formattedDate,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isNewest)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 7,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: const Color(0xFF25D366).withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: const Text(
                                                "Más reciente",
                                                style: TextStyle(
                                                  color: Color(0xFF25D366),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.verified_user_rounded,
                                            size: 13,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              "Respaldo integral multi-perfil",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            backup.formattedSize,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'monospace',
                                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSafety),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.restore_rounded, size: 20),
                            label: const Text(
                              "Restaurar copia seleccionada",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              final chosen = recentBackups[selectedIndex];
                              Navigator.pop(sheetCtx);
                              _executeDirectRestore(chosen);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(
                            "Ahora no",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeDirectRestore(GoogleDriveBackupMetadata backup) async {
    setState(() => _isRestoring = true);
    try {
      final res = await _service.downloadAndRestoreBackup(backup.fileId);
      if (!mounted) return;
      setState(() => _isRestoring = false);

      if (res.isSuccess) {
        if (!mounted) return;
        try {
          final authProv = Provider.of<AuthProvider?>(context, listen: false);
          await authProv?.checkInitialState();
        } catch (_) {}
        if (!mounted) return;
        try {
          final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
          await licenseProv?.checkLicense();
        } catch (_) {}
        if (!mounted) return;
        CustomSnackBar.show(
          context,
          message: "¡Copia de seguridad restaurada con éxito! Todos tus perfiles y negocios están listos.",
          isError: false,
        );
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: res.message,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        CustomSnackBar.show(
          context,
          message: "Error restaurando copia: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _showOAuthErrorDialog(dynamic error, {String? passedHardwareId}) async {
    final isDark = widget.isDark;
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

    if (!mounted) return;

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
                            Clipboard.setData(ClipboardData(text: technicalReport));
                            Navigator.pop(ctx);
                            CustomSnackBar.show(
                              context,
                              message: "Datos técnicos copiados al portapapeles para soporte.",
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

  Future<void> _handleSignOut() async {
    await _service.signOut();
    if (mounted) {
      setState(() {
        _user = null;
        _backups = [];
      });
      CustomSnackBar.show(
        context,
        message: "Cuenta de Google desvinculada.",
      );
    }
  }

  Future<void> _handleBackupNow() async {
    if (_user == null) return;
    setState(() => _isBackingUp = true);

    try {
      final meta = await _service.uploadEncryptedBackup();
      final updatedBackups = await _service.listBackups();
      final updatedConfig = await _service.getConfig();

      if (mounted) {
        setState(() {
          _backups = updatedBackups;
          _config = updatedConfig;
          _isBackingUp = false;
        });

        CustomSnackBar.show(
          context,
          message: "¡Copia de seguridad guardada en Google Drive! (${meta?.formattedSize ?? ''})",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBackingUp = false);
        CustomSnackBar.show(
          context,
          message: "No se pudo completar el respaldo: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmAndRestore(GoogleDriveBackupMetadata backup) async {
    final isDark = widget.isDark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "¿Restaurar Respaldo?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Se sobreescribirán los datos actuales de la aplicación con la copia fechada:",
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${backup.formattedDate} (${backup.formattedSize})",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "¡Se creará automáticamente una copia de seguridad local de seguridad antes de proceder!",
              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Restaurar Ahora"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isRestoring = true);

    try {
      final res = await _service.downloadAndRestoreBackup(backup.fileId);

      if (!mounted) return;
      setState(() => _isRestoring = false);

      if (res.isSuccess) {
        // Refrescar Providers activos
        if (mounted) {
          try {
            final authProv = Provider.of<AuthProvider?>(context, listen: false);
            await authProv?.checkInitialState();
          } catch (_) {}
        }

        if (mounted) {
          try {
            final licenseProv = Provider.of<LicenseProvider?>(context, listen: false);
            await licenseProv?.checkLicense();
          } catch (_) {}
        }

        if (mounted) {
          CustomSnackBar.show(
            context,
            message: res.message,
            isError: res.requiresLicenseMigration,
          );
        }
      } else {
        if (mounted) {
          CustomSnackBar.show(
            context,
            message: res.message,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        CustomSnackBar.show(
          context,
          message: "Error restaurando respaldo: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _updateFrequency(BackupFrequency freq) async {
    final updated = _config.copyWith(frequency: freq);
    await _service.saveConfig(updated);
    setState(() => _config = updated);
  }

  Future<void> _toggleWifiOnly(bool val) async {
    final updated = _config.copyWith(wifiOnly: val);
    await _service.saveConfig(updated);
    setState(() => _config = updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardColor = isDark ? const Color(0xFF232332) : Colors.white;

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encabezado de la Sección (Opcional si se incrusta en pantalla con su propia cabecera)
          if (widget.showHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_queue_rounded, color: Colors.blue, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            "Copia de Seguridad en Google Drive",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "Nube",
                              style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Respaldo automático con cifrado AES-256-GCM atado a tu cuenta de Google.",
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          // Estado: No Vinculado
          if (_user == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.blue.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_rounded, size: 20, color: Colors.teal),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Tus copias viajan cifradas con tu cuenta de Google. Si compras un teléfono nuevo o pierdes este equipo, bastará con iniciar sesión para recuperar el 100% de tus ventas, clientes y catálogo.",
                          style: TextStyle(fontSize: 13, height: 1.35, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tarjeta destacada de cobertura total multi-perfil
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Respaldo integral: guarda toda tu base de datos (todos tus perfiles, negocios, ventas, productos y clientes).",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Lista de Vista Previa de Funcionalidades al Conectar
                  Text(
                    "Al vincular tu cuenta podrás configurar:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPreviewFeatureItem(
                    icon: Icons.sync_rounded,
                    title: "Respaldo Manual o Automático",
                    description: "Programa copias automáticas con frecuencia Diario (24h), Semanal (7 días) o Mensual (30 días).",
                    isDark: isDark,
                  ),
                  _buildPreviewFeatureItem(
                    icon: Icons.wifi_rounded,
                    title: "Ahorro de Datos con Solo Wi-Fi",
                    description: "Restringe la subida automática únicamente a redes inalámbricas seguras.",
                    isDark: isDark,
                  ),
                  _buildPreviewFeatureItem(
                    icon: Icons.history_rounded,
                    title: "Bóveda de Últimas 5 Copias",
                    description: "Historial de las últimas 5 versiones fechadas con restauración en 1 toque.",
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.account_circle_outlined, size: 20),
                    label: const Text("Vincular Cuenta de Google"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _handleSignIn,
                  ),
                ],
              ),
            ),
          ],

          // Estado: Vinculado
          if (_user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.blue.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de Usuario Conectado
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue.withValues(alpha: 0.2),
                        backgroundImage: _user!.photoUrl != null ? NetworkImage(_user!.photoUrl!) : null,
                        child: _user!.photoUrl == null
                            ? const Icon(Icons.person, color: Colors.blue, size: 22)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user!.displayName ?? "Cuenta Conectada",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _user!.email,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _handleSignOut,
                        child: const Text("Desvincular", style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Botón Respaldar Ahora e Indicador
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload_rounded, size: 20),
                          label: Text(_isBackingUp ? "Subiendo..." : "Respaldar Ahora"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isBackingUp || _isRestoring ? null : _handleBackupNow,
                        ),
                      ),
                    ],
                  ),
                  if (_config.lastBackupAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Última copia: ${DateFormat('dd/MM/yyyy • hh:mm a').format(_config.lastBackupAt!.toLocal())}",
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Modo de Operación: Automático vs Manual
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Respaldo Automático en Google Drive",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _config.isEnabled
                          ? "Sincronización en segundo plano con tu cuenta de Google."
                          : "Modo manual (se respaldará únicamente al presionar 'Respaldar Ahora').",
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: _config.isEnabled,
                    activeThumbColor: Colors.blue,
                    activeTrackColor: Colors.blue.withValues(alpha: 0.4),
                    onChanged: (val) async {
                      final updated = _config.copyWith(isEnabled: val);
                      await _service.saveConfig(updated);
                      if (mounted) setState(() => _config = updated);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Selector de Frecuencia (visible solo si automático está activado)
                  if (_config.isEnabled) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Frecuencia de Respaldo Automático",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<BackupFrequency>(
                              value: _config.frequency == BackupFrequency.manual ? BackupFrequency.daily : _config.frequency,
                              isExpanded: true,
                              dropdownColor: cardColor,
                              items: [
                                BackupFrequency.daily,
                                BackupFrequency.weekly,
                                BackupFrequency.monthly,
                              ].map((f) {
                                return DropdownMenuItem(
                                  value: f,
                                  child: Text(f.label, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (f) {
                                if (f != null) _updateFrequency(f);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Interruptor Solo con Wi-Fi
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Solo con Wi-Fi", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text("Ahorra datos móviles al respaldar automáticamente", style: TextStyle(fontSize: 11)),
                    value: _config.wifiOnly,
                    activeThumbColor: Colors.blue,
                    activeTrackColor: Colors.blue.withValues(alpha: 0.4),
                    onChanged: _toggleWifiOnly,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lista Cronológica de hasta 5 Copias Fechadas
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Copias en Google Drive (Últimas 5)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  "${_backups.length}/5 copias",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_backups.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "No hay copias de seguridad en Google Drive aún.\nPresiona 'Respaldar Ahora' para generar la primera.",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._backups.asMap().entries.map((entry) {
                final index = entry.key;
                final backup = entry.value;
                final isLatest = (index == 0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLatest
                          ? Colors.green.withValues(alpha: 0.4)
                          : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isLatest
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.insert_drive_file_outlined,
                          size: 18,
                          color: isLatest ? Colors.green : Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              backup.formattedDate,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  backup.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                if (isLatest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "Más reciente",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isRestoring ? null : () => _confirmAndRestore(backup),
                        child: const Text("Restaurar", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
