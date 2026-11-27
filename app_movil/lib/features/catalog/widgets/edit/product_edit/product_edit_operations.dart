import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_form_mapper.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

part 'operations/product_edit_load_and_list_part.dart';
part 'operations/product_edit_leftover_and_cut_part.dart';
part 'operations/product_edit_save_part.dart';

/// Resultado hidratado de metadatos al cargar un producto existente en edición.
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
  /// Carga datos iniciales del producto en edición mapeando hacia controladores.
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
  }) => _loadInitialDataImpl(
    product: product,
    invProv: invProv,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    parentBarcodeCtrl: parentBarcodeCtrl,
    presentationControllers: presentationControllers,
    presentationKeys: presentationKeys,
    initialPresentationId: initialPresentationId,
  );

  /// Añade una nueva presentación vacía y scrollea a ella.
  static void addPresentation({
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required int? generalProviderId,
    required Map<int, String> deferredProviderNames,
  }) => _addPresentationImpl(
    controllers: controllers,
    keys: keys,
    generalProviderId: generalProviderId,
    deferredProviderNames: deferredProviderNames,
  );

  /// Clona la presentación seleccionada.
  static void clonePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required BuildContext context,
  }) => _clonePresentationImpl(
    index: index,
    controllers: controllers,
    keys: keys,
    context: context,
  );

  /// Asigna variante principal y la mueve al inicio.
  static void setDefault({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required BuildContext context,
  }) =>
      _setDefaultImpl(index: index, controllers: controllers, context: context);

  /// Mueve presentación hacia arriba.
  static void moveUp({
    required int index,
    required List<Map<String, dynamic>> controllers,
  }) => _moveUpImpl(index: index, controllers: controllers);

  /// Mueve presentación hacia abajo.
  static void moveDown({
    required int index,
    required List<Map<String, dynamic>> controllers,
  }) => _moveDownImpl(index: index, controllers: controllers);

  /// Actualiza proveedor general con confirmación si sobreescribe variantes.
  static Future<bool> updateGeneralProvider({
    required BuildContext context,
    required int? newId,
    required String? newName,
    required bool isDark,
    required int? currentGeneralProviderId,
    required List<Map<String, dynamic>> controllers,
  }) => _updateGeneralProviderImpl(
    context: context,
    newId: newId,
    newName: newName,
    isDark: isDark,
    currentGeneralProviderId: currentGeneralProviderId,
    controllers: controllers,
  );

  /// Creación de variante sobrante/fraccionada.
  static void createLeftover({
    required BuildContext context,
    required String parentId,
    required int leftoverUnits,
    required double costoBaseIndividual,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
  }) => _createLeftoverImpl(
    context: context,
    parentId: parentId,
    leftoverUnits: leftoverUnits,
    costoBaseIndividual: costoBaseIndividual,
    controllers: controllers,
    keys: keys,
  );

  /// Invalidación de variante sobrante/fraccionada.
  static void invalidateLeftover({
    required String parentId,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
  }) => _invalidateLeftoverImpl(
    parentId: parentId,
    controllers: controllers,
    keys: keys,
  );

  /// Diálogo y lógica de eliminación segura de una presentación.
  static Future<void> deletePresentation({
    required BuildContext context,
    required int index,
    required bool isDark,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required List<int> idsToDelete,
    required VoidCallback onDeleted,
  }) => _deletePresentationImpl(
    context: context,
    index: index,
    isDark: isDark,
    controllers: controllers,
    keys: keys,
    idsToDelete: idsToDelete,
    onDeleted: onDeleted,
  );

  /// Finaliza el corte diferido de una variante en memoria y en base de datos de forma atómica.
  static Future<void> finalizeVariantExtractionCut({
    required BuildContext context,
    required ProductExtractionResult result,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required int originProductId,
    required VoidCallback onCompleted,
    InventoryProvider? inventoryProvider,
    TextEditingController? sharedStockCtrl,
  }) => _finalizeVariantExtractionCutImpl(
    context: context,
    result: result,
    controllers: controllers,
    keys: keys,
    originProductId: originProductId,
    onCompleted: onCompleted,
    inventoryProvider: inventoryProvider,
    sharedStockCtrl: sharedStockCtrl,
  );

  /// Ejecuta validación y guardado completo del producto editado.
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
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
    Map<String, GlobalKey>? keys,
  }) => _saveEditedProductImpl(
    context: context,
    formKey: formKey,
    productToEdit: productToEdit,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    parentBarcodeCtrl: parentBarcodeCtrl,
    selectedBrandId: selectedBrandId,
    selectedBrandName: selectedBrandName,
    selectedCategoryId: selectedCategoryId,
    selectedCategoryName: selectedCategoryName,
    controllers: controllers,
    idsToDelete: idsToDelete,
    modoStock: modoStock,
    stockCompartido: stockCompartido,
    costoBase: costoBase,
    keys: keys,
  );
}
