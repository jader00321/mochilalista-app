import 'package:flutter/material.dart';

class MasterDetailModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;
  final List<Map<String, String>> dataRows;
  
  final int usageCount; 

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleActive;

  const MasterDetailModal({
    super.key,
    required this.title,
    this.subtitle = "Detalle del registro",
    required this.icon,
    required this.color,
    required this.isActive,
    required this.dataRows,
    this.usageCount = 0, 
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  State<MasterDetailModal> createState() => _MasterDetailModalState();
}

class _MasterDetailModalState extends State<MasterDetailModal> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final bool canDelete = widget.usageCount == 0;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de arrastre
          Center(
            child: Container(
              width: 50, height: 5, margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Cabecera
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: (_isActive ? widget.color : Colors.grey).withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(widget.icon, color: _isActive ? widget.color : (isDark ? Colors.grey[400] : Colors.grey), size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle, style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Switch Estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isActive ? (isDark ? Colors.green.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.05)) : (isDark ? Colors.orange.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isActive ? (isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.2)) : (isDark ? Colors.orange.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Icon(_isActive ? Icons.check_circle : Icons.pause_circle_filled, color: _isActive ? (isDark ? Colors.green[400] : Colors.green) : (isDark ? Colors.orange[400] : Colors.orange), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isActive ? "Estado: ACTIVO" : "Estado: SUSPENDIDO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isActive ? (isDark ? Colors.green[300] : Colors.green[800]) : (isDark ? Colors.orange[300] : Colors.orange[800]))),
                      const SizedBox(height: 2),
                      Text(_isActive ? "Visible para usar en el inventario." : "Oculto en las listas desplegables.", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  activeThumbColor: isDark ? Colors.green[400] : Colors.green,
                  onChanged: (val) { 
                    setState(() => _isActive = val);
                    widget.onToggleActive(val); 
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Datos
          if (widget.dataRows.isNotEmpty) ...[
            Text("INFORMACIÓN DETALLADA", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            ...widget.dataRows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 110, child: Text(row['label'] ?? "", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500, fontSize: 15))),
                  Expanded(child: Text((row['value']?.isEmpty ?? true) ? "-" : row['value']!, style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15))),
                ],
              ),
            )),
            Divider(height: 40, color: isDark ? Colors.white10 : Colors.grey[200]),
          ],

          // Botones Acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { 
                    Navigator.pop(context); // Cierra el bottomsheet
                    widget.onEdit(); // Llama a la lógica principal de manera segura
                  },
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text("EDITAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800], side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(width: 16),
              
              // BOTÓN ELIMINAR INTELIGENTE
              Expanded(
                child: canDelete 
                ? OutlinedButton.icon(
                    onPressed: () { 
                      Navigator.pop(context); // Cierra el bottomsheet
                      widget.onDelete(); // Llama a la lógica principal de manera segura
                    },
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text("ELIMINAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: isDark ? Colors.red[300] : Colors.red[700], side: BorderSide(color: isDark ? Colors.red.withValues(alpha: 0.5) : Colors.red.shade200), backgroundColor: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300)),
                    child: Column(
                      children: [
                        Icon(Icons.lock_outline, size: 20, color: isDark ? Colors.grey[400] : Colors.grey),
                        const SizedBox(height: 2),
                        Text("En uso (${widget.usageCount})", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey)),
                      ],
                    ),
                  ),
              ),
            ],
          ),
          if (!canDelete)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                "No se puede eliminar porque está asignado a ${widget.usageCount} productos. Suspéndalo para dejar de usarlo.",
                style: TextStyle(fontSize: 13, color: isDark ? Colors.red[300] : Colors.red, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}