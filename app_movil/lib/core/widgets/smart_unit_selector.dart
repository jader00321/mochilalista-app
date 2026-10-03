import 'package:flutter/material.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';

class SmartUnitSelector extends StatefulWidget {
  final TextEditingController unitCtrl;
  final TextEditingController factorCtrl;
  final bool isDark;
  final Function(String unitName, int factor, bool isAutomatic)? onChanged;
  final bool isCompact;
  final bool isMini;

  const SmartUnitSelector({
    super.key,
    required this.unitCtrl,
    required this.factorCtrl,
    required this.isDark,
    this.onChanged,
    this.isCompact = false,
    this.isMini = false,
  });

  @override
  State<SmartUnitSelector> createState() => _SmartUnitSelectorState();
}

class _SmartUnitSelectorState extends State<SmartUnitSelector> {
  bool _isExpanded = false;

  void _onUnitTextChanged(String text) {
    UnitMatch? match = UnitCatalogService.resolveUnit(text);
    if (match != null) {
      if (!match.isConfigurable) {
        if (widget.factorCtrl.text != match.factor.toString()) {
          widget.factorCtrl.text = match.factor.toString();
          widget.onChanged?.call(match.name, match.factor, true);
        }
      } else {
        int currentFactor = int.tryParse(widget.factorCtrl.text) ?? 1;
        widget.onChanged?.call(match.name, currentFactor, true);
      }
    } else {
      int currentFactor = int.tryParse(widget.factorCtrl.text) ?? 1;
      widget.onChanged?.call(text, currentFactor, false);
    }
  }

  void _onFactorTextChanged(String text) {
    int factor = int.tryParse(text) ?? 1;
    String? resolvedName = UnitCatalogService.resolveFromFactor(factor);
    
    if (resolvedName != null && UnitCatalogService.isStandardUnit(widget.unitCtrl.text)) {
      if (resolvedName.toLowerCase() != widget.unitCtrl.text.toLowerCase().trim()) {
        widget.unitCtrl.text = resolvedName;
        widget.onChanged?.call(resolvedName, factor, true);
        return;
      }
    }
    
    if (resolvedName == null && factor > 1) {
      UnitMatch? currentMatch = UnitCatalogService.resolveUnit(widget.unitCtrl.text);
      if (currentMatch != null && !currentMatch.isConfigurable) {
        widget.unitCtrl.text = "Caja";
        widget.onChanged?.call("Caja", factor, true);
        return;
      }
    }
    
    widget.onChanged?.call(widget.unitCtrl.text, factor, false);
  }

  void _selectChip(Map<String, dynamic> unit) {
    widget.unitCtrl.text = unit['name'];
    widget.factorCtrl.text = unit['factor'].toString();
    widget.onChanged?.call(unit['name'], unit['factor'], true);
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMini) {
      // Modo ultra compacto para Tablas Comparativas (Clasificar y Confirmar)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMiniInputRow(),
          const SizedBox(height: 4),
          _buildToggleButton(),
          _buildExpandedChips(),
        ],
      );
    }

    if (widget.isCompact) {
      // Modo compacto (StagingRow)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactInputRow(),
          const SizedBox(height: 4),
          _buildToggleButton(),
          _buildExpandedChips(),
        ],
      );
    }

    // Modo Normal (Crear / Editar Producto)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNormalInputRow(),
        const SizedBox(height: 6),
        _buildToggleButton(),
        _buildExpandedChips(),
      ],
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: widget.isDark ? Colors.purple[300] : Colors.purple[700]),
            const SizedBox(width: 4),
            Text("Ver unidades disponibles", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.purple[300] : Colors.purple[700], fontWeight: FontWeight.bold)),
            Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: widget.isDark ? Colors.purple[300] : Colors.purple[700]),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedChips() {
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity, height: 0),
      secondChild: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...UnitCatalogService.getAllFixedUnits().map((u) {
                bool isSelected = widget.unitCtrl.text.toLowerCase().trim() == u['name'].toString().toLowerCase().trim();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text("${u['name']} (x${u['factor']})", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (widget.isDark ? Colors.purple[200] : Colors.purple[800]))),
                    backgroundColor: isSelected ? (widget.isDark ? Colors.purple[600] : Colors.purple[600]) : (widget.isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.shade50),
                    side: BorderSide(color: isSelected ? Colors.transparent : (widget.isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200)),
                    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                    onPressed: () => _selectChip(u),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text("Caja", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.purple[200] : Colors.purple[800])),
                  backgroundColor: widget.isDark ? Colors.purple.withValues(alpha: 0.15) : Colors.purple.shade50,
                  side: BorderSide(color: widget.isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200),
                  visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                  onPressed: () {
                    int currentFactor = int.tryParse(widget.factorCtrl.text) ?? 1;
                    if (currentFactor == 1) currentFactor = 24;
                    _selectChip({'name': 'Caja', 'factor': currentFactor});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildNormalInputRow() {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Unidad", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: widget.unitCtrl,
                  onChanged: _onUnitTextChanged,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Docena", hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.purple[400]! : Colors.purple)),
                  ),
                ),
              ),
            ],
          )
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Factor", style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 38,
                child: TextField(
                  controller: widget.factorCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: _onFactorTextChanged,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "12", hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.white10 : Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.isDark ? Colors.purple[400]! : Colors.purple)),
                  ),
                ),
              ),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildCompactInputRow() {
    // Usado en variant_editor_row.dart
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Unidad Venta", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: TextField(
                  controller: widget.unitCtrl,
                  onChanged: _onUnitTextChanged,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Unidad", hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          )
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Factor Venta", style: TextStyle(fontSize: 10, color: widget.isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: TextField(
                  controller: widget.factorCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: _onFactorTextChanged,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "1", hintStyle: TextStyle(color: widget.isDark ? Colors.white24 : Colors.black26),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildMiniInputRow() {
    // Usado en la tabla comparativa de comparative_update_modal.dart
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 28,
            child: TextField(
              controller: widget.unitCtrl,
              onChanged: _onUnitTextChanged,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          )
        ),
        const SizedBox(width: 6),
        Text("x", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[500] : Colors.grey[600])),
        const SizedBox(width: 6),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 28,
            child: TextField(
              controller: widget.factorCtrl,
              keyboardType: TextInputType.number,
              onChanged: _onFactorTextChanged,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                filled: true, fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          )
        ),
      ],
    );
  }
}
