part of '../profile_selection_screen.dart';

mixin _ProfileBackupSectionMixin on _ProfileSelectionStateBase {
  // ============================================================
  // EJECUCIÓN DE BACKUP: Perfil específico
  // ============================================================

  @override
  Future<void> _executeProfileBackup(UserModel profile) async {
    final negocioId = profile.business?.id;
    final businessName = profile.business?.commercialName ?? "Negocio";

    if (negocioId == null) {
      if (mounted) CustomSnackBar.show(context, message: "Este perfil no tiene un negocio asociado.", isError: true);
      setState(() {
        _screenMode = ProfileScreenMode.normal;
        _selectedProfileId = null;
      });
      return;
    }

    setState(() {
      _screenMode = ProfileScreenMode.normal;
      _selectedProfileId = null;
      _isProcessing = true;
      _processingMessage = "Creando backup de\n$businessName...";
    });

    try {
      bool ok = await BusinessBackupService.exportBusinessToFile(negocioId, businessName);

      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          CustomSnackBar.show(context, message: "¡Backup de \"$businessName\" guardado en Descargas!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al crear el backup.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(context, message: "Error: $e", isError: true);
      }
    }
  }

  // ============================================================
  // EJECUCIÓN DE BACKUP: Sistema completo
  // ============================================================

  @override
  Future<void> _executeFullSystemBackup() async {
    setState(() {
      _isProcessing = true;
      _processingMessage = "Creando backup del\nsistema completo...";
    });

    try {
      bool ok = await BackupManager.exportToDownloads();

      if (mounted) {
        setState(() => _isProcessing = false);
        if (ok) {
          CustomSnackBar.show(context, message: "¡Backup del sistema guardado en Descargas!", isError: false);
        } else {
          CustomSnackBar.show(context, message: "Error al crear el backup del sistema.", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        CustomSnackBar.show(context, message: "Error: $e", isError: true);
      }
    }
  }

  // ============================================================
  // MÓDULO UNIFICADO DE RESPALDO Y RESTAURACIÓN EN PERFILES
  // ============================================================

  @override
  Widget _buildUnifiedBackupSection(
    BuildContext context, {
    required bool isDark,
    required bool isEmptyState,
    required List<UserModel> profiles,
  }) {
    final driveProv = Provider.of<GoogleDriveBackupProvider?>(context);
    final cardBg = isDark ? const Color(0xFF1B1E26) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    if (driveProv == null) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: _buildLocalRestoreTile(isDark),
      );
    }

    final isConnected = driveProv.isConnected && driveProv.currentUser != null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila Superior: Google Drive
          if (!isConnected)
            _buildDriveUnlinkedTile(driveProv, isDark)
          else
            _buildDriveLinkedTile(driveProv, isDark, profiles),

          // Divisor sutil
          Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),

          // Fila Inferior: Archivo local .mlbg en una sola línea limpia
          _buildLocalRestoreTile(isDark),
        ],
      ),
    );
  }

  Widget _buildDriveUnlinkedTile(GoogleDriveBackupProvider driveProv, bool isDark) {
    return InkWell(
      key: const ValueKey('drive_unlinked_card'),
      onTap: _isDriveActionLoading ? null : () => _handleDriveSignIn(driveProv),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_download_rounded,
                size: 20,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recuperar desde Google Drive",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Vincula tu correo para respaldar o restaurar tus negocios en la nube",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (_isDriveActionLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriveLinkedTile(
    GoogleDriveBackupProvider driveProv,
    bool isDark,
    List<UserModel> profiles,
  ) {
    final health = GoogleDriveBackupProvider.computeHealthInfo(
      backups: driveProv.backups,
      isDark: isDark,
    );

    return InkWell(
      key: const ValueKey('drive_linked_card'),
      onTap: () => _openDriveQuickOptionsModal(driveProv, isDark, profiles),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: health.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                health.icon,
                size: 18,
                color: health.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driveProv.currentUser?.email ?? "Cuenta Google",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    health.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: health.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalRestoreTile(bool isDark) {
    return InkWell(
      key: const ValueKey('local_backup_restore_tile'),
      onTap: () => showProfileRestoreBottomSheet(context),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 17,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Restaurar respaldo local (.mlbg)",
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
