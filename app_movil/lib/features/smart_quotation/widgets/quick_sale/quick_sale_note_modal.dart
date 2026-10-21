import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🏆 QuickSaleNoteModal (Mobile Awards Standard)
/// Bottom Sheet interactivo de alta fidelidad para notas de venta en Caja Rápida.
/// Superficie sólida anti-transparencia con micro-desenfoque, chips en Wrap responsivo
/// y blindaje universal contra la barra de 3 botones de Android y el teclado virtual.
class QuickSaleNoteModal extends StatefulWidget {
  const QuickSaleNoteModal({super.key});

  static Future<void> show(BuildContext context) {
    return InteractiveSheetWrapper.show(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
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

    // 🛡️ CÁLCULO SEGURO UNIVERSAL CONTRA BARRA DE 3 BOTONES Y TECLADO
    final bottomSafe = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final effectiveBottom = keyboardInset > 0
        ? keyboardInset + 16.0
        : math.max(bottomSafe + 16.0, 24.0);

    final surfaceColor = isDark ? const Color(0xFF1E1E28) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black12,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.22),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, effectiveBottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle superior interactivo
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header con ícono y título
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.amber.withValues(alpha: 0.18)
                              : Colors.amber.shade100,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? Colors.amber.withValues(alpha: 0.35)
                                : Colors.amber.shade300,
                            width: 1,
                          ),
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
                                letterSpacing: -0.3,
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
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                          onPressed: () => _clearNote(quickProv),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chips de acceso rápido en fila horizontal fluida y compacta
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
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(
                              chipText,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.amber[200] : Colors.amber[900])
                                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _appendChip(chipText),
                            backgroundColor: isDark ? const Color(0xFF262636) : Colors.grey[100],
                            selectedColor: isDark
                                ? Colors.amber.withValues(alpha: 0.25)
                                : Colors.amber.withValues(alpha: 0.2),
                            checkmarkColor: isDark ? Colors.amber[200] : Colors.amber[900],
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: isSelected
                                    ? (isDark ? Colors.amber.withValues(alpha: 0.6) : Colors.amber)
                                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                                width: isSelected ? 1.4 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo de texto para la nota (compacto y a prueba de teclado)
                  TextField(
                    controller: _ctrl,
                    maxLines: 3,
                    maxLength: _maxLength,
                    autofocus: false,
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: "Escribe detalles de entrega, recordatorios de cobro o referencias...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF14141E) : const Color(0xFFF6F7F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                      counterText: "$currentLength / $_maxLength",
                      counterStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // Botón de acción principal
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmNote(quickProv),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                        "Confirmar Nota",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

