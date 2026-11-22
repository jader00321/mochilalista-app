import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';

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

  /// Asistente guiado estilo WhatsApp para restaurar una de las últimas 5 copias
  static Future<void> showGuidedWhatsAppRestoreModal(
    BuildContext context, {
    required GoogleDriveBackupProvider driveProvider,
    required List<GoogleDriveBackupMetadata> allBackups,
    required String userEmail,
    bool isDark = false,
    Future<void> Function()? onRestoreSuccess,
  }) async {
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
                                      Text(
                                        backup.formattedDate,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 2,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (isNewest)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 1.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: const Color(0xFF25D366).withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: const Text(
                                                "Más reciente",
                                                style: TextStyle(
                                                  color: Color(0xFF25D366),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            backup.formattedSize,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: 'monospace',
                                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            "Respaldo integral multi-perfil",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              final chosen = recentBackups[selectedIndex];
                              Navigator.pop(sheetCtx);
                              executeDirectRestore(
                                context,
                                driveProvider: driveProvider,
                                backup: chosen,
                                onRestoreSuccess: onRestoreSuccess,
                              );
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

  /// Ejecución directa y reactiva de restauración con actualización de providers
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

  @override
  State<GoogleDriveBackupSheet> createState() => _GoogleDriveBackupSheetState();
}

class _GoogleDriveBackupSheetState extends State<GoogleDriveBackupSheet>
    with AutomaticKeepAliveClientMixin<GoogleDriveBackupSheet> {
  GoogleDriveBackupProvider? _localFallbackProvider;

  @override
  bool get wantKeepAlive => true;

  GoogleDriveBackupProvider _resolveProvider(BuildContext context) {
    if (widget.backupService != null) {
      if (_localFallbackProvider == null || _localFallbackProvider!.service != widget.backupService) {
        _localFallbackProvider?.removeListener(_onLocalProviderChanged);
        _localFallbackProvider?.dispose();
        _localFallbackProvider = GoogleDriveBackupProvider(service: widget.backupService);
        _localFallbackProvider!.addListener(_onLocalProviderChanged);
        _localFallbackProvider!.initializeFromCache();
      }
      return _localFallbackProvider!;
    }

    final ambient = Provider.of<GoogleDriveBackupProvider?>(context);
    if (ambient != null) {
      return ambient;
    }

    if (_localFallbackProvider == null) {
      _localFallbackProvider = GoogleDriveBackupProvider(service: GoogleDriveBackupService.instance);
      _localFallbackProvider!.addListener(_onLocalProviderChanged);
      _localFallbackProvider!.initializeFromCache();
    }
    return _localFallbackProvider!;
  }

  void _onLocalProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.backupService != null) {
        _resolveProvider(context);
      } else {
        final ambient = Provider.of<GoogleDriveBackupProvider?>(context, listen: false);
        if (ambient != null) {
          if (!ambient.hasInitialized && !ambient.isInitialLoading) {
            ambient.initializeFromCache();
          } else if (ambient.isConnected) {
            ambient.syncBackupsSilently();
          }
        }
      }
    });
  }

  @override
  void didUpdateWidget(GoogleDriveBackupSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backupService != widget.backupService) {
      _localFallbackProvider?.removeListener(_onLocalProviderChanged);
      _localFallbackProvider?.dispose();
      _localFallbackProvider = null;
    }
  }

  @override
  void dispose() {
    _localFallbackProvider?.removeListener(_onLocalProviderChanged);
    _localFallbackProvider?.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn(GoogleDriveBackupProvider prov) async {
    final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
    try {
      final user = await prov.signIn(licenseHardwareId: licenseHardwareId);
      if (user != null && mounted) {
        CustomSnackBar.show(
          context,
          message: "Conectado a Google Drive como ${user.email}",
        );

        // Si se encontraron copias previas en la nube, desplegar modal guiado estilo WhatsApp
        if (prov.backups.isNotEmpty) {
          await _showGuidedWhatsAppRestoreModal(prov, prov.backups, user.email);
        }
      }
    } catch (e) {
      if (mounted) {
        await _showOAuthErrorDialog(e, passedHardwareId: licenseHardwareId);
      }
    }
  }

  Future<void> _showGuidedWhatsAppRestoreModal(
    GoogleDriveBackupProvider prov,
    List<GoogleDriveBackupMetadata> allBackups,
    String userEmail,
  ) =>
      GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
        context,
        driveProvider: prov,
        allBackups: allBackups,
        userEmail: userEmail,
        isDark: widget.isDark,
      );

  Future<void> _showOAuthErrorDialog(dynamic error, {String? passedHardwareId}) =>
      GoogleDriveBackupSheet.showOAuthErrorDialog(
        context,
        error,
        isDark: widget.isDark,
        passedHardwareId: passedHardwareId,
      );

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour24 = local.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final hourStr = hour12.toString().padLeft(2, '0');
    final minuteStr = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hourStr:$minuteStr $period';
  }

  Future<void> _handleSignOut(GoogleDriveBackupProvider prov) async {
    await prov.signOut();
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Cuenta de Google desvinculada.",
      );
    }
  }

  Future<void> _handleBackupNow(GoogleDriveBackupProvider prov) async {
    if (prov.currentUser == null) return;

    try {
      final meta = await prov.performBackupNow();
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "¡Copia de seguridad guardada en Google Drive! (${meta?.formattedSize ?? ''})",
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo completar el respaldo: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmAndRestore(GoogleDriveBackupProvider prov, GoogleDriveBackupMetadata backup) async {
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

    try {
      final res = await prov.restoreBackup(backup);
      if (!mounted) return;

      if (res.isSuccess) {
        try {
          await InteractiveTourService.suppressAutomaticToursAfterRestore();
        } catch (_) {}
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
        CustomSnackBar.show(
          context,
          message: "Error restaurando respaldo: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _updateFrequency(GoogleDriveBackupProvider prov, BackupFrequency freq) async {
    await prov.updateConfig(prov.config.copyWith(frequency: freq));
  }

  Future<void> _toggleWifiOnly(GoogleDriveBackupProvider prov, bool val) async {
    await prov.updateConfig(prov.config.copyWith(wifiOnly: val));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = _resolveProvider(context);
    final isDark = widget.isDark;
    final cardColor = isDark ? const Color(0xFF232332) : Colors.white;

    if (prov.isInitialLoading && !prov.hasInitialized) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final user = prov.currentUser;
    final config = prov.config;
    final backups = prov.backups;
    final isBackingUp = prov.isBackingUp;
    final isRestoring = prov.isRestoring;

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
          if (user == null) ...[
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
                    icon: prov.isSigningIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.account_circle_outlined, size: 20),
                    label: Text(prov.isSigningIn ? "Conectando..." : "Vincular Cuenta de Google"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: prov.isSigningIn ? null : () => _handleSignIn(prov),
                  ),
                ],
              ),
            ),
          ],

          // Estado: Vinculado
          if (user != null) ...[
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
                  // Aviso discreto de error de sincronización no destructivo
                  if (prov.lastError != null && prov.isConnected) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "No se pudieron sincronizar las copias más recientes. Mostrando copia guardada.",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.amber[200] : Colors.amber[900],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => prov.syncBackupsSilently(force: true),
                            child: const Text("Reintentar", style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tarjeta de Usuario Conectado (3 Filas Limpias y Responsivas)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila 1: Avatar + Nombre de Usuario + Botón Desvincular a la derecha
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.blue.withValues(alpha: 0.2),
                            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                            child: user.photoUrl == null
                                ? const Icon(Icons.person, color: Colors.blue, size: 20)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user.displayName ?? "Cuenta Conectada",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: isBackingUp || isRestoring ? null : () => _handleSignOut(prov),
                            child: const Text(
                              "Desvincular",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Fila 2: Correo electrónico al 100% del ancho, sin truncamiento
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.blueGrey[800],
                        ),
                        maxLines: 2,
                        softWrap: true,
                      ),
                      const SizedBox(height: 6),
                      // Fila 3: Semáforo visual de salud de respaldo (Óptimo / Atención / Sin Copias)
                      Builder(
                        builder: (context) {
                          final health = GoogleDriveBackupProvider.computeHealthInfo(
                            backups: backups,
                            isDark: isDark,
                          );
                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: health.backgroundColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(health.icon, size: 13, color: health.color),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        health.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: health.color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (config.lastBackupAt != null)
                                Text(
                                  "Última copia: ${_formatDateTime(config.lastBackupAt!)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Botón Respaldar Ahora
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_upload_rounded, size: 20),
                          label: Text(isBackingUp ? "Subiendo..." : "Respaldar Ahora"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isBackingUp || isRestoring ? null : () => _handleBackupNow(prov),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Modo de Operación: Automático vs Manual
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Respaldo Automático en Google Drive",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      config.isEnabled
                          ? "Sincronización en segundo plano con tu cuenta de Google."
                          : "Modo manual (se respaldará únicamente al presionar 'Respaldar Ahora').",
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: config.isEnabled,
                    activeThumbColor: Colors.blue,
                    activeTrackColor: Colors.blue.withValues(alpha: 0.4),
                    onChanged: (val) async {
                      await prov.updateConfig(config.copyWith(isEnabled: val));
                    },
                  ),
                  const SizedBox(height: 8),

                  // Selector de Frecuencia (visible solo si automático está activado)
                  if (config.isEnabled) ...[
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
                              value: config.frequency == BackupFrequency.manual ? BackupFrequency.daily : config.frequency,
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
                                if (f != null) _updateFrequency(prov, f);
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
                    value: config.wifiOnly,
                    activeThumbColor: Colors.blue,
                    activeTrackColor: Colors.blue.withValues(alpha: 0.4),
                    onChanged: (val) => _toggleWifiOnly(prov, val),
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
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "${backups.length}/5 copias",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 4),
                if (prov.isSyncingSilently)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: "Actualizar lista de copias",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    onPressed: isRestoring || isBackingUp ? null : () => prov.syncBackupsSilently(force: true),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (backups.isEmpty)
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
              ...backups.asMap().entries.map((entry) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila 1: Icono y Fecha Completa al 100% de ancho disponible (Cero truncamiento)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isLatest
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.insert_drive_file_outlined,
                              size: 16,
                              color: isLatest ? Colors.green : Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              backup.formattedDate,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Fila 2: Tamaño, Badge 'Más reciente' y Botón 'Restaurar'
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  backup.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                                if (isLatest)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "Más reciente",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.restore_rounded, size: 14),
                            label: const Text("Restaurar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: isRestoring ? null : () => _confirmAndRestore(prov, backup),
                          ),
                        ],
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
