part of '../profile_selection_screen.dart';

mixin _ProfileDriveModalsMixin on _ProfileSelectionStateBase {
  @override
  Future<void> _handleDriveSignIn(GoogleDriveBackupProvider driveProv) async {
    if (!await _ensureEulaAccepted()) return;
    if (!mounted) return;

    setState(() {
      _isDriveActionLoading = true;
    });

    try {
      final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
      final user = await driveProv.signIn(licenseHardwareId: licenseHardwareId);
      if (!mounted) return;

      if (user != null) {
        if (driveProv.backups.isNotEmpty) {
          await GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
            context,
            driveProvider: driveProv,
            allBackups: driveProv.backups,
            userEmail: user.email,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onRestoreSuccess: () async {
              await _loadProfileOrder();
              await _loadProfileMetadata();
              if (mounted) setState(() {});
            },
          );
        } else {
          await DriveActionFeedbackModal.show(
            context: context,
            actionType: DriveActionType.signIn,
            task: (updateStep) async {
              updateStep("Cuenta vinculada (${user.email})");
            },
            customSuccessTitle: "¡Cuenta vinculada con éxito!",
            customSuccessSubtitle: "Cuenta vinculada (${user.email}). No se encontraron copias previas.",
            onDone: () {
              if (mounted) setState(() {});
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final licenseHardwareId = Provider.of<LicenseProvider?>(context, listen: false)?.deviceFingerprint;
        await GoogleDriveBackupSheet.showOAuthErrorDialog(
          context,
          e,
          isDark: Theme.of(context).brightness == Brightness.dark,
          passedHardwareId: licenseHardwareId,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDriveActionLoading = false;
        });
      }
    }
  }

  @override
  void _openDriveQuickOptionsModal(
    GoogleDriveBackupProvider driveProv,
    bool isDark,
    List<UserModel> profiles,
  ) {
    final bottomSafety = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    ) + 16.0;

    final health = GoogleDriveBackupProvider.computeHealthInfo(
      backups: driveProv.backups,
      isDark: isDark,
    );

    // Fecha exacta de la última copia
    String lastBackupText;
    if (driveProv.backups.isNotEmpty) {
      final latest = driveProv.backups.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );
      lastBackupText = "Última copia: ${latest.formattedDate}";
    } else {
      lastBackupText = "Sin copias en la nube todavía";
    }

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSafety),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Cabecera Enriquecida
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: health.color.withValues(alpha: isDark ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: health.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Google Drive",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: health.color.withValues(alpha: isDark ? 0.25 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  health.label,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: health.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driveProv.currentUser?.email ?? "",
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastBackupText,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Opción 1: Ver y Restaurar Copias
                _buildQuickActionCard(
                  index: 0,
                  isDark: isDark,
                  icon: Icons.history_rounded,
                  accentColor: const Color(0xFF0284C7),
                  title: "Ver y Restaurar Copias de la Nube",
                  subtitle: driveProv.backups.isEmpty
                      ? "Aún no tienes copias en la nube"
                      : (driveProv.backups.length == 1
                          ? "Explora tu copia disponible"
                          : "Explora las ${driveProv.backups.length} copias disponibles"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (driveProv.backups.isEmpty) {
                      CustomSnackBar.show(
                        context,
                        message: "No hay copias de seguridad en Google Drive aún.",
                      );
                    } else {
                      GoogleDriveBackupSheet.showGuidedWhatsAppRestoreModal(
                        context,
                        driveProvider: driveProv,
                        allBackups: driveProv.backups,
                        userEmail: driveProv.currentUser?.email ?? "",
                        isDark: isDark,
                        onRestoreSuccess: () async {
                          await _loadProfileOrder();
                          await _loadProfileMetadata();
                          if (mounted) setState(() {});
                        },
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Opción 2: Respaldar Ahora (Pluralización gramatical estricta)
                _buildQuickActionCard(
                  index: 1,
                  isDark: isDark,
                  icon: Icons.cloud_upload_rounded,
                  accentColor: const Color(0xFF10B981),
                  title: "Respaldar Ahora en Google Drive",
                  subtitle: profiles.isEmpty
                      ? "Crea primero un negocio para respaldar"
                      : (profiles.length == 1
                          ? "Genera una copia inmediata de tu negocio"
                          : "Genera una copia inmediata de tus ${profiles.length} negocios"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (profiles.isEmpty) {
                      CustomSnackBar.show(
                        context,
                        message: "Crea al menos un negocio antes de realizar un respaldo.",
                        isError: true,
                      );
                    } else {
                      _executeDriveBackupNow(driveProv);
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Opción 3: Desvincular Cuenta
                _buildQuickActionCard(
                  index: 2,
                  isDark: isDark,
                  icon: Icons.link_off_rounded,
                  accentColor: const Color(0xFFEF4444),
                  title: "Desvincular Cuenta de Google",
                  subtitle: "Tus copias en la nube se mantendrán intactas",
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmAndSignOutDrive(driveProv, isDark);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required int index,
    required bool isDark,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 70)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Material(
        color: isDark
            ? (isDestructive ? accentColor.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04))
            : (isDestructive ? accentColor.withValues(alpha: 0.05) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDestructive
                    ? accentColor.withValues(alpha: isDark ? 0.3 : 0.25)
                    : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDestructive
                              ? accentColor
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSignOutDrive(
    GoogleDriveBackupProvider driveProv,
    bool isDark,
  ) async {
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
              child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "¿Desvincular Google Drive?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          "Tus respaldos en la nube se mantendrán a salvo en tu cuenta de Google, pero la sincronización automática en este celular se detendrá.",
          style: TextStyle(fontSize: 13, height: 1.4),
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
            child: const Text("Desvincular"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DriveActionFeedbackModal.show(
        context: context,
        actionType: DriveActionType.signOut,
        task: (updateStep) async {
          updateStep("Desvinculando cuenta de Google...");
          await driveProv.signOut();
        },
        onDone: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  Future<void> _executeDriveBackupNow(GoogleDriveBackupProvider driveProv) async {
    GoogleDriveBackupMetadata? resultMeta;

    await DriveActionFeedbackModal.show(
      context: context,
      actionType: DriveActionType.backup,
      task: (updateStep) async {
        updateStep("Preparando y cifrando datos del negocio...");
        await Future.delayed(const Duration(milliseconds: 250));
        updateStep("Subiendo copia segura a Google Drive...");
        resultMeta = await driveProv.performBackupNow();
      },
      getResultMetadata: () => resultMeta,
      getUpdatedBackupsCount: () => driveProv.backups.length,
      onDone: () {
        if (mounted) setState(() {});
      },
      onRetry: () => _executeDriveBackupNow(driveProv),
    );
  }
}
