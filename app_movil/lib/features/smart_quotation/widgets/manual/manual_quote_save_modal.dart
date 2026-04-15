import 'package:flutter/material.dart';

class ManualQuoteSaveModal extends StatelessWidget {
  final bool isEditing;
  final bool isAppOrder; // 🔥 FLAG B2C: Indica si el pedido vino de la App de Cliente
  final void Function(String status, String type, {bool forceClone}) onSave;

  const ManualQuoteSaveModal({
    super.key,
    required this.isEditing,
    this.isAppOrder = false, // Por defecto falso para no romper compatibilidad
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text("Opciones de Guardado", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          if (isEditing) ...[
            
            // 🔥 LÓGICA B2C: Si es un pedido de la App, obligamos a clonar en lugar de sobreescribir.
            if (isAppOrder) ...[
              _buildSaveOption(
                context,
                icon: Icons.copy_all, 
                title: "Clonar y Asignar", 
                subtitle: "Crea una copia de este pedido sin afectar el original del cliente.", 
                color: isDark ? Colors.blue[300]! : Colors.blue, 
                isDark: isDark,
                onTap: () => onSave('MAINTAIN_CURRENT', 'manual', forceClone: true), 
              ),
            ] else ...[
              _buildSaveOption(
                context,
                icon: Icons.save, 
                title: "Actualizar Cambios", 
                subtitle: "Guarda las modificaciones realizadas.", 
                color: isDark ? Colors.blue[300]! : Colors.blue, 
                isDark: isDark,
                onTap: () => onSave('MAINTAIN_CURRENT', 'manual'), 
              ),
            ],

            const SizedBox(height: 12),
            _buildSaveOption(
              context,
              icon: Icons.inventory_2, 
              title: "Duplicar como Pack", 
              subtitle: "Crea una plantilla nueva sin alterar la original.", 
              color: isDark ? Colors.purple[300]! : Colors.purple, 
              isDark: isDark,
              onTap: () => onSave('PENDING', 'pack'), 
            ),
          ] else ...[
            _buildSaveOption(
              context,
              icon: Icons.edit_document, 
              title: "Guardar como Borrador", 
              subtitle: "Podrás seguir editando más tarde.", 
              color: isDark ? Colors.grey[300]! : Colors.grey[700]!, 
              isDark: isDark,
              onTap: () => onSave('DRAFT', 'manual'),
            ),
            const SizedBox(height: 12),
            _buildSaveOption(
              context,
              icon: Icons.bookmark_added, 
              title: "Lista Lista para Vender", 
              subtitle: "La cotización quedará pendiente de pago.", 
              color: isDark ? Colors.teal[300]! : Colors.teal, 
              isDark: isDark,
              onTap: () => onSave('READY', 'manual'),
            ),
            const SizedBox(height: 12),
            _buildSaveOption(
              context,
              icon: Icons.inventory_2, 
              title: "Crear Pack Escolar", 
              subtitle: "Guarda esto como una plantilla reutilizable.", 
              color: isDark ? Colors.purple[300]! : Colors.purple, 
              isDark: isDark,
              onTap: () => onSave('PENDING', 'pack'),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSaveOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required bool isDark, required VoidCallback onTap}) {
    return InkWell(
      onTap: () { Navigator.pop(context); onTap(); },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.15), radius: 26, child: Icon(icon, color: color, size: 26)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.white24 : Colors.grey)
          ],
        ),
      ),
    );
  }
}