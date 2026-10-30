import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/backup_provider.dart';
import 'package:app_movil/core/utils/backup_manager.dart';
import 'package:app_movil/features/profile/services/business_backup_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

// ============================================================
// BOTTOM SHEET: Restaurar Backup (elegir tipo de archivo)
// ============================================================
void showProfileRestoreBottomSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, minPadding: kMinDefensiveBottomClearance);
      return SafeArea(
        top: false,
        bottom: true,
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restore_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 28),
                    const SizedBox(width: 12),
                    Text("Restaurar Backup", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Elige el tipo de archivo que deseas restaurar.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    handleUnifiedProfileRestore(context, type: 'mlb');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.withValues(alpha: 0.1) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.inventory_2_rounded, color: Colors.purple),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Importar Negocio (.mlb)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Agrega un perfil de negocio exportado previamente.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.purple),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    handleUnifiedProfileRestore(context, type: 'db');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.redAccent.withValues(alpha: 0.1) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.storage_rounded, color: Colors.redAccent),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Restaurar Sistema Completo (.mlbg o .db)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Reemplaza TODA la aplicación con una copia global.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================
// HANDLER: Lógica unificada de restauración de backups
// ============================================================
void handleUnifiedProfileRestore(BuildContext context, {String? type}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  // Abrir el selector genérico para evitar PlatformException en Android
  FilePickerResult? result;
  try {
    result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
  } catch (e) {
    if (context.mounted) CustomSnackBar.show(context, message: "Error al abrir archivos: $e", isError: true);
    return;
  }

  if (result == null || result.files.single.path == null) return;
  
  final path = result.files.single.path!;
  final lowerPath = path.toLowerCase();

  // Validación estricta de la extensión según el botón presionado
  if (type != null) {
    if (type == 'mlb' && !lowerPath.endsWith('.mlb') && !lowerPath.endsWith('.json')) {
      if (context.mounted) CustomSnackBar.show(context, message: "Formato incorrecto. Debes elegir un archivo de negocio (.mlb o .json).", isError: true);
      return;
    } else if (type == 'db' && !lowerPath.endsWith('.db') && !lowerPath.endsWith('.mlbg')) {
      if (context.mounted) CustomSnackBar.show(context, message: "Formato incorrecto. Debes elegir un archivo de sistema (.mlbg o .db).", isError: true);
      return;
    }
  }

  if (lowerPath.endsWith('.mlb') || lowerPath.endsWith('.json')) {
    // Flujo de importar Negocio (.mlb)
    if (!context.mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.localProfiles.isEmpty) {
      CustomSnackBar.show(context, message: "Debes tener al menos una cuenta para importar un negocio.", isError: true);
      return;
    }
    
    CustomSnackBar.show(context, message: "Procesando archivo de negocio...", isError: false);
    Map<String, dynamic> backupData;
    try {
      backupData = await BusinessBackupService.readBackupFile(path);
    } catch (e) {
      if (context.mounted) CustomSnackBar.show(context, message: e.toString(), isError: true);
      return;
    }

    if (!context.mounted) return;
    bool applyPin = false;
    if (backupData['has_security_pin'] == true) {
        bool? confirmPin = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_person_rounded, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text("Clave Detectada", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.purple))),
              ],
            ),
            content: const Text("El archivo contiene una clave de seguridad. ¿Deseas configurarla como la clave de este nuevo perfil?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Ignorar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(ctx, true), 
                child: const Text("Sí, Usarla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              )
            ],
          )
        );
        if (confirmPin == null) return;
        applyPin = confirmPin;
    }

    if (!context.mounted) return;
    CustomSnackBar.show(context, message: "Importando negocio...", isError: false);
    
    // Usamos el ID del primer usuario local como dueño provisional
    bool ok = await BusinessBackupService.importBusiness(auth.localProfiles.first.id, backupData['filePath'] ?? path, applyPin: applyPin);
    
    if (context.mounted) {
      if (ok) {
        CustomSnackBar.show(context, message: "Negocio importado correctamente. Inicia sesión.", isError: false);
        auth.checkInitialState();
      } else {
        CustomSnackBar.show(context, message: "No se pudo importar el negocio.", isError: true);
      }
    }

  } else if (lowerPath.endsWith('.db') || lowerPath.endsWith('.mlbg')) {
    // Flujo de restaurar Sistema completo (.db o .mlbg)
    if (!context.mounted) return;
    bool? confirmDb = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text("Restaurar Sistema", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent))),
          ],
        ),
        content: const Text("Estás a punto de reemplazar TODA la base de datos de la aplicación. Perderás todos los negocios actuales.\n\n¿Deseas continuar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Restaurar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      )
    );

    if (confirmDb != true) return;
    
    if (!context.mounted) return;
    CustomSnackBar.show(context, message: "Restaurando sistema...", isError: false);
    final backupProvider = Provider.of<BackupProvider>(context, listen: false);
    
    try {
      bool success = await BackupManager.restoreBackupFromFilePath(path);
      if (context.mounted) {
        if (success) {
          CustomSnackBar.show(context, message: "Base de datos restaurada. Reiniciando...", isError: false);
          Provider.of<AuthProvider>(context, listen: false).checkInitialState();
        } else {
          CustomSnackBar.show(context, message: backupProvider.errorMessage.isNotEmpty ? backupProvider.errorMessage : "Error al restaurar la base de datos.", isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.show(context, message: e.toString(), isError: true);
      }
    }
  } else {
    if (context.mounted) CustomSnackBar.show(context, message: "Formato de archivo no soportado (.db, .mlbg o .mlb)", isError: true);
  }
}
