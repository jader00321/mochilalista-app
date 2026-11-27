part of '../backup_screen.dart';

mixin _BackupLocalSectionsMixin on _BackupScreenBase {
  void _confirmRestore(BuildContext context, BackupProvider backupProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Zona de Peligro",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          "Estás a punto de reemplazar TODA la información actual de tu negocio (inventario, clientes, ventas).\n\n"
          "Si continúas, la aplicación se reiniciará con los datos del archivo que elijas. Esta acción NO se puede deshacer.",
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await backupProvider.restoreDatabase();

              if (context.mounted) {
                if (success) {
                  AppFeedbackHelper.showSuccess(
                    context,
                    "¡Datos restaurados con éxito! Reiniciando...",
                  );
                  final auth = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await auth.logout();
                  await auth.checkInitialState();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileSelectionScreen(),
                    ),
                    (route) => false,
                  );
                } else if (backupProvider.errorMessage.isNotEmpty) {
                  AppFeedbackHelper.showError(
                    context,
                    backupProvider.errorMessage,
                  );
                }
              }
            },
            child: const Text(
              "Sí, Restaurar Datos",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalAutoBackupCard(
    BackupProvider backupProvider,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white10
              : Colors.indigoAccent.withValues(alpha: 0.3),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.indigoAccent.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              "Respaldo Local Automático en Memoria del Teléfono",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            subtitle: const Text(
              "Crea copias .mlbg silenciosas en el almacenamiento interno de este celular, sin usar Google Drive.",
              style: TextStyle(fontSize: 12),
            ),
            value: backupProvider.isAutoBackupEnabled,
            activeTrackColor: Colors.indigoAccent.withValues(alpha: 0.5),
            activeThumbColor: Colors.indigoAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onChanged: (val) => backupProvider.toggleAutoBackup(val),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !backupProvider.isAutoBackupEnabled
                ? const SizedBox.shrink()
                : _AutoBackupSettingsView(
                    provider: backupProvider,
                    isDark: isDark,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalExportCard(
    BuildContext context,
    BackupProvider backupProvider,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.2),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          _ActionButton(
            icon: Icons.chat_bubble_outline,
            label: "Enviar Backup Global por WhatsApp",
            color: Colors.green,
            isDark: isDark,
            isTop: true,
            onTap: () async {
              bool ok = await backupProvider.backupToWhatsApp();
              if (context.mounted &&
                  !ok &&
                  backupProvider.errorMessage.isNotEmpty) {
                AppFeedbackHelper.showError(
                  context,
                  backupProvider.errorMessage,
                );
              }
            },
          ),
          _ActionButton(
            icon: Icons.folder_open_rounded,
            label: "Guardar Backup Global en Descargas",
            color: Colors.orange,
            isDark: isDark,
            isBottom: false,
            onTap: () async {
              bool ok = await backupProvider.backupToDownloads();
              if (context.mounted) {
                if (ok) {
                  AppFeedbackHelper.showSuccess(
                    context,
                    "¡Guardado en la carpeta de Descargas!",
                  );
                } else {
                  AppFeedbackHelper.showError(
                    context,
                    backupProvider.errorMessage,
                  );
                }
              }
            },
          ),
          _Divider(isDark: isDark),
          _ActionSubButton(
            icon: Icons.folder_special_rounded,
            label: "Elegir carpeta personalizada",
            color: Colors.blueAccent,
            isDark: isDark,
            onTap: () async {
              String? customPath = await FilePicker.platform.getDirectoryPath();
              if (customPath == null) return;
              if (!context.mounted) return;
              AppFeedbackHelper.showInfo(
                context,
                "Guardando en ruta elegida...",
              );
              try {
                bool ok = await BackupManager.exportToDirectory(customPath);
                if (context.mounted) {
                  if (ok) {
                    AppFeedbackHelper.showSuccess(
                      context,
                      "¡Guardado en la carpeta elegida!",
                    );
                  } else {
                    AppFeedbackHelper.showError(
                      context,
                      "Error al exportar la base de datos.",
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  AppFeedbackHelper.showError(context, e.toString());
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocalRestoreCard(
    BuildContext context,
    BackupProvider backupProvider,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1418) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.redAccent.withValues(alpha: 0.3)
              : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restore_page_outlined,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Restauración Local (.mlbg o .db)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Recupera una copia desde el almacenamiento interno de este celular.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(
              Icons.file_open_outlined,
              color: Colors.redAccent,
              size: 20,
            ),
            label: const Text(
              "Cargar Backup Completo (.mlbg o .db)",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              side: BorderSide(
                color: Colors.redAccent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _confirmRestore(context, backupProvider),
          ),
        ],
      ),
    );
  }
}
