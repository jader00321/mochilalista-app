part of '../product_detail_modal.dart';

extension _ProductDetailHeaderAndVariantsExtension on _ProductDetailModalState {
  Widget _buildHeaderAndDescription({
    required BuildContext context,
    required Product prod,
    required CatalogProvider? catalogProv,
    required String brandName,
    required String imageUrl,
    required String imageTag,
    required bool isDark,
    required Color textColor,
    required TextTheme textTheme,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. CABECERA: IMAGEN + TÍTULOS (AISLADO DE LA 'X')
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (imageUrl.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullScreenImageViewer(
                        imageUrl: imageUrl,
                        tag: imageTag,
                      ),
                    ),
                  );
                }
              },
              child: Hero(
                tag: imageTag,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: UniversalImage(
                        path: imageUrl,
                        productName: prod.nombre,
                        categoryName: catalogProv?.getCategoryName(
                          prod.categoriaId,
                        ),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Margen derecho de 44dp garantiza 0 colisiones con el botón 'X'
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 44.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (brandName.isNotEmpty)
                      Text(
                        brandName.toUpperCase(),
                        style: textTheme.labelLarge?.copyWith(
                          color: isDark
                              ? Colors.indigo[300]
                              : Colors.indigo[800],
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    RichText(
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "${prod.nombre} ",
                            style: textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          if (_currentPres.nombreEspecifico != null &&
                              _currentPres.nombreEspecifico!.isNotEmpty)
                            TextSpan(
                              text: _currentPres.nombreEspecifico!,
                              style: textTheme.titleLarge?.copyWith(
                                color: isDark
                                    ? Colors.teal[300]
                                    : Colors.teal[700],
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (prod.descripcion != null && prod.descripcion!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            prod.descripcion!,
            style: textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariantSelectorSection({
    required Product prod,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              _refreshState(() => _showVariantSelector = !_showVariantSelector),
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
                      const SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Seleccionar Variante / Presentación",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : Colors.black87,
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
                          "${prod.presentaciones.length}",
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
                  mainAxisSize: MainAxisSize.min,
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
          if (prod.hasSharedStock)
            _buildStockModeInfoBanner(prod: prod, isDark: isDark),
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
                children: prod.presentaciones.map((p) {
                  final isSelected = p.id == _currentPres.id;
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
                  final vendibleUnits = _computeMaxStock(p);
                  final bool isOutOfStock = vendibleUnits <= 0;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
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
                                style: TextStyle(
                                  fontSize: 13,
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
                                  color: isOutOfStock
                                      ? Colors.red
                                      : (vendibleUnits < 10
                                            ? Colors.orange
                                            : Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${p.unidadVenta ?? 'Und'}$factorStr · ${AppCurrency.format(p.precioVentaFinal)} · ${isOutOfStock ? 'Agotado' : '$vendibleUnits disp.'}",
                            style: TextStyle(
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
                      onSelected: (v) => v ? _selectPresentation(p) : null,
                      selectedColor: isDark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue[100],
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.grey[100],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.blue[300] : Colors.blue[900])
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
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
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildStockModeInfoBanner({
    required Product prod,
    required bool isDark,
  }) {
    if (_currentPres.usaStockCompartido) {
      final pool = prod.stockCompartido > 0
          ? prod.stockCompartido
          : _currentPres.stockActual;
      final factor = _currentPres.unidadesPorVenta > 0
          ? _currentPres.unidadesPorVenta
          : 1;
      final maxPhysical = pool ~/ factor;
      final cupo = _currentPres.cupoMaximoVariante;
      final cupoStr = cupo != null ? " · Cupo: $cupo disp." : "";
      final modoStr = prod.modoStock == 'MIXTO' ? 'Mixto' : 'Compartido';
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                "Inventario base compartido: $pool und. (= máx. $maxPhysical ${_currentPres.unidadVenta ?? 'Und'}$cupoStr) · $modoStr",
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

    final factor = _currentPres.unidadesPorVenta > 0
        ? _currentPres.unidadesPorVenta
        : 1;
    final ownStock = _currentPres.stockActual ~/ factor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              "Stock Propio disponible: $ownStock ${_currentPres.unidadVenta ?? 'Und'} · Mixto",
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
