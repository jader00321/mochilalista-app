import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/backup_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../widgets/custom_snackbar.dart';
import '../../../../screens/onboarding/profile_selection_screen.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

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
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text("Zona de Peligro", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))),
          ],
        ),
        content: Text(
          "Estás a punto de reemplazar TODA la información actual de tu negocio (inventario, clientes, ventas).\n\n"
          "Si continúas, la aplicación se reiniciará con los datos del archivo que elijas. Esta acción NO se puede deshacer.",
          style: TextStyle(fontSize: 15, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await backupProvider.restoreDatabase();
              
              if (context.mounted) {
                if (success) {
                  CustomSnackBar.show(context, message: "¡Datos restaurados con éxito! Reiniciando...", isError: false);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  await auth.logout();
                  await auth.checkInitialState();
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ProfileSelectionScreen()), (route) => false);
                } else if (backupProvider.errorMessage.isNotEmpty) {
                  CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                }
              }
            },
            child: const Text("Sí, Restaurar Datos", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backupProvider = Provider.of<BackupProvider>(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Respaldos y Seguridad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              const Text("Exportación Manual", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text("Guarda una copia exacta de tu inventario y ventas en este preciso momento.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200), boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    _ActionButton(
                      icon: Icons.chat_bubble_outline, label: "Enviar por WhatsApp", color: Colors.green, isDark: isDark, isTop: true,
                      onTap: () async {
                        bool ok = await backupProvider.backupToWhatsApp();
                        if (context.mounted && !ok && backupProvider.errorMessage.isNotEmpty) {
                          CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                        }
                      },
                    ),
                    _Divider(isDark: isDark),
                    _ActionButton(
                      icon: Icons.cloud_upload_outlined, label: "Subir a Google Drive", color: Colors.blueAccent, isDark: isDark,
                      onTap: () async {
                        bool ok = await backupProvider.backupToGoogleDrive();
                        if (context.mounted) {
                          if (ok) CustomSnackBar.show(context, message: "¡Respaldo subido a Drive exitosamente!", isError: false);
                          else CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                        }
                      },
                    ),
                    _Divider(isDark: isDark),
                    _ActionButton(
                      icon: Icons.folder_open_rounded, label: "Guardar en Descargas", color: Colors.orange, isDark: isDark, isBottom: true,
                      onTap: () async {
                        bool ok = await backupProvider.backupToDownloads();
                        if (context.mounted) {
                          if (ok) CustomSnackBar.show(context, message: "¡Guardado en la carpeta de Descargas!", isError: false);
                          else CustomSnackBar.show(context, message: backupProvider.errorMessage, isError: true);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              const Text("Protección Automática", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blue, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text("La aplicación creará un respaldo por ti de forma silenciosa e invisible.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              
              Container(
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.3)), boxShadow: [if (!isDark) BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text("Activar Backups Automáticos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text("Se ejecutarán en segundo plano.", style: TextStyle(fontSize: 13)),
                      value: backupProvider.isAutoBackupEnabled,
                      activeColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onChanged: (val) => backupProvider.toggleAutoBackup(val),
                    ),
                    
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: !backupProvider.isAutoBackupEnabled 
                        ? const SizedBox.shrink() 
                        : Column(
                            children: [
                              _Divider(isDark: isDark),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Frecuencia", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                      child: DropdownButton<int>(
                                        value: backupProvider.autoBackupIntervalDays,
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                        items: const [
                                          DropdownMenuItem(value: 7, child: Text("Cada 7 Días")),
                                          DropdownMenuItem(value: 15, child: Text("Cada 15 Días")),
                                          DropdownMenuItem(value: 30, child: Text("Cada 30 Días")),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) backupProvider.setAutoBackupInterval(val);
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Destino", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                                      child: DropdownButton<String>(
                                        value: backupProvider.autoBackupLocation,
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                        items: const [
                                          DropdownMenuItem(value: 'Local', child: Text("Descargas")),
                                          DropdownMenuItem(value: 'Drive', child: Text("Google Drive")),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) backupProvider.setAutoBackupLocation(val);
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              const Text("Restaurar Sistema", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text("Usa esta opción solo si cambiaste de celular o si necesitas recuperar una versión anterior.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                icon: const Icon(Icons.restore_page_outlined, color: Colors.red, size: 24),
                label: const Text("Cargar Backup .db", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
                  backgroundColor: Colors.red.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _confirmRestore(context, backupProvider),
              ),
              const SizedBox(height: 50),
            ],
          ),

          if (backupProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.blue),
                      const SizedBox(height: 20),
                      Text("Procesando...", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isTop;
  final bool isBottom;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.isDark, this.isTop = false, this.isBottom = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(top: Radius.circular(isTop ? 20 : 0), bottom: Radius.circular(isBottom ? 20 : 0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 65, color: isDark ? Colors.white10 : Colors.grey[200]);
  }
}