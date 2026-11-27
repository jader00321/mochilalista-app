part of '../product_edit_operations.dart';

Future<bool> _saveEditedProductImpl({
  required BuildContext context,
  required GlobalKey<FormState> formKey,
  required Product productToEdit,
  required TextEditingController nameCtrl,
  required TextEditingController descCtrl,
  required TextEditingController imgUrlCtrl,
  required TextEditingController parentBarcodeCtrl,
  required int? selectedBrandId,
  required String? selectedBrandName,
  required int? selectedCategoryId,
  required String? selectedCategoryName,
  required List<Map<String, dynamic>> controllers,
  required List<int> idsToDelete,
  required String modoStock,
  required int stockCompartido,
  required double costoBase,
  Map<String, GlobalKey>? keys,
}) async {
  if (!formKey.currentState!.validate()) {
    AppFeedbackHelper.showSnackBar(
      context,
      "Por favor corrige los errores antes de guardar.",
      backgroundColor: Colors.red,
    );
    return false;
  }

  if (controllers.isEmpty) {
    AppFeedbackHelper.showSnackBar(
      context,
      "Debe haber al menos una presentación.",
      backgroundColor: Colors.red,
    );
    return false;
  }

  if (modoStock == 'COMPARTIDO' || modoStock == 'MIXTO') {
    final sharedControllers = controllers.where((c) {
      if (modoStock == 'COMPARTIDO') {
        return true;
      }
      return c['usaStockCompartido'] == true;
    }).toList();

    if (sharedControllers.isNotEmpty && stockCompartido > 0) {
      final allZeroFormable = sharedControllers.every((c) {
        final factor =
            int.tryParse(
              (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
            ) ??
            1;
        final safeFactor = factor <= 0 ? 1 : factor;
        return stockCompartido < safeFactor;
      });

      if (allZeroFormable) {
        AppFeedbackHelper.showSnackBar(
          context,
          "El stock compartido no alcanza para formar ningún paquete. Agrega una variante por Unidad o ajusta el inventario.",
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        );
        return false;
      }
    }
  }

  for (final c in controllers) {
    final bool isShared =
        modoStock == 'COMPARTIDO' ||
        (modoStock == 'MIXTO' && c['usaStockCompartido'] == true);

    if (!isShared && !_validateOwnStockVariant(context, c, keys)) {
      return false;
    }
  }

  final bool hasDefault = controllers.any((c) => c['isDefault'] == true);
  if (!hasDefault) {
    controllers.first['isDefault'] = true;
  }

  final presentacionesFinales = ProductFormMapper.toPresentations(
    controllers: controllers,
    defaultDesc: descCtrl.text,
    defaultImg: imgUrlCtrl.text,
    defaultBarcode: parentBarcodeCtrl.text,
    modoStock: modoStock,
    stockCompartido: stockCompartido,
  );

  final provider = Provider.of<InventoryProvider>(context, listen: false);
  final bool isBrandDef = selectedBrandId != null && selectedBrandId < 0;
  final bool isCatDef = selectedCategoryId != null && selectedCategoryId < 0;

  final success = await provider.editFullProduct(
    productId: productToEdit.id,
    nombre: nameCtrl.text,
    descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
    marcaId: isBrandDef
        ? null
        : (selectedBrandId == 0 ? null : selectedBrandId),
    deferredBrandName: isBrandDef ? selectedBrandName : null,
    categoriaId: isCatDef
        ? null
        : (selectedCategoryId == 0 ? null : selectedCategoryId),
    deferredCategoryName: isCatDef ? selectedCategoryName : null,
    estado: productToEdit.estado,
    imagenUrl: imgUrlCtrl.text.trim().isEmpty ? null : imgUrlCtrl.text.trim(),
    codigoBarras: parentBarcodeCtrl.text.trim().isEmpty
        ? null
        : parentBarcodeCtrl.text.trim(),
    presentaciones: presentacionesFinales,
    idsToDelete: idsToDelete,
    modoStock: modoStock,
    stockCompartido: stockCompartido,
    costoBase: costoBase,
  );

  if (success && context.mounted) {
    await ProductSaveSuccessDialog.show(
      context: context,
      productName: nameCtrl.text.trim(),
      presentationCount: presentacionesFinales.length,
      mode: ProductSaveDialogMode.edit,
    );
    return true;
  } else if (context.mounted) {
    final msg = provider.errorMessage.isNotEmpty
        ? provider.errorMessage
        : "No se pudieron guardar los cambios";
    AppFeedbackHelper.showSnackBar(
      context,
      "Error: $msg",
      backgroundColor: Colors.red,
    );
  }

  return false;
}

bool _validateOwnStockVariant(
  BuildContext context,
  Map<String, dynamic> c,
  Map<String, GlobalKey>? keys,
) {
  final int factor =
      int.tryParse(
        (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
      ) ??
      1;
  final int safeFactor = factor <= 0 ? 1 : factor;
  if (safeFactor <= 1) {
    return true;
  }

  final String specific =
      (c['specific'] as TextEditingController?)?.text.trim() ?? '';
  final String uVenta =
      (c['unidadVenta'] as TextEditingController?)?.text.trim() ?? 'Unidad';
  final String variantName = specific.isNotEmpty ? specific : uVenta;

  StockValidationResult? validation =
      c['stockValidation'] as StockValidationResult?;
  if (validation == null) {
    int baseUnits = 0;
    final ajusteText =
        (c['ajusteBase'] as TextEditingController?)?.text.trim() ?? '';
    if (ajusteText.isNotEmpty) {
      baseUnits = int.tryParse(ajusteText) ?? 0;
    } else {
      final engine = c['mathEngine'] as PresentationMathEngine?;
      if (engine != null) {
        baseUnits = engine.originalBaseStock;
      } else {
        final visual =
            int.tryParse(
              (c['stockFinal'] as TextEditingController?)?.text ?? '0',
            ) ??
            0;
        baseUnits = visual * safeFactor;
      }
    }
    validation = UnitCatalogService.validateStockForUnit(
      totalUnitsBase: baseUnits,
      presentationFactor: safeFactor,
      baseUnitCost: 0.0,
      unitName: uVenta,
    );
  }

  if (validation.status == StockValidationStatus.deficit) {
    _focusVariantAndShowSnack(
      context: context,
      variantKey: keys?[c['id']],
      message: "'$variantName': ${validation.userMessage(uVenta, safeFactor)}",
      color: Colors.red,
    );
    return false;
  }

  if (validation.status == StockValidationStatus.hasLeftover &&
      c['leftoverCreated'] != true) {
    _focusVariantAndShowSnack(
      context: context,
      variantKey: keys?[c['id']],
      message: "'$variantName': ${validation.userMessage(uVenta, safeFactor)}",
      color: Colors.orange,
    );
    return false;
  }

  return true;
}

void _focusVariantAndShowSnack({
  required BuildContext context,
  required GlobalKey? variantKey,
  required String message,
  required Color color,
}) {
  if (variantKey?.currentContext != null) {
    Scrollable.ensureVisible(
      variantKey!.currentContext!,
      duration: const Duration(milliseconds: 300),
    );
  }
  AppFeedbackHelper.showSnackBar(
    context,
    message,
    backgroundColor: color,
    duration: const Duration(seconds: 4),
  );
}
