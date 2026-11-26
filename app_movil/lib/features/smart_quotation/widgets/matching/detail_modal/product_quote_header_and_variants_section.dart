part of '../product_quote_detail_modal.dart';

mixin _ProductQuoteHeaderAndVariantsMixin on _ProductQuoteDetailStateBase {
  @override
  Widget _buildNameChangedBanner(String snapshot, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.history,
              size: 18,
              color: isDark ? Colors.orange[300] : Colors.orange[800],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Extraído originalmente como:\n$snapshot",
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.orange[300] : Colors.orange[800],
                fontStyle: FontStyle.italic,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildProductHeader({
    required Product productDisplay,
    required String? img,
    required bool hasRealImage,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
    required bool isStockEmpty,
    required int realStock,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: hasRealImage
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrl: img!,
                        tag: "matching_${_selectedPresentation.id}",
                      ),
                    ),
                  );
                }
              : null,
          child: Hero(
            tag: "matching_${_selectedPresentation.id}",
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    border: Border.all(
                      color: isDark ? Colors.transparent : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: UniversalImage(
                      path: img,
                      productName: productDisplay.nombre,
                      categoryName: _currentCategoryName.isNotEmpty
                          ? _currentCategoryName
                          : widget.brandName,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (hasRealImage) ...[
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                  const Icon(Icons.zoom_in, color: Colors.white, size: 32),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.brandName != null && widget.brandName!.isNotEmpty)
                Text(
                  widget.brandName!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.indigo[300] : Colors.indigo[800],
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              RichText(
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "${productDisplay.nombre} ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.2,
                      ),
                    ),
                    if (_selectedPresentation.nombreEspecifico != null &&
                        _selectedPresentation.nombreEspecifico!.isNotEmpty)
                      TextSpan(
                        text: _selectedPresentation.nombreEspecifico!,
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.teal[300] : Colors.teal[700],
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_selectedPresentation.unidadVenta ?? 'Unidad'} (x${_selectedPresentation.unidadesPorVenta})",
                      style: textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),
                  if (_currentCategoryName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _currentCategoryName,
                        style: textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  isStockEmpty
                      ? "Agotado (0)"
                      : "Stock disponible: $realStock ${_selectedPresentation.unidadVenta ?? 'Unidad'}",
                  style: textTheme.bodySmall?.copyWith(
                    color: isStockEmpty
                        ? (isDark ? Colors.red[400] : Colors.red)
                        : (isDark ? Colors.green[400] : Colors.green),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget _buildVariantSelectorSection({
    required bool isClient,
    required bool isDark,
    required TextTheme textTheme,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () =>
              setState(() => _showVariantSelector = !_showVariantSelector),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_customize_outlined,
                        size: 18,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Seleccionar Variante / Presentación",
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue.withValues(alpha: 0.25)
                              : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${_fullProduct!.presentaciones.length}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[200] : Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      _showVariantSelector ? "Ocultar" : "Ver otras",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _showVariantSelector
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_showVariantSelector) ...[
          if (_fullProduct != null && _fullProduct!.hasSharedStock)
            _buildStockModeInfoBanner(isDark),
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.94, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _fullProduct!.presentaciones.map((p) {
                  final isSelected = p.id == _selectedPresentation.id;
                  final realVariantStock = _getRealStock(p);
                  final isOutOfStockVariant = realVariantStock <= 0;
                  final isDisabled = isClient && isOutOfStockVariant;
                  final specName =
                      (p.nombreEspecifico != null &&
                          p.nombreEspecifico!.trim().isNotEmpty)
                      ? p.nombreEspecifico!.trim()
                      : (p.esDefault
                            ? "Principal"
                            : (p.unidadVenta ?? "Variante"));
                  final factorStr = p.unidadesPorVenta > 1
                      ? " (x${p.unidadesPorVenta})"
                      : "";
                  final stockStr = isOutOfStockVariant
                      ? "Agotado"
                      : "$realVariantStock disp.";

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                specName,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                  color: isSelected
                                      ? (isDark
                                            ? Colors.blue[200]
                                            : Colors.blue[900])
                                      : (isDark
                                            ? Colors.white
                                            : Colors.black87),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 5),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOutOfStockVariant
                                      ? Colors.red
                                      : (realVariantStock < 10
                                            ? Colors.orange
                                            : Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${p.unidadVenta ?? 'Und'}$factorStr · ${AppCurrency.format(p.precioVentaFinal)} · $stockStr",
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              color: isSelected
                                  ? (isDark
                                        ? Colors.blue[100]
                                        : Colors.blue[800])
                                  : (isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: isDisabled
                          ? null
                          : (v) {
                              if (v) {
                                setState(() {
                                  _selectedPresentation = p;
                                  _initializePricing();

                                  if (isClient &&
                                      _quantity > realVariantStock) {
                                    _quantity = realVariantStock > 0
                                        ? realVariantStock
                                        : 1;
                                    _qtyCtrl.text = _quantity.toString();
                                  }
                                });
                              }
                            },
                      selectedColor: isDark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue[100],
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.grey[100],
                      labelStyle: TextStyle(
                        color: isDisabled
                            ? (isDark ? Colors.grey[600] : Colors.grey[400])
                            : (isSelected
                                  ? (isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[900])
                                  : textColor),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStockModeInfoBanner(bool isDark) {
    if (_selectedPresentation.usaStockCompartido) {
      final pool = _fullProduct!.stockCompartido;
      final factor = _selectedPresentation.unidadesPorVenta > 0
          ? _selectedPresentation.unidadesPorVenta
          : 1;
      final maxPhysical = pool ~/ factor;
      final cupo = _selectedPresentation.cupoMaximoVariante;
      final cupoStr = cupo != null ? " · Cupo: $cupo disp." : "";
      final modoStr = _fullProduct!.modoStock == 'MIXTO'
          ? 'Mixto'
          : 'Compartido';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.blue.shade700 : const Color(0xFF93C5FD),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hub_rounded,
              size: 16,
              color: isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Inventario base compartido: $pool und. (= máx. $maxPhysical ${_selectedPresentation.unidadVenta ?? 'Und'}$cupoStr) · $modoStr",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue[200] : const Color(0xFF1E40AF),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final factor = _selectedPresentation.unidadesPorVenta > 0
        ? _selectedPresentation.unidadesPorVenta
        : 1;
    final ownStock = _selectedPresentation.stockActual ~/ factor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.teal.withValues(alpha: 0.15)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.teal.shade700 : const Color(0xFF86EFAC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 16,
            color: isDark ? Colors.teal[300] : const Color(0xFF166534),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Stock Propio disponible: $ownStock ${_selectedPresentation.unidadVenta ?? 'Und'} · Mixto",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.teal[200] : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
