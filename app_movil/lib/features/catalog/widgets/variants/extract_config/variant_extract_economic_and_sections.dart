part of '../variant_extract_config_modal.dart';

extension _VariantExtractEconomicAndSectionsExtension
    on _VariantExtractConfigModalState {
  Widget _buildEconomicBreakdownSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blue.withValues(alpha: 0.3)
              : const Color(0xFFBFDBFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "DESGLOSE ECONÓMICO INTELIGENTE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• $_unidadVenta (x$_factorVenta): Costo S/ ${_costoUnitario.toStringAsFixed(2)} • Venta S/ ${_precioVenta.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.teal[300] : Colors.teal[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "• Por unidad: Costo S/ ${_unitCostPrice.toStringAsFixed(2)} • Venta S/ ${_unitSalePrice.toStringAsFixed(2)} • Margen ${((_margen - 1) * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "¿Cómo deseas estructurar el nuevo producto?",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[200] : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 8),
          _buildStructureOption(
            structure: VariantExtractionStructure.keepPackaging,
            title: "1. Mantener en Empaque ($_unidadVenta x$_factorVenta)",
            subtitle:
                "Se vende por $_unidadVenta a S/ ${_precioVenta.toStringAsFixed(2)} con stock de $_packageUnits ${_unidadVenta}s ($_baseUnits und. base).",
            isSelected:
                _targetStructure == VariantExtractionStructure.keepPackaging,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _buildStructureOption(
            structure: VariantExtractionStructure.unitOnly,
            title: "2. Convertir a Unidad Individual (Unidad x1)",
            subtitle:
                "Se venderá al por menor a S/ ${_unitSalePrice.toStringAsFixed(2)} con stock de $_baseUnits Unidades.",
            isSelected: _targetStructure == VariantExtractionStructure.unitOnly,
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _buildStructureOption(
            structure: VariantExtractionStructure.bothUnitAndPackage,
            title:
                "3. Crear con Ambas (Unidad x1 + $_unidadVenta x$_factorVenta)",
            subtitle:
                "Crea 2 presentaciones en Stock Compartido ($_baseUnits und. base) para vender por menor y por mayor.",
            isSelected:
                _targetStructure ==
                VariantExtractionStructure.bothUnitAndPackage,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStructureOption({
    required VariantExtractionStructure structure,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _refreshState(() => _targetStructure = structure);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.25)
                    : const Color(0xFFDBEAFE))
              : (isDark ? Colors.black12 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.blue.shade400 : const Color(0xFF2563EB))
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 15,
                color: isSelected
                    ? (isDark ? Colors.blue[300] : const Color(0xFF1E40AF))
                    : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? (isDark
                                ? Colors.blue[100]
                                : const Color(0xFF1E3A8A))
                          : (isDark ? Colors.grey[200] : Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralAndDetailSections({
    required bool isDark,
    required Color borderColor,
    required String empaqueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "A. DATOS GENERALES DEL PRODUCTO ACTUAL",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _copyGeneralData,
                activeThumbColor: Colors.teal,
                activeTrackColor: Colors.teal.withValues(alpha: 0.3),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  _refreshState(() {
                    _copyGeneralData = val;
                    _copyCategory = val;
                    _copyBrand = val;
                    _copyProvider = val;
                    _copyDescription = val;
                    _copyImages = val;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildToggleChip(
              label: "Categoría: ${widget.categoryName ?? 'Ninguna'}",
              icon: Icons.category_outlined,
              isSelected: _copyCategory,
              enabled: _copyGeneralData && widget.categoryId != null,
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _copyCategory = !_copyCategory),
            ),
            _buildToggleChip(
              label: "Marca: ${widget.brandName ?? 'Ninguna'}",
              icon: Icons.branding_watermark_outlined,
              isSelected: _copyBrand,
              enabled: _copyGeneralData && widget.brandId != null,
              isDark: isDark,
              onToggle: () => _refreshState(() => _copyBrand = !_copyBrand),
            ),
            _buildToggleChip(
              label: "Proveedor: ${widget.generalProviderName ?? 'Ninguno'}",
              icon: Icons.local_shipping_outlined,
              isSelected: _copyProvider,
              enabled:
                  _copyGeneralData &&
                  (widget.generalProviderId != null ||
                      widget.generalProviderName != null),
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _copyProvider = !_copyProvider),
            ),
            _buildToggleChip(
              label: "Descripción / Notas",
              icon: Icons.notes_rounded,
              isSelected: _copyDescription,
              enabled:
                  _copyGeneralData &&
                  (widget.parentDescription?.isNotEmpty ?? false),
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _copyDescription = !_copyDescription),
            ),
            _buildToggleChip(
              label: "Fotos generales",
              icon: Icons.photo_outlined,
              isSelected: _copyImages,
              enabled:
                  _copyGeneralData &&
                  (widget.parentImageUrl?.isNotEmpty ?? false),
              isDark: isDark,
              onToggle: () => _refreshState(() => _copyImages = !_copyImages),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(color: borderColor, height: 1),
        const SizedBox(height: 14),
        Text(
          "B. DATOS DETALLADOS DE LA VARIANTE",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildToggleChip(
              label:
                  "Precios, Costo y Margen (S/ ${_precioVenta.toStringAsFixed(2)})",
              icon: Icons.attach_money_rounded,
              isSelected: _includePricing,
              enabled: true,
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _includePricing = !_includePricing),
            ),
            _buildToggleChip(
              label: "Unidad / Empaque ($_unidadVenta x$_factorVenta)",
              icon: Icons.inventory_2_outlined,
              isSelected: _includeUnit,
              enabled: true,
              isDark: isDark,
              onToggle: () => _refreshState(() => _includeUnit = !_includeUnit),
            ),
            if (_variantImage.isNotEmpty)
              _buildToggleChip(
                label: "Foto de la variante",
                icon: Icons.image_outlined,
                isSelected: _includeVariantImage,
                enabled: true,
                isDark: isDark,
                onToggle: () => _refreshState(
                  () => _includeVariantImage = !_includeVariantImage,
                ),
              ),
            _buildToggleChip(
              label: "Stock Actual ($empaqueLabel)",
              icon: Icons.warehouse_outlined,
              isSelected: _includeStock,
              enabled: true,
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _includeStock = !_includeStock),
            ),
            _buildToggleChip(
              label: _barcode.isNotEmpty
                  ? "Código de Barras ($_barcode)"
                  : "Código de Barras (Vacío)",
              icon: Icons.qr_code_rounded,
              isSelected: _includeBarcode,
              enabled: _barcode.isNotEmpty,
              isDark: isDark,
              onToggle: () {
                if (_barcode.isEmpty) return;
                _refreshState(() => _includeBarcode = !_includeBarcode);
              },
            ),
            _buildToggleChip(
              label: "Alerta Stock Mínimo",
              icon: Icons.notifications_active_outlined,
              isSelected: _includeStockAlert,
              enabled: true,
              isDark: isDark,
              onToggle: () =>
                  _refreshState(() => _includeStockAlert = !_includeStockAlert),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool enabled,
    required bool isDark,
    required VoidCallback onToggle,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onToggle();
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? Colors.teal.withValues(alpha: 0.18)
                      : Colors.teal.shade50)
                : (isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.teal.shade400 : Colors.teal)
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 13,
                color: isSelected ? Colors.teal : Colors.grey,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? (isDark ? Colors.teal[200] : Colors.teal[900])
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
