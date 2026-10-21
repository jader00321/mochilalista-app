import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

class ProductEditLoadedData {
  final int? categoryId;
  final String? categoryName;
  final int? brandId;
  final String? brandName;
  final String? targetKeyToScroll;

  const ProductEditLoadedData({
    this.categoryId,
    this.categoryName,
    this.brandId,
    this.brandName,
    this.targetKeyToScroll,
  });
}

/// Operaciones y lógica de negocio desacoplada para ProductEditScreen.
class ProductEditOperations {
  /// Carga datos iniciales del producto en edición mapeando hacia controladores
  static ProductEditLoadedData loadInitialData({
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

    int? categoryId = invProv.categories.any((c) => c.id == product.categoriaId)
        ? product.categoriaId
        : (product.categoriaId > 0 ? product.categoriaId : null);
    String? categoryName;
    if (categoryId != null) {
      final c = invProv.categories.where((c) => c.id == categoryId).firstOrNull;
      categoryName = c?.nombre;
    }

    int? brandId = product.marcaId;
    String? brandName;
    if (brandId != null) {
      final b = invProv.brands.where((b) => b.id == brandId).firstOrNull;
      brandName = b?.nombre ?? product.marcaNombre;
    }

    List<ProductPresentation> sortedList = List.from(product.presentaciones);
    sortedList.sort((a, b) {
      if (a.esDefault && !b.esDefault) return -1;
      if (!a.esDefault && b.esDefault) return 1;
      if (a.orden != b.orden) return a.orden.compareTo(b.orden);
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    presentationControllers.clear();
    presentationKeys.clear();
    String? targetKeyToScroll;

    for (var pres in sortedList) {
      int? safeProvId = pres.proveedorId;
      if (safeProvId != null &&
          !invProv.providers.any((pr) => pr.id == safeProvId)) {
        safeProvId = null;
      }

      final String presKeyId = pres.id.toString();
      presentationKeys[presKeyId] = GlobalKey();

      final bool isTarget = initialPresentationId != null &&
          pres.id == initialPresentationId;
      if (isTarget) {
        targetKeyToScroll = presKeyId;
      }

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
        stockInicial: (pres.stockActual ~/ (pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1)).toString(),
        stockFinal: (pres.stockActual ~/ (pres.unidadesPorVenta > 0 ? pres.unidadesPorVenta : 1)).toString(),
        barcode: pres.codigoBarras ?? "",
        providerId: safeProvId,
        estado: pres.estado,
        unidadesLote: pres.unidadesPorLote.toString(),
        cantCompra: pres.cantidadUmpComprada?.toStringAsFixed(2) ?? "",
        totalPago: pres.totalPagoLote?.toStringAsFixed(2) ?? "",
        umpCompra: pres.umpCompra ?? "",
        desc: pres.descripcion ?? "",
        image: pres.imagenUrl ?? "",
        descuentoActivo: (pres.precioOferta != null && pres.precioOferta! > 0) ||
            (pres.valorDescuento != null &&
                pres.valorDescuento! > 0 &&
                pres.tipoDescuento != null &&
                pres.tipoDescuento != 'ninguno'),
        valorDescuento: pres.valorDescuento?.toStringAsFixed(2) ?? "",
        tipoDescuento: pres.tipoDescuento ?? 'porcentaje',
        precioOfertaExacto: pres.precioOferta,
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

  /// Añade una nueva presentación vacía y scrollea a ella
  static void addPresentation({
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

  /// Clona la presentación seleccionada
  static void clonePresentation({
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 Variante clonada exitosamente"),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Asigna variante principal y la mueve al inicio
  static void setDefault({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required BuildContext context,
  }) {
    if (index < 0 || index >= controllers.length) return;
    for (int i = 0; i < controllers.length; i++) {
      controllers[i]['isDefault'] = (i == index);
    }
    final item = controllers.removeAt(index);
    controllers.insert(0, item);
    item['isExpanded'] = true;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("⭐ Presentación Principal actualizada"),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Mueve presentación hacia arriba
  static void moveUp({
    required int index,
    required List<Map<String, dynamic>> controllers,
  }) {
    if (index <= 0) return;
    final item = controllers.removeAt(index);
    controllers.insert(index - 1, item);
    HapticFeedback.selectionClick();
  }

  /// Mueve presentación hacia abajo
  static void moveDown({
    required int index,
    required List<Map<String, dynamic>> controllers,
  }) {
    if (index >= controllers.length - 1) return;
    final item = controllers.removeAt(index);
    controllers.insert(index + 1, item);
    HapticFeedback.selectionClick();
  }

  /// Actualiza proveedor general con confirmación si sobreescribe variantes
  static Future<bool> updateGeneralProvider({
    required BuildContext context,
    required int? newId,
    required String? newName,
    required bool isDark,
    required int? currentGeneralProviderId,
    required List<Map<String, dynamic>> controllers,
  }) async {
    if (currentGeneralProviderId != -2 && controllers.length <= 1) {
      for (var c in controllers) {
        c['providerId'] = newId;
        if (newId != null && newId < 0 && newName != null) {
          c['deferredProviderName'] = newName;
        } else {
          c.remove('deferredProviderName');
        }
      }
      return true;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Sobreescribir Proveedores?",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Esta acción cambiará el proveedor de TODAS las presentaciones, perdiendo cualquier proveedor específico.",
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Sí, Aplicar")),
        ],
      ),
    );
    if (confirm == true) {
      for (var c in controllers) {
        c['providerId'] = newId;
        if (newId != null && newId < 0 && newName != null) {
          c['deferredProviderName'] = newName;
        } else {
          c.remove('deferredProviderName');
        }
      }
      return true;
    }
    return false;
  }

  /// Creación de variante sobrante/fraccionada
  static void createLeftover({
    required BuildContext context,
    required String parentId,
    required int leftoverUnits,
    required double costoBaseIndividual,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
  }) {
    int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex == -1) return;

    Map<String, dynamic> sourceMap = controllers[parentIndex];
    sourceMap['leftoverCreated'] = true;

    String newChildId = UniqueKey().toString();
    sourceMap['childId'] = newChildId;
    keys[newChildId] = GlobalKey();

    final newChild = ProductControllerFactory.createLeftoverControllerMap(
      parentMap: sourceMap,
      newChildId: newChildId,
      leftoverUnits: leftoverUnits,
      costoBaseIndividual: costoBaseIndividual,
    );

    controllers.insert(parentIndex + 1, newChild);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Variante sobrante creada debajo"),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Invalidación de variante sobrante/fraccionada
  static void invalidateLeftover({
    required String parentId,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
  }) {
    int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex != -1) {
      String? childId = controllers[parentIndex]['childId'];
      if (childId != null) {
        int childIndex = controllers.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
          controllers.removeAt(childIndex);
          keys.remove(childId);
        }
      }
      controllers[parentIndex]['childId'] = null;
      controllers[parentIndex]['leftoverCreated'] = false;
    }
  }

  /// Diálogo y lógica de eliminación segura de una presentación
  static Future<void> deletePresentation({
    required BuildContext context,
    required int index,
    required bool isDark,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required List<int> idsToDelete,
    required VoidCallback onDeleted,
  }) async {
    if (controllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "El producto debe tener al menos una presentación.",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final item = controllers[index];
    final bool wasDefault = item['isDefault'] == true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "¿Eliminar presentación?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          wasDefault
              ? "Esta es la presentación PRINCIPAL. Al eliminarla, la siguiente variante será promovida automáticamente a Principal."
              : "Se eliminará esta presentación y su stock asociado.",
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Eliminar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (item['db_id'] != null) {
      idsToDelete.add(item['db_id']);
    }

    for (var c in controllers) {
      if (c['childId'] == item['id']) {
        c['childId'] = null;
        c['leftoverCreated'] = false;
      }
    }

    String? childId = item['childId'];
    ProductControllerFactory.disposeControllerMap(controllers[index]);
    controllers.removeAt(index);
    keys.remove(item['id']);

    if (childId != null) {
      int childIndex = controllers.indexWhere((c) => c['id'] == childId);
      if (childIndex != -1) {
        ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
        controllers.removeAt(childIndex);
        keys.remove(childId);
      }
    }

    if (wasDefault && controllers.isNotEmpty) {
      controllers.first['isDefault'] = true;
    }

    onDeleted();
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasDefault
                ? "⭐ Variante eliminada. La siguiente fue promovida a Principal."
                : "Variante eliminada.",
          ),
          backgroundColor: wasDefault ? Colors.teal : Colors.grey[800],
        ),
      );
    }
  }

  /// Ejecuta validación y guardado completo del producto editado
  static Future<bool> saveEditedProduct({
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
  }) async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor corrige los errores antes de guardar."),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (controllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debe haber al menos una presentación."),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    bool hasDefault = controllers.any((c) => c['isDefault'] == true);
    if (!hasDefault) {
      controllers.first['isDefault'] = true;
    }

    final presentacionesFinales = ProductFormMapper.toPresentations(
      controllers: controllers,
      defaultDesc: descCtrl.text,
      defaultImg: imgUrlCtrl.text,
      defaultBarcode: parentBarcodeCtrl.text,
    );

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final bool isBrandDef = selectedBrandId != null && selectedBrandId < 0;
    final bool isCatDef = selectedCategoryId != null && selectedCategoryId < 0;

    final success = await provider.editFullProduct(
      productId: productToEdit.id,
      nombre: nameCtrl.text,
      descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      marcaId: isBrandDef ? null : (selectedBrandId == 0 ? null : selectedBrandId),
      deferredBrandName: isBrandDef ? selectedBrandName : null,
      categoriaId: isCatDef ? null : (selectedCategoryId == 0 ? null : selectedCategoryId),
      deferredCategoryName: isCatDef ? selectedCategoryName : null,
      estado: productToEdit.estado,
      imagenUrl: imgUrlCtrl.text.trim().isEmpty ? null : imgUrlCtrl.text.trim(),
      codigoBarras: parentBarcodeCtrl.text.trim().isEmpty ? null : parentBarcodeCtrl.text.trim(),
      presentaciones: presentacionesFinales,
      idsToDelete: idsToDelete,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
      );
    }

    return false;
  }
}
