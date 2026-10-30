import 'package:flutter/material.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

// ============================================================
// WIDGET: Tile reutilizable para opciones dentro de modales
// ============================================================
class ModalOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const ModalOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MODAL: Gestión de Perfiles (Crear Backup / Eliminar)
// ============================================================
void showProfileManagementModal({
  required BuildContext context,
  required VoidCallback onBackupOptionSelected,
  required VoidCallback onDeleteOptionSelected,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => InteractiveSheetWrapper(
      title: "Gestión de Perfiles",
      icon: Icons.dashboard_customize_rounded,
      iconColor: isDark ? Colors.blue[300] : Colors.blue[700],
      maxHeightFactor: 0.7,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Elige una acción para tus perfiles.",
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Opción: Crear Backup
            ModalOptionTile(
              icon: Icons.backup_rounded,
              label: "Crear Backup",
              subtitle: "Respalda un negocio o todo el sistema",
              color: Colors.indigoAccent,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                onBackupOptionSelected();
              },
            ),
            const SizedBox(height: 12),

            // Opción: Eliminar Perfil
            ModalOptionTile(
              icon: Icons.delete_forever_rounded,
              label: "Eliminar Perfil",
              subtitle: "Borra permanentemente un negocio",
              color: Colors.redAccent,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                onDeleteOptionSelected();
              },
            ),
            const SizedBox(height: kModalScrollBottomClearance),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// MODAL: Tipo de Backup (Perfil específico / Sistema completo)
// ============================================================
void showBackupTypeModal({
  required BuildContext context,
  required VoidCallback onSpecificProfileSelected,
  required VoidCallback onFullSystemSelected,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => InteractiveSheetWrapper(
      title: "Tipo de Backup",
      icon: Icons.cloud_upload_rounded,
      iconColor: isDark ? Colors.indigoAccent : Colors.indigo[700],
      maxHeightFactor: 0.7,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "¿Qué deseas respaldar?",
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Opción: Perfil específico
            ModalOptionTile(
              icon: Icons.store_rounded,
              label: "Perfil / Negocio Específico",
              subtitle: "Respalda un solo negocio (.mlb)",
              color: Colors.purple,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                onSpecificProfileSelected();
              },
            ),
            const SizedBox(height: 12),

            // Opción: Sistema Completo
            ModalOptionTile(
              icon: Icons.storage_rounded,
              label: "Sistema Completo",
              subtitle: "Respalda todos los datos (.mlbg)",
              color: Colors.blue,
              isDark: isDark,
              onTap: () {
                Navigator.pop(ctx);
                onFullSystemSelected();
              },
            ),
            const SizedBox(height: kModalScrollBottomClearance),
          ],
        ),
      ),
    ),
  );
}

// ============================================================
// MODAL: Confirmación de perfil para backup
// ============================================================
void showBackupConfirmationModal({
  required BuildContext context,
  required UserModel profile,
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bName = profile.business?.commercialName ?? "Negocio sin nombre";
  final uName = profile.fullName;

  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => InteractiveSheetWrapper(
      title: "¿Crear backup de este perfil?",
      icon: Icons.backup_rounded,
      iconColor: Colors.purple,
      maxHeightFactor: 0.65,
      bottomAction: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                onCancel();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text("Volver", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Confirmar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info del perfil seleccionado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded, size: 18, color: isDark ? Colors.purple[200] : Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(bName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(uName, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
