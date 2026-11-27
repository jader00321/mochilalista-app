part of '../bundle_builder_screen.dart';

mixin _BundleBuilderProductPickerMixin on _BundleBuilderScreenStateBase {
  Widget _buildSelectedContentSection(bool isDark, InventoryProvider invProv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: _tourKeys.productSelectionKey,
          children: [
            const Expanded(
              child: Text(
                "Contenido del Paquete",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _showAddProductModal,
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              label: const Text(
                "Agregar",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[300]!,
              ),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "El paquete está vacío",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "Agrega los productos que conformarán esta oferta.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ..._selectedItems.asMap().entries.map(
          (entry) =>
              _buildSelectedItemCard(entry.key, entry.value, isDark, invProv),
        ),
      ],
    );
  }

  Widget _buildSelectedItemCard(
    int idx,
    BundleItemModel item,
    bool isDark,
    InventoryProvider invProv,
  ) {
    final prodWrap = invProv.items
        .where((p) => p.presentation.id == item.presentacionId)
        .firstOrNull;

    if (prodWrap == null) {
      return Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 12),
        color: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Producto no disponible",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "Este producto fue eliminado del inventario.",
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(idx),
              ),
            ],
          ),
        ),
      );
    }

    final String fullName =
        (prodWrap.product.marcaNombre != null &&
                prodWrap.product.marcaNombre!.isNotEmpty &&
                prodWrap.product.marcaNombre!.toLowerCase() != 'sin marca'
            ? '${prodWrap.product.marcaNombre} '
            : '') +
        prodWrap.product.nombre +
        (prodWrap.presentation.nombreEspecifico != null &&
                prodWrap.presentation.nombreEspecifico!.isNotEmpty
            ? ' - ${prodWrap.presentation.nombreEspecifico}'
            : '');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 50,
                height: 50,
                color: isDark ? Colors.white10 : Colors.grey[200],
                child: prodWrap.presentation.imagenUrl != null
                    ? UniversalImage(
                        path: prodWrap.presentation.imagenUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        productName: prodWrap.product.nombre,
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          prodWrap.presentation.unidadVenta ?? "UND",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Costo: ${AppCurrency.format(prodWrap.presentation.costoUnitarioCalculado ?? 0)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        "Normal: ${AppCurrency.format(prodWrap.effectivePrice)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue[300] : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C3E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (item.cantidadRequerida > 1) {
                        setState(() {
                          _selectedItems[idx] = BundleItemModel(
                            id: item.id,
                            paqueteId: item.paqueteId,
                            productoId: item.productoId,
                            presentacionId: item.presentacionId,
                            cantidadRequerida: item.cantidadRequerida - 1,
                            precioOriginalUnitario: item.precioOriginalUnitario,
                          );
                          _autoSuggestNameAndPrice();
                        });
                      } else {
                        _removeItem(idx);
                      }
                    },
                  ),
                  Text(
                    "${item.cantidadRequerida}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _selectedItems[idx] = BundleItemModel(
                          id: item.id,
                          paqueteId: item.paqueteId,
                          productoId: item.productoId,
                          presentacionId: item.presentacionId,
                          cantidadRequerida: item.cantidadRequerida + 1,
                          precioOriginalUnitario: item.precioOriginalUnitario,
                        );
                        _autoSuggestNameAndPrice();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductModal() {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final invProv = Provider.of<InventoryProvider>(context);

            final filteredCatalog = invProv.items.where((p) {
              return p.product.nombre.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (p.presentation.codigoBarras?.contains(_searchQuery) ??
                      false);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Agregar Producto",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: "Buscar en catálogo",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2C2C3E)
                          : Colors.grey[100],
                    ),
                    onChanged: (v) => setModalState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredCatalog.length,
                      itemBuilder: (context, i) {
                        final p = filteredCatalog[i];
                        final isAlreadyAdded = _selectedItems.any(
                          (item) => item.presentacionId == p.presentation.id,
                        );
                        final displayName =
                            (p.product.marcaNombre != null &&
                                    p.product.marcaNombre!.isNotEmpty &&
                                    p.product.marcaNombre!.toLowerCase() !=
                                        'sin marca'
                                ? '${p.product.marcaNombre} '
                                : '') +
                            p.product.nombre +
                            (p.presentation.nombreEspecifico != null &&
                                    p.presentation.nombreEspecifico!.isNotEmpty
                                ? ' - ${p.presentation.nombreEspecifico}'
                                : '');
                        final unidadVenta =
                            p.presentation.unidadVenta ?? 'Unidad';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: ClipOval(
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: p.presentation.imagenUrl != null
                                    ? UniversalImage(
                                        path: p.presentation.imagenUrl,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        productName: p.product.nombre,
                                      )
                                    : Container(
                                        color: isDark
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : Colors.blue[50],
                                        child: const Icon(
                                          Icons.inventory_2,
                                          color: Colors.blue,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    unidadVenta,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Stock: ${p.presentation.stockActual} | Venta: ${AppCurrency.format(p.effectivePrice)}",
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: isAlreadyAdded
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: Colors.blue,
                                      size: 28,
                                    ),
                                    onPressed: () {
                                      _addItem(p);
                                      AppFeedbackHelper.showSuccess(
                                        context,
                                        "Agregado al paquete",
                                      );
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _searchQuery = "");
    });
  }

  @override
  void _showInfoTooltip(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: Icon(icon, size: 32, color: Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Entendido",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
