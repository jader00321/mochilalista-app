import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/backup/google_drive_backup_service.dart';
import 'package:app_movil/core/services/backup/i_google_drive_backup_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

/// Componente modular y hoja de gestión para Copias de Seguridad en Google Drive
class GoogleDriveBackupSheet extends StatefulWidget {
  final IGoogleDriveBackupService? backupService;
  final bool isDark;

  const GoogleDriveBackupSheet({
    super.key,
    this.backupService,
    this.isDark = false,
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
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        CustomSnackBar.show(
          context,
          message: cleanMsg,
          isError: true,
        );
      }
    }
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
          // Encabezado de la Sección
          Row(
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Copia de Seguridad en Google Drive (Opcional)",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Nube",
                            style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Respaldo automático con cifrado AES-256-GCM atado a tu cuenta de Google.",
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

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
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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

                  // Selector de Frecuencia
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Frecuencia de Respaldo",
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
                            value: _config.frequency,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            items: BackupFrequency.values.map((f) {
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
}
