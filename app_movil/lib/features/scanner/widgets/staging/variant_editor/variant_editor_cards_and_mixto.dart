part of '../variant_editor_row.dart';

mixin _VariantEditorCardsAndMixtoMixin on _VariantEditorRowStateBase {
  @override
  Widget _buildMixtoVariantToggle() {
    final bool isShared = widget.variant.usaStockCompartido;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1F1F2B) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (!isShared) {
                  widget.provider.toggleVariantSharedStock(
                    widget.variant.uuidTemporal,
                  );
                  _initControllers();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isShared
                      ? (widget.isDark ? Colors.teal[800] : Colors.teal[600])
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 14,
                      color: isShared
                          ? Colors.white
                          : (widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Compartido",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isShared
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isShared
                                ? Colors.white
                                : (widget.isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (isShared) {
                  widget.provider.toggleVariantSharedStock(
                    widget.variant.uuidTemporal,
                  );
                  _initControllers();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: !isShared
                      ? (widget.isDark
                            ? Colors.blueGrey[800]
                            : Colors.blueGrey[600])
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: !isShared
                          ? Colors.white
                          : (widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Stock Propio",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: !isShared
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !isShared
                                ? Colors.white
                                : (widget.isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildSharedCupoSection({required int maxFormable}) {
    final int currentCupo = widget.variant.cupoMaximoVariante ?? maxFormable;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.teal.withValues(alpha: 0.08)
            : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isDark
              ? Colors.teal.withValues(alpha: 0.25)
              : Colors.teal.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: widget.isDark ? Colors.tealAccent : Colors.teal.shade800,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Gestión de Cupo (Stock Vendible)",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark
                        ? Colors.tealAccent
                        : Colors.teal.shade900,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  "Máx. Formable: $maxFormable ${_unidadVentaCtrl.text}",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.teal[200] : Colors.teal[800],
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Stock disponible para vender (máximo $maxFormable):",
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              SizedBox(
                width: 75,
                height: 30,
                child: TextFormField(
                  key: ValueKey(
                    'cupo_${widget.variant.uuidTemporal}_$maxFormable',
                  ),
                  initialValue: currentCupo.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    filled: true,
                    fillColor: widget.isDark
                        ? const Color(0xFF14141C)
                        : Colors.white,
                  ),
                  onChanged: (text) {
                    int? val = int.tryParse(text);
                    if (val != null) {
                      if (val > maxFormable) val = maxFormable;
                      if (val < 0) val = 0;
                      widget.variant.cupoMaximoVariante = val;
                    } else {
                      widget.variant.cupoMaximoVariante = null;
                    }
                    widget.provider.notifyUIUpdate();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildVariantCards() {
    final alternatives =
        widget.group.matchProducto.datos?.availablePresentations ?? [];
    if (alternatives.isEmpty) return const SizedBox.shrink();

    int? selectedId =
        widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE"
        ? -1
        : widget.variant.matchPresentacion.datos?.id;
    if (selectedId != -1 &&
        selectedId != null &&
        !alternatives.any((p) => p['id'] == selectedId)) {
      selectedId = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.style_outlined,
                size: 14,
                color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Variante Vinculada para esta Compra:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            itemCount: alternatives.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) {
              if (i == alternatives.length) {
                bool isSelected = selectedId == -1;
                return GestureDetector(
                  onTap: () {
                    widget.provider.switchVariantToNew(
                      widget.variant.uuidTemporal,
                    );
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _initControllers();
                    });
                  },
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (widget.isDark
                                ? Colors.blue.withValues(alpha: 0.2)
                                : Colors.blue.shade50)
                          : (widget.isDark
                                ? const Color(0xFF1A1A24)
                                : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (widget.isDark
                                  ? Colors.blue
                                  : Colors.blue.shade400)
                            : (widget.isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add,
                            size: 18,
                            color: widget.isDark
                                ? Colors.blue[300]
                                : Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Nueva",
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.blue[300]
                                  : Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              var p = alternatives[i];
              bool isSelected = selectedId == p['id'];
              String pName =
                  p['nombre_completo']?.toString() ??
                  p['nombre_especifico']?.toString() ??
                  '';
              if (pName.isEmpty || pName == 'null') pName = 'General';
              double pVenta = (p['precio_venta'] is num)
                  ? (p['precio_venta'] as num).toDouble()
                  : 0.0;
              double? pOferta = (p['precio_oferta'] is num)
                  ? (p['precio_oferta'] as num).toDouble()
                  : null;

              return GestureDetector(
                onTap: () {
                  widget.provider.switchVariantLink(
                    widget.variant.uuidTemporal,
                    p['id'],
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _initControllers();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 192,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (widget.isDark
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.green.shade50)
                        : (widget.isDark
                              ? const Color(0xFF23232F)
                              : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? (widget.isDark ? Colors.green[400]! : Colors.green)
                          : (widget.isDark
                                ? Colors.white10
                                : Colors.grey.shade200),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      if (!widget.isDark && !isSelected)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        pName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected
                              ? (widget.isDark
                                    ? Colors.green[300]
                                    : Colors.green[800])
                              : (widget.isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${p['unidad'] ?? 'Unidad'} (x${p['factor_conversion'] ?? 1})",
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              "Stock: ${p['stock_actual'] ?? 0}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (pOferta != null)
                                    Text(
                                      AppCurrency.format(pVenta),
                                      style: TextStyle(
                                        fontSize: 9,
                                        decoration: TextDecoration.lineThrough,
                                        color: widget.isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (pOferta != null)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            "PROMO",
                                            style: TextStyle(
                                              fontSize: 7,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        AppCurrency.format(pOferta ?? pVenta),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: pOferta != null
                                              ? Colors.purple[400]
                                              : (widget.isDark
                                                    ? Colors.blue[300]
                                                    : Colors.blue[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
