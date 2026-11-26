part of '../google_drive_backup_sheet.dart';

mixin _GoogleDriveActionsMixin on _GoogleDriveBackupSheetStateBase {
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

  @override
  String _formatDateTime(DateTime dt) =>
      AppDateFormatter.ddMMyyyyDotHhmma.format(dt.toLocal());

  @override
  Future<void> _handleSignOut(GoogleDriveBackupProvider prov) async {
    await prov.signOut();
    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Cuenta de Google desvinculada.",
      );
    }
  }

  @override
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

  @override
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

  @override
  Future<void> _updateFrequency(GoogleDriveBackupProvider prov, BackupFrequency freq) async {
    await prov.updateConfig(prov.config.copyWith(frequency: freq));
  }

  @override
  Future<void> _toggleWifiOnly(GoogleDriveBackupProvider prov, bool val) async {
    await prov.updateConfig(prov.config.copyWith(wifiOnly: val));
  }


  @override
  List<Widget> _buildDriveUnlinkedSection({
    required GoogleDriveBackupProvider prov,
    required bool isDark,
    required Color cardColor,
  }) {
    return [
            Container(
              key: widget.statusCardKey,
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
    ];
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
