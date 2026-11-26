import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/providers/google_drive_backup_provider.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/clipboard_helper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';

part 'google_drive/google_drive_restore_dialogs.dart';
part 'google_drive/google_drive_oauth_and_direct_restore.dart';
part 'google_drive/google_drive_actions_and_unlinked.dart';
part 'google_drive/google_drive_connected_and_backups.dart';

/// Componente modular y hoja de gestión para Copias de Seguridad en Google Drive
class GoogleDriveBackupSheet extends StatefulWidget {
  final IGoogleDriveBackupService? backupService;
  final bool isDark;
  final bool showHeader;
  final Key? statusCardKey;

  const GoogleDriveBackupSheet({
    super.key,
    this.backupService,
    this.isDark = false,
    this.showHeader = true,
    this.statusCardKey,
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
  }) => _GoogleDriveRestoreDialogsHelper.showOnboardingInvitation(
    context,
    backupService: backupService,
  );

  static Future<void> showGuidedWhatsAppRestoreModal(
    BuildContext context, {
    required GoogleDriveBackupProvider driveProvider,
    required List<GoogleDriveBackupMetadata> allBackups,
    required String userEmail,
    bool isDark = false,
    Future<void> Function()? onRestoreSuccess,
  }) => _GoogleDriveRestoreDialogsHelper.showGuidedWhatsAppRestoreModal(
    context,
    driveProvider: driveProvider,
    allBackups: allBackups,
    userEmail: userEmail,
    isDark: isDark,
    onRestoreSuccess: onRestoreSuccess,
  );

  static Future<void> executeDirectRestore(
    BuildContext context, {
    required GoogleDriveBackupProvider driveProvider,
    required GoogleDriveBackupMetadata backup,
    Future<void> Function()? onRestoreSuccess,
  }) => _GoogleDriveOAuthHelper.executeDirectRestore(
    context,
    driveProvider: driveProvider,
    backup: backup,
    onRestoreSuccess: onRestoreSuccess,
  );

  static Future<void> showOAuthErrorDialog(
    BuildContext context,
    dynamic error, {
    bool isDark = false,
    String? passedHardwareId,
  }) => _GoogleDriveOAuthHelper.showOAuthErrorDialog(
    context,
    error,
    isDark: isDark,
    passedHardwareId: passedHardwareId,
  );

  @override
  State<GoogleDriveBackupSheet> createState() => _GoogleDriveBackupSheetState();
}

abstract class _GoogleDriveBackupSheetStateBase extends State<GoogleDriveBackupSheet>
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


  String _formatDateTime(DateTime dt);
  Future<void> _handleSignOut(GoogleDriveBackupProvider prov);
  Future<void> _handleBackupNow(GoogleDriveBackupProvider prov);
  Future<void> _confirmAndRestore(GoogleDriveBackupProvider prov, GoogleDriveBackupMetadata backup);
  Future<void> _updateFrequency(GoogleDriveBackupProvider prov, BackupFrequency freq);
  Future<void> _toggleWifiOnly(GoogleDriveBackupProvider prov, bool val);
  List<Widget> _buildDriveUnlinkedSection({
    required GoogleDriveBackupProvider prov,
    required bool isDark,
    required Color cardColor,
  });
  List<Widget> _buildDriveConnectedSection({
    required GoogleDriveBackupProvider prov,
    required GoogleDriveUser user,
    required DriveBackupConfig config,
    required List<GoogleDriveBackupMetadata> backups,
    required bool isBackingUp,
    required bool isRestoring,
    required bool isDark,
    required Color cardColor,
  });
  List<Widget> _buildDriveBackupsListSection({
    required GoogleDriveBackupProvider prov,
    required List<GoogleDriveBackupMetadata> backups,
    required bool isBackingUp,
    required bool isRestoring,
    required bool isDark,
    required Color cardColor,
  });

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
            ..._buildDriveUnlinkedSection(
              prov: prov,
              isDark: isDark,
              cardColor: cardColor,
            ),
          ],

          // Estado: Vinculado
          if (user != null) ...[
            ..._buildDriveConnectedSection(
              prov: prov,
              user: user,
              config: config,
              backups: backups,
              isBackingUp: isBackingUp,
              isRestoring: isRestoring,
              isDark: isDark,
              cardColor: cardColor,
            ),
            ..._buildDriveBackupsListSection(
              prov: prov,
              backups: backups,
              isBackingUp: isBackingUp,
              isRestoring: isRestoring,
              isDark: isDark,
              cardColor: cardColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleDriveBackupSheetState extends _GoogleDriveBackupSheetStateBase
    with
        _GoogleDriveActionsMixin,
        _GoogleDriveConnectedAndBackupsMixin {}
