part of '../product_edit_operations.dart';

ProductEditLoadedData _loadInitialDataImpl({
  required Product product,
  required InventoryProvider invProv,
  required TextEditingController nameCtrl,
  required TextEditingController descCtrl,
  required TextEditingController imgUrlCtrl,
  required TextEditingController parentBarcodeCtrl,
  required List<Map<String, dynamic>> presentationControllers,
  required Map<String, GlobalKey> presentationKeys,
  int? initialPresentationId,
}) {
  nameCtrl.text = product.nombre;
  descCtrl.text = product.descripcion ?? "";
  imgUrlCtrl.text = product.imagenUrl ?? "";
  parentBarcodeCtrl.text = product.codigoBarras ?? "";

  final int? categoryId =
      invProv.categories.any((c) => c.id == product.categoriaId)
      ? product.categoriaId
      : (product.categoriaId > 0 ? product.categoriaId : null);
  String? categoryName;
  if (categoryId != null) {
    final c = invProv.categories.where((c) => c.id == categoryId).firstOrNull;
    categoryName = c?.nombre;
  }

  final int? brandId = product.marcaId;
  String? brandName;
  if (brandId != null) {
    final b = invProv.brands.where((b) => b.id == brandId).firstOrNull;
    brandName = b?.nombre ?? product.marcaNombre;
  }

  final List<ProductPresentation> sortedList = List.from(
    product.presentaciones,
  );
  sortedList.sort((a, b) {
    if (a.esDefault && !b.esDefault) {
      return -1;
    }
    if (!a.esDefault && b.esDefault) {
      return 1;
    }
    if (a.orden != b.orden) {
      return a.orden.compareTo(b.orden);
    }
    return (a.id ?? 0).compareTo(b.id ?? 0);
  });

  presentationControllers.clear();
  presentationKeys.clear();
  String? targetKeyToScroll;

  for (final pres in sortedList) {
    int? safeProvId = pres.proveedorId;
    if (safeProvId != null &&
        !invProv.providers.any((pr) => pr.id == safeProvId)) {
      safeProvId = null;
    }

    final String presKeyId = pres.id.toString();
    presentationKeys[presKeyId] = GlobalKey();

    final bool isTarget =
        initialPresentationId != null && pres.id == initialPresentationId;
    if (isTarget) {
      targetKeyToScroll = presKeyId;
    }

    final String initialStockStr = _computePresentationStockText(product, pres);
    final bool isFixedDiscount =
        pres.tipoDescuento == 'monto' || pres.tipoDescuento == 'fijo';
    final bool hasActiveDiscount =
        (pres.precioOferta != null &&
            pres.precioOferta! > 0 &&
            pres.precioOferta! < pres.precioVentaFinal) ||
        (pres.valorDescuento != null &&
            pres.valorDescuento! > 0 &&
            pres.tipoDescuento != null &&
            pres.tipoDescuento != 'ninguno');

    final map = ProductControllerFactory.createNewControllerMap(
      id: presKeyId,
      dbId: pres.id,
      isDefault: pres.esDefault,
      isExpanded: isTarget || pres.esDefault,
      isEditMode: true,
      specificName: pres.nombreEspecifico ?? "",
      unidadVenta: pres.unidadVenta ?? "Unidad",
      unidadesVenta: pres.unidadesPorVenta.toString(),
      costoPres: pres.costoUnitarioCalculado?.toStringAsFixed(2) ?? "0.00",
      margen: pres.factorGananciaVenta?.toStringAsFixed(2) ?? "1.35",
      precioVenta: pres.precioVentaFinal.toStringAsFixed(2),
      stockInicial: initialStockStr,
      stockFinal: initialStockStr,
      barcode: pres.codigoBarras ?? "",
      providerId: safeProvId,
      estado: pres.estado,
      unidadesLote: pres.unidadesPorLote.toString(),
      cantCompra: pres.cantidadUmpComprada?.toStringAsFixed(2) ?? "",
      totalPago: pres.totalPagoLote?.toStringAsFixed(2) ?? "",
      umpCompra: pres.umpCompra ?? "",
      desc: pres.descripcion ?? "",
      image: pres.imagenUrl ?? "",
      descuentoActivo: hasActiveDiscount,
      valorDescuento: _computeInitialDiscountValue(pres, isFixedDiscount),
      tipoDescuento: isFixedDiscount ? 'fijo' : 'porcentaje',
      precioOfertaExacto: pres.precioOferta,
      usaStockCompartido: pres.usaStockCompartido,
      cupoMaximoVariante: pres.cupoMaximoVariante,
    );

    presentationControllers.add(map);
  }

  return ProductEditLoadedData(
    categoryId: categoryId,
    categoryName: categoryName,
    brandId: brandId,
    brandName: brandName,
    targetKeyToScroll: targetKeyToScroll,
  );
}

String _computePresentationStockText(
  Product product,
  ProductPresentation pres,
) {
  final int factorV = pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1;
  if (pres.usaStockCompartido) {
    final int baseEff = product.stockCompartido > 0
        ? product.stockCompartido
        : pres.stockActual;
    final int maxF = baseEff ~/ factorV;
    if (pres.cupoMaximoVariante != null && pres.cupoMaximoVariante! > 0) {
      return (pres.cupoMaximoVariante! <= maxF
              ? pres.cupoMaximoVariante!
              : maxF)
          .toString();
    }
    return maxF.toString();
  }
  return (pres.stockActual ~/ factorV).toString();
}

String _computeInitialDiscountValue(
  ProductPresentation pres,
  bool isFixedDiscount,
) {
  if (!isFixedDiscount) {
    if (pres.valorDescuento != null && pres.valorDescuento! > 0) {
      if ((pres.valorDescuento! - pres.valorDescuento!.roundToDouble()).abs() <
          0.001) {
        return pres.valorDescuento!.round().toString();
      }
      return pres.valorDescuento!.toStringAsFixed(2);
    }
    if (pres.precioOferta != null && pres.precioVentaFinal > 0) {
      final double p =
          ((pres.precioVentaFinal - pres.precioOferta!) /
              pres.precioVentaFinal) *
          100;
      return p.round().toString();
    }
    return "";
  }

  if (pres.precioOferta != null && pres.precioOferta! > 0) {
    return pres.precioOferta!.toStringAsFixed(2);
  }
  if (pres.valorDescuento != null && pres.valorDescuento! > 0) {
    return pres.valorDescuento!.toStringAsFixed(2);
  }
  return "";
}

void _addPresentationImpl({
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
  required int? generalProviderId,
  required Map<int, String> deferredProviderNames,
}) {
  final String newId = UniqueKey().toString();
  keys[newId] = GlobalKey();

  final map = ProductControllerFactory.createNewControllerMap(
    id: newId,
    dbId: null,
    isDefault: controllers.isEmpty,
    isExpanded: true,
    isEditMode: true,
    providerId: generalProviderId == -2 ? null : generalProviderId,
    deferredProviderName: generalProviderId != null && generalProviderId < 0
        ? deferredProviderNames[generalProviderId]
        : null,
  );

  controllers.add(map);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final key = keys[newId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  });
}

void _clonePresentationImpl({
  required int index,
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
  required BuildContext context,
}) {
  final source = controllers[index];
  final String newId = UniqueKey().toString();
  keys[newId] = GlobalKey();

  final newMap = ProductControllerFactory.cloneControllerMap(
    source: source,
    newId: newId,
  );

  controllers.insert(index + 1, newMap);
  HapticFeedback.mediumImpact();
  AppFeedbackHelper.showSnackBar(
    context,
    "Variante clonada exitosamente",
    backgroundColor: Colors.teal,
    duration: const Duration(seconds: 2),
  );
}

void _setDefaultImpl({
  required int index,
  required List<Map<String, dynamic>> controllers,
  required BuildContext context,
}) {
  if (index < 0 || index >= controllers.length) {
    return;
  }
  for (int i = 0; i < controllers.length; i++) {
    controllers[i]['isDefault'] = (i == index);
  }
  final item = controllers.removeAt(index);
  controllers.insert(0, item);
  item['isExpanded'] = true;
  HapticFeedback.mediumImpact();
  AppFeedbackHelper.showSnackBar(
    context,
    "Presentación Principal actualizada",
    backgroundColor: Colors.teal,
    duration: const Duration(seconds: 2),
  );
}

void _moveUpImpl({
  required int index,
  required List<Map<String, dynamic>> controllers,
}) {
  if (index <= 0) {
    return;
  }
  final item = controllers.removeAt(index);
  controllers.insert(index - 1, item);
  HapticFeedback.selectionClick();
}

void _moveDownImpl({
  required int index,
  required List<Map<String, dynamic>> controllers,
}) {
  if (index >= controllers.length - 1) {
    return;
  }
  final item = controllers.removeAt(index);
  controllers.insert(index + 1, item);
  HapticFeedback.selectionClick();
}

Future<bool> _updateGeneralProviderImpl({
  required BuildContext context,
  required int? newId,
  required String? newName,
  required bool isDark,
  required int? currentGeneralProviderId,
  required List<Map<String, dynamic>> controllers,
}) async {
  if (currentGeneralProviderId != -2 && controllers.length <= 1) {
    _applyProviderToAllControllers(controllers, newId, newName);
    return true;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "¿Sobreescribir Proveedores?",
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        "Esta acción cambiará el proveedor de TODAS las presentaciones, perdiendo cualquier proveedor específico.",
        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("Sí, Aplicar"),
        ),
      ],
    ),
  );

  if (confirm == true) {
    _applyProviderToAllControllers(controllers, newId, newName);
    return true;
  }
  return false;
}

void _applyProviderToAllControllers(
  List<Map<String, dynamic>> controllers,
  int? newId,
  String? newName,
) {
  for (final c in controllers) {
    c['providerId'] = newId;
    if (newId != null && newId < 0 && newName != null) {
      c['deferredProviderName'] = newName;
    } else {
      c.remove('deferredProviderName');
    }
  }
}
