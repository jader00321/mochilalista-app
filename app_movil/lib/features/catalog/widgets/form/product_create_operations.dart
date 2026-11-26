import 'package:flutter/material.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_draft_and_hydration.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_hydrated_data.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_presentation_ops.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_submit_ops.dart';

export 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_hydrated_data.dart';

class ProductCreateOperations {
  static Map<String, dynamic> createControllerMapFromDraft({
    required Map<String, dynamic> p,
    required VoidCallback onSyncDraft,
    required Map<int, String> deferredProviderNames,
  }) => ProductCreateDraftAndHydration.createControllerMapFromDraft(
    p: p,
    onSyncDraft: onSyncDraft,
    deferredProviderNames: deferredProviderNames,
  );

  static ProductCreateDraft buildCurrentDraft({
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required int? selectedBrandId,
    required String? selectedBrandName,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
    required int? generalProviderId,
    required String? generalProviderName,
    required int generalState,
    required List<Map<String, dynamic>> controllers,
    required Map<int, String> deferredProviderNames,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
  }) => ProductCreateDraftAndHydration.buildCurrentDraft(
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    barcodeCtrl: barcodeCtrl,
    selectedBrandId: selectedBrandId,
    selectedBrandName: selectedBrandName,
    selectedCategoryId: selectedCategoryId,
    selectedCategoryName: selectedCategoryName,
    generalProviderId: generalProviderId,
    generalProviderName: generalProviderName,
    generalState: generalState,
    controllers: controllers,
    deferredProviderNames: deferredProviderNames,
    modoStock: modoStock,
    stockCompartido: stockCompartido,
    costoBase: costoBase,
  );

  static void addPresentation({
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required int? generalProviderId,
    required int generalState,
    bool isDefault = false,
  }) => ProductCreatePresentationOps.addPresentation(
    controllers: controllers,
    keys: keys,
    onSyncDraft: onSyncDraft,
    generalProviderId: generalProviderId,
    generalState: generalState,
    isDefault: isDefault,
  );

  static void clonePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) => ProductCreatePresentationOps.clonePresentation(
    index: index,
    controllers: controllers,
    keys: keys,
    onSyncDraft: onSyncDraft,
    context: context,
  );

  static void createLeftover({
    required String parentId,
    required int leftoverUnits,
    required double costoBaseIndividual,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) => ProductCreatePresentationOps.createLeftover(
    parentId: parentId,
    leftoverUnits: leftoverUnits,
    costoBaseIndividual: costoBaseIndividual,
    controllers: controllers,
    keys: keys,
    onSyncDraft: onSyncDraft,
    context: context,
  );

  static void invalidateLeftover({
    required String parentId,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) => ProductCreatePresentationOps.invalidateLeftover(
    parentId: parentId,
    controllers: controllers,
    onSyncDraft: onSyncDraft,
  );

  static void removePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) => ProductCreatePresentationOps.removePresentation(
    index: index,
    controllers: controllers,
    keys: keys,
    onSyncDraft: onSyncDraft,
    context: context,
  );

  static void setDefault({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) => ProductCreatePresentationOps.setDefault(
    index: index,
    controllers: controllers,
    onSyncDraft: onSyncDraft,
    context: context,
  );

  static void moveUp({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) => ProductCreatePresentationOps.moveUp(
    index: index,
    controllers: controllers,
    onSyncDraft: onSyncDraft,
  );

  static void moveDown({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) => ProductCreatePresentationOps.moveDown(
    index: index,
    controllers: controllers,
    onSyncDraft: onSyncDraft,
  );

  static Future<void> handleClearAll({
    required BuildContext context,
    required bool isDark,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required Map<int, String> deferredProviderNames,
    required VoidCallback onCleared,
  }) => ProductCreateDraftAndHydration.handleClearAll(
    context: context,
    isDark: isDark,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    barcodeCtrl: barcodeCtrl,
    controllers: controllers,
    keys: keys,
    deferredProviderNames: deferredProviderNames,
    onCleared: onCleared,
  );

  static Future<bool> submitProduct({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required int? selectedBrandId,
    required String? selectedBrandName,
    required int? selectedCategoryId,
    required String? selectedCategoryName,
    required int? generalProviderId,
    required String? generalProviderName,
    required int generalState,
    required List<Map<String, dynamic>> controllers,
    required Map<int, String> deferredProviderNames,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
    Map<String, GlobalKey>? keys,
  }) => ProductCreateSubmitOps.submitProduct(
    context: context,
    formKey: formKey,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    barcodeCtrl: barcodeCtrl,
    selectedBrandId: selectedBrandId,
    selectedBrandName: selectedBrandName,
    selectedCategoryId: selectedCategoryId,
    selectedCategoryName: selectedCategoryName,
    generalProviderId: generalProviderId,
    generalProviderName: generalProviderName,
    generalState: generalState,
    controllers: controllers,
    deferredProviderNames: deferredProviderNames,
    modoStock: modoStock,
    stockCompartido: stockCompartido,
    costoBase: costoBase,
    keys: keys,
  );

  static ProductCreateHydratedData? hydrateFromDraft({
    required InventoryProvider invProv,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required Map<int, String> deferredProviderNames,
    required VoidCallback onSyncDraft,
    required int generalState,
    String? initialBarcode,
  }) => ProductCreateDraftAndHydration.hydrateFromDraft(
    invProv: invProv,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    barcodeCtrl: barcodeCtrl,
    controllers: controllers,
    keys: keys,
    deferredProviderNames: deferredProviderNames,
    onSyncDraft: onSyncDraft,
    generalState: generalState,
    initialBarcode: initialBarcode,
  );

  static ProductCreateHydratedData hydrateFromExtraction({
    required VariantExtractionBundle bundle,
    required TextEditingController nameCtrl,
    required TextEditingController descCtrl,
    required TextEditingController imgUrlCtrl,
    required TextEditingController barcodeCtrl,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required Map<int, String> deferredProviderNames,
    required VoidCallback onSyncDraft,
  }) => ProductCreateDraftAndHydration.hydrateFromExtraction(
    bundle: bundle,
    nameCtrl: nameCtrl,
    descCtrl: descCtrl,
    imgUrlCtrl: imgUrlCtrl,
    barcodeCtrl: barcodeCtrl,
    controllers: controllers,
    keys: keys,
    deferredProviderNames: deferredProviderNames,
    onSyncDraft: onSyncDraft,
  );

  static Future<bool> applyGeneralProviderChange({
    required BuildContext context,
    required int? newId,
    required String? newName,
    required bool isDark,
    required int? computedGeneralProviderId,
    required List<Map<String, dynamic>> controllers,
  }) => ProductCreatePresentationOps.applyGeneralProviderChange(
    context: context,
    newId: newId,
    newName: newName,
    isDark: isDark,
    computedGeneralProviderId: computedGeneralProviderId,
    controllers: controllers,
  );
}
