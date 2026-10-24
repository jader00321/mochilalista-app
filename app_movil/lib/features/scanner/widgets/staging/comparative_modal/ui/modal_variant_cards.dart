part of '../comparative_update_modal.dart';

extension _ModalVariantCards on _ComparativeUpdateModalState {
  Widget _buildVariantCards() {
    final alternatives = widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();
    bool isNewSelected = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE";
    int? selectedId = isNewSelected ? -1 : widget.variant.matchPresentacion.datos?.id;
    if (!isNewSelected && selectedId != null && !alternatives.any((p) => p['id'] == selectedId)) {
      selectedId = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        itemCount: alternatives.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          if (i == alternatives.length) {
            bool isSelected = isNewSelected;
            return GestureDetector(
              onTap: () {
                updateState(() {
                  widget.provider.switchVariantToNew(widget.variant.uuidTemporal);
                  _currentDbData = {};
                  _initControllers();
                });
                Navigator.pop(context);
              },
              child: Container(
                width: 140,
                decoration: BoxDecoration(
                  color: isSelected ? (widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50) : (widget.isDark ? const Color(0xFF1A1A24) : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? (widget.isDark ? Colors.blue : Colors.blue.shade400) : (widget.isDark ? Colors.white24 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                      const SizedBox(width: 6),
                      Text("Crear Nueva", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            );
          }

          var p = alternatives[i];
          bool isSelected = selectedId == p['id'];
          String pName = p['nombre_completo']?.toString() ?? p['nombre_especifico']?.toString() ?? '';
          if (pName.isEmpty || pName == 'null') pName = 'General';
          
          return GestureDetector(
            onTap: () {
              updateState(() {
                widget.provider.switchVariantLink(widget.variant.uuidTemporal, p['id']);
                _currentDbData = Map.from(p);
                _initControllers();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 160,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? (widget.isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50) : (widget.isDark ? const Color(0xFF23232F) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? (widget.isDark ? Colors.green[400]! : Colors.green) : (widget.isDark ? Colors.white10 : Colors.grey.shade200),
                  width: isSelected ? 2 : 1
                ),
                boxShadow: [
                  if (!widget.isDark && !isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(pName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? (widget.isDark ? Colors.green[300] : Colors.green[800]) : (widget.isDark ? Colors.white : Colors.black87)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text("${p['unidad'] ?? 'Unidad'} (x${p['factor_conversion'] ?? 1})", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Stock: ${p['stock_actual'] ?? 0}", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p['precio_oferta'] != null)
                            Text("S/${(p['precio_venta'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 9, decoration: TextDecoration.lineThrough, color: widget.isDark ? Colors.grey[500] : Colors.grey[400])),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (p['precio_oferta'] != null)
                                Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(4)), child: const Text("PROMO", style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold))),
                              Text("S/${(p['precio_oferta'] ?? p['precio_venta'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: p['precio_oferta'] != null ? Colors.purple[400] : (widget.isDark ? Colors.blue[300] : Colors.blue[700]))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }



  // ============================================================================
  // FASE 7: NUEVOS WIDGETS DE COMPARACIÓN COMPACTOS
  // ============================================================================

  /// Layout vertical compacto: checkbox + label + referencia BD en una línea,
  /// TextField a ancho completo debajo.
  /// ```
  /// ┌──────────────────────────────────────────┐
  /// │ [✓] Nombre Específico       BD: Papel A4 │
  /// │ ┌────────────────────────────────────────┐│
  /// │ │ Papel A4 Rojo                          ││
  /// │ └────────────────────────────────────────┘│
  /// └──────────────────────────────────────────┘
  /// ```
  Widget _buildCompactField(
    String label, 
    String dbValue, 
    TextEditingController ctrl, 
    bool isChecked, 
    Function(bool?) onChanged, {
    bool isText = false, 
    String? isPrefix, 
    VoidCallback? onTextChanged,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50], 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: isChecked ? Colors.blue.withValues(alpha: 0.4) : (widget.isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Línea 1: Checkbox + Label + Referencia BD (Organizado para 0 recortes)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 20, height: 20,
                  child: Checkbox(
                    value: isChecked, 
                    onChanged: onChanged, 
                    activeColor: Colors.blue, 
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label, 
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w700, 
                        color: widget.isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dbValue.isNotEmpty && dbValue != 'null' && dbValue != 'N/A') ...[
                      const SizedBox(height: 1),
                      Text(
                        "BD: $dbValue", 
                        style: TextStyle(
                          fontSize: 9.5, 
                          color: isChecked 
                              ? (widget.isDark ? Colors.grey[500] : Colors.grey[600]) 
                              : (widget.isDark ? Colors.blue[300] : Colors.blue[700]), 
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Línea 2: TextField a ancho completo
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: ctrl,
                    enabled: isChecked,
                    onChanged: (_) => onTextChanged?.call(),
                    keyboardType: isText ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isChecked ? (widget.isDark ? Colors.white : Colors.black) : Colors.grey),
                    decoration: InputDecoration(
                      prefixText: isPrefix,
                      prefixStyle: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.isDark ? Colors.white24 : Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
                      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade200)),
                      filled: true,
                      fillColor: isChecked ? (widget.isDark ? const Color(0xFF14141C) : Colors.white) : (widget.isDark ? Colors.transparent : Colors.grey.shade100),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Para campos numéricos cortos: agrupa 2 campos en una fila horizontal.
  /// ```
  /// ┌───────────────────┬───────────────────┐
  /// │ [✓] Precio UMP    │ [✓] Pago Total    │
  /// │ BD: 9.95          │ BD: 9.95          │
  /// │ [___S/ 9.95___]   │ [___S/ 9.95___]   │
  /// └───────────────────┴───────────────────┘
  /// ```
  Widget _buildCompactFieldRow(List<_CompactFieldData> fields) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields.asMap().entries.map((entry) {
        final i = entry.key;
        final f = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < fields.length - 1 ? 8 : 0),
            child: _buildCompactField(
              f.label, f.dbValue, f.ctrl, f.isChecked, f.onChanged,
              isText: f.isText, isPrefix: f.isPrefix, onTextChanged: f.onTextChanged,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Datos para un campo compacto (usado por _buildCompactFieldRow).
class _CompactFieldData {
  final String label;
  final String dbValue;
  final TextEditingController ctrl;
  final bool isChecked;
  final Function(bool?) onChanged;
  final bool isText;
  final String? isPrefix;
  final VoidCallback? onTextChanged;

  _CompactFieldData({
    required this.label,
    required this.dbValue,
    required this.ctrl,
    required this.isChecked,
    required this.onChanged,
    this.isText = false,
    this.isPrefix,
    this.onTextChanged,
  });
}
