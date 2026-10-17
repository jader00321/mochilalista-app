import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🏆 QuickSaleNoteModal (Mobile Awards Standard)
/// Reemplaza el antiguo Drawer vacío por un Bottom Sheet interactivo,
/// con chips rápidos de un toque, contador de caracteres y blindaje ante el teclado virtual.
class QuickSaleNoteModal extends StatefulWidget {
  const QuickSaleNoteModal({super.key});

  static Future<void> show(BuildContext context) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => const QuickSaleNoteModal(),
    );
  }

  @override
  State<QuickSaleNoteModal> createState() => _QuickSaleNoteModalState();
}

class _QuickSaleNoteModalState extends State<QuickSaleNoteModal> {
  late TextEditingController _ctrl;
  static const int _maxLength = 250;

  static const List<String> _quickChips = [
    "Entrega pendiente",
    "Envío a domicilio",
    "Cliente recoge en tienda",
    "Pago mixto / por confirmar",
    "Empaque para regalo",
    "Comprobante pendiente",
  ];

  @override
  void initState() {
    super.initState();
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final initialNote = quickProv.saleNote ?? '';
    _ctrl = TextEditingController(text: initialNote)
      ..selection = TextSelection.collapsed(offset: initialNote.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _appendChip(String text) {
    final current = _ctrl.text.trim();
    String updated;
    if (current.isEmpty) {
      updated = text;
    } else if (current.contains(text)) {
      return; // Ya existe en la nota
    } else {
      updated = "$current - $text";
    }

    if (updated.length > _maxLength) {
      updated = updated.substring(0, _maxLength);
    }

    setState(() {
      _ctrl.text = updated;
      _ctrl.selection = TextSelection.collapsed(offset: updated.length);
    });
  }

  void _clearNote(QuickSaleProvider prov) {
    setState(() {
      _ctrl.clear();
    });
    prov.clearSaleNote();
  }

  void _confirmNote(QuickSaleProvider prov) {
    final text = _ctrl.text.trim();
    prov.setClientInfo(
      saleNote: text.isEmpty ? null : text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quickProv = Provider.of<QuickSaleProvider>(context);
    final currentLength = _ctrl.text.length;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con ícono y título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: isDark ? Colors.amber[300] : Colors.amber[800],
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Nota de Venta",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Detalle o condición especial para este pedido",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                IconButton(
                  tooltip: "Limpiar nota",
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  onPressed: () => _clearNote(quickProv),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Chips de acceso rápido (1-Touch)
          Text(
            "Etiquetas rápidas:",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _quickChips.map((chipText) {
                final isSelected = _ctrl.text.contains(chipText);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      chipText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isDark ? Colors.amber[200] : Colors.amber[900])
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => _appendChip(chipText),
                    backgroundColor: isDark ? const Color(0xFF23232F) : Colors.grey[100],
                    selectedColor: isDark
                        ? Colors.amber.withValues(alpha: 0.25)
                        : Colors.amber.withValues(alpha: 0.2),
                    checkmarkColor: isDark ? Colors.amber[200] : Colors.amber[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? (isDark ? Colors.amber.withValues(alpha: 0.5) : Colors.amber)
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Campo de texto para la nota
          TextField(
            controller: _ctrl,
            maxLines: 4,
            maxLength: _maxLength,
            autofocus: false,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.35,
            ),
            decoration: InputDecoration(
              hintText: "Escribe detalles de entrega, recordatorios de cobro o referencias...",
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF161622) : const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
              counterText: "$currentLength / $_maxLength",
              counterStyle: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Botón de acción principal
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _confirmNote(quickProv),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text(
                "Confirmar Nota",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
