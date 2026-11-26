part of '../variant_extract_config_modal.dart';

extension _VariantExtractHeaderAndModesExtension
    on _VariantExtractConfigModalState {
  Widget _buildHeaderSection({
    required bool isDark,
    required Color borderColor,
    required String empaqueLabel,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171722) : Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.teal.withValues(alpha: 0.2)
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.drive_file_move_outlined,
                  size: 20,
                  color: isDark ? Colors.teal[300] : Colors.teal[700],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Convertir Variante en Producto",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      "Desde: ${widget.originProductName}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.purple.withValues(alpha: 0.25)
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$_unidadVenta (x$_factorVenta) ${_specificName.isNotEmpty ? _specificName : ''}"
                          .trim(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.purple[200] : Colors.purple[800],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "S/ ${_precioVenta.toStringAsFixed(2)} • $empaqueLabel",
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.teal[300] : Colors.teal[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeAndNameSection({
    required bool isDark,
    required bool canCut,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildModeCard(
                mode: ProductExtractionMode.copy,
                icon: Icons.copy_rounded,
                title: "Copiar",
                desc: "Mantiene en este producto y crea uno nuevo.",
                isSelected: _mode == ProductExtractionMode.copy,
                isEnabled: true,
                isDark: isDark,
                onTap: () => _onModeChanged(ProductExtractionMode.copy),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModeCard(
                mode: ProductExtractionMode.cut,
                icon: Icons.content_cut_rounded,
                title: "Cortar / Mover",
                desc: canCut
                    ? "Traslada al nuevo y retira de aquí al guardar."
                    : "Bloqueado. Este producto solo tiene 1 variante.",
                isSelected: _mode == ProductExtractionMode.cut,
                isEnabled: canCut,
                isDark: isDark,
                onTap: canCut
                    ? () => _onModeChanged(ProductExtractionMode.cut)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          "NOMBRE DEL NUEVO PRODUCTO",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.edit_outlined, size: 18),
            hintText: "Ej. ${_generateCombinedName()}",
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? Colors.teal.shade300 : Colors.teal,
                width: 1.5,
              ),
            ),
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildNameChip(
              label: "Padre + Variante",
              onTap: () =>
                  _refreshState(() => _nameCtrl.text = _generateCombinedName()),
              isDark: isDark,
            ),
            if (_specificName.isNotEmpty)
              _buildNameChip(
                label: "Solo Variante: $_specificName",
                onTap: () =>
                    _refreshState(() => _nameCtrl.text = _specificName),
                isDark: isDark,
              ),
            _buildNameChip(
              label: "Solo Padre",
              onTap: () => _refreshState(
                () => _nameCtrl.text = widget.originProductName.trim(),
              ),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required ProductExtractionMode mode,
    required IconData icon,
    required String title,
    required String desc,
    required bool isSelected,
    required bool isEnabled,
    required bool isDark,
    required VoidCallback? onTap,
  }) {
    final activeColor = mode == ProductExtractionMode.cut
        ? Colors.amber.shade700
        : Colors.teal;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? activeColor.withValues(alpha: 0.18)
                      : activeColor.withValues(alpha: 0.08))
                : (isDark ? Colors.white10 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.white12 : Colors.grey.shade300),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: isSelected ? activeColor : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.25,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.teal[200] : Colors.teal[800],
          ),
        ),
      ),
    );
  }
}
