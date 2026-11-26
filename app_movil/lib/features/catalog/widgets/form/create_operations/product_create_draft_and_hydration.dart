import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/widgets/form/product_clear_form_dialog.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_hydrated_data.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_presentation_ops.dart';

class ProductCreateDraftAndHydration {
  ProductCreateDraftAndHydration._();

  static void attachSyncListeners(
    Map<String, dynamic> controllerMap,
    VoidCallback onSyncDraft,
  ) {
    (controllerMap['specific'] as TextEditingController).addListener(
      onSyncDraft,
    );
    (controllerMap['precioVenta'] as TextEditingController).addListener(
      onSyncDraft,
    );
    (controllerMap['costoPres'] as TextEditingController).addListener(
      onSyncDraft,
    );
    (controllerMap['image'] as TextEditingController).addListener(onSyncDraft);
    (controllerMap['barcode'] as TextEditingController).addListener(
      onSyncDraft,
    );
    (controllerMap['stockFinal'] as TextEditingController).addListener(
      onSyncDraft,
    );
  }

  static Map<String, dynamic> createControllerMapFromDraft({
    required Map<String, dynamic> p,
    required VoidCallback onSyncDraft,
    required Map<int, String> deferredProviderNames,
  }) {
    final spec = TextEditingController(text: p['specific'] ?? "");
    final uVenta = TextEditingController(text: p['unidadVenta'] ?? "Unidad");
    final factorVenta = TextEditingController(text: p['unidadesVenta'] ?? "1");
    final costoPres = TextEditingController(text: p['costoPres'] ?? "0.00");
    final margen = TextEditingController(text: p['margen'] ?? "1.35");
    final pVenta = TextEditingController(text: p['precioVenta'] ?? "");

    final valorDesc = TextEditingController(text: p['valorDescuento'] ?? "");
    final stockInit = TextEditingController(text: p['stockInicial'] ?? "0");
    final nuevoIng = TextEditingController(text: p['nuevoIngreso'] ?? "");
    final stockDesc = TextEditingController(text: p['stockDescuento'] ?? "0");
    final stockFinal = TextEditingController(text: p['stockFinal'] ?? "0");

    final umpC = TextEditingController(text: p['umpCompra'] ?? "");
    final unLote = TextEditingController(text: p['unidadesLote'] ?? "");
    final cantC = TextEditingController(text: p['cantCompra'] ?? "");
    final totalP = TextEditingController(text: p['totalPago'] ?? "");

    final bar = TextEditingController(text: p['barcode'] ?? "");
    final desc = TextEditingController(text: p['desc'] ?? "");
    final img = TextEditingController(text: p['image'] ?? "");
    final ajuste = TextEditingController(text: p['ajusteBase'] ?? "");

    final int? pId = p['providerId'] as int?;
    final String? defProv = p['deferredProviderName'] as String?;
    if (pId != null && pId < 0 && defProv != null) {
      deferredProviderNames[pId] = defProv;
    }

    final map = <String, dynamic>{
      'id': p['id'] ?? UniqueKey().toString(),
      'childId': p['childId'],
      'isEditMode': false,
      'leftoverCreated': p['leftoverCreated'] == true,
      'specific': spec,
      'unidadVenta': uVenta,
      'unidadesVenta': factorVenta,
      'costoPres': costoPres,
      'margen': margen,
      'precioVenta': pVenta,
      'descuentoActivo': p['descuentoActivo'] == true,
      'tipoDescuento': p['tipoDescuento'] ?? 'porcentaje',
      'valorDescuento': valorDesc,
      'stockInicial': stockInit,
      'nuevoIngreso': nuevoIng,
      'stockDescuento': stockDesc,
      'stockFinal': stockFinal,
      'umpCompra': umpC,
      'unidadesLote': unLote,
      'cantCompra': cantC,
      'totalPago': totalP,
      'barcode': bar,
      'desc': desc,
      'image': img,
      'ajusteBase': ajuste,
      'providerId': pId,
      'isDefault': p['isDefault'] == true,
      'isExpanded': p['isExpanded'] ?? false,
      'estado': p['estado'] ?? 'publico',
      'activeRoundingTarget': p['activeRoundingTarget'] as double?,
      'preRoundedPrice': p['preRoundedPrice'] as String?,
      'preRoundedMargen': p['preRoundedMargen'] as String?,
      'usaStockCompartido': p['usaStockCompartido'] == true,
      'cupoMaximoVariante': p['cupoMaximoVariante'] as int?,
    };
    attachSyncListeners(map, onSyncDraft);
    return map;
  }

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
  }) {
    final presList = controllers.map((c) {
      final pId = c['providerId'] as int?;
      return {
        'id': c['id'],
        'childId': c['childId'],
        'leftoverCreated': c['leftoverCreated'] == true,
        'specific': (c['specific'] as TextEditingController).text,
        'unidadVenta': (c['unidadVenta'] as TextEditingController).text,
        'unidadesVenta': (c['unidadesVenta'] as TextEditingController).text,
        'costoPres': (c['costoPres'] as TextEditingController).text,
        'margen': (c['margen'] as TextEditingController).text,
        'precioVenta': (c['precioVenta'] as TextEditingController).text,
        'descuentoActivo': c['descuentoActivo'] == true,
        'tipoDescuento': c['tipoDescuento'] ?? 'porcentaje',
        'valorDescuento': (c['valorDescuento'] as TextEditingController).text,
        'stockInicial': (c['stockInicial'] as TextEditingController).text,
        'nuevoIngreso': (c['nuevoIngreso'] as TextEditingController).text,
        'stockDescuento': (c['stockDescuento'] as TextEditingController).text,
        'stockFinal': (c['stockFinal'] as TextEditingController).text,
        'umpCompra': (c['umpCompra'] as TextEditingController).text,
        'unidadesLote': (c['unidadesLote'] as TextEditingController).text,
        'cantCompra': (c['cantCompra'] as TextEditingController).text,
        'totalPago': (c['totalPago'] as TextEditingController).text,
        'barcode': (c['barcode'] as TextEditingController).text,
        'desc': (c['desc'] as TextEditingController).text,
        'image': (c['image'] as TextEditingController).text,
        'ajusteBase': (c['ajusteBase'] as TextEditingController).text,
        'providerId': pId,
        'deferredProviderName': pId != null && pId < 0
            ? deferredProviderNames[pId]
            : null,
        'isDefault': c['isDefault'] == true,
        'isExpanded': c['isExpanded'] == true,
        'estado': c['estado'] ?? 'publico',
        'activeRoundingTarget': c['activeRoundingTarget'] as double?,
        'preRoundedPrice': c['preRoundedPrice'] as String?,
        'preRoundedMargen': c['preRoundedMargen'] as String?,
        'usaStockCompartido': c['usaStockCompartido'] == true,
        'cupoMaximoVariante': c['cupoMaximoVariante'] as int?,
      };
    }).toList();

    return ProductCreateDraft(
      name: nameCtrl.text,
      brandId: selectedBrandId,
      deferredBrandName: selectedBrandName,
      categoryId: selectedCategoryId,
      deferredCategoryName: selectedCategoryName,
      generalProviderId: generalProviderId,
      deferredGeneralProviderName: generalProviderName,
      generalState: generalState,
      description: descCtrl.text,
      imageUrl: imgUrlCtrl.text,
      barcode: barcodeCtrl.text,
      presentations: presList,
      modoStock: modoStock,
      stockCompartido: stockCompartido,
      costoBase: costoBase,
    );
  }

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
  }) async {
    final confirm = await ProductClearFormDialog.show(context, isDark: isDark);
    if (confirm != true || !context.mounted) return;

    nameCtrl.clear();
    descCtrl.clear();
    imgUrlCtrl.clear();
    barcodeCtrl.clear();
    deferredProviderNames.clear();

    keys.clear();
    for (var map in controllers) {
      ProductControllerFactory.disposeControllerMap(map);
    }
    controllers.clear();

    Provider.of<InventoryProvider>(context, listen: false).clearCreationDraft();
    onCleared();
    HapticFeedback.mediumImpact();

    AppFeedbackHelper.showSnackBar(
      context,
      "Formulario limpiado por completo",
      backgroundColor: Colors.blueGrey,
      duration: const Duration(seconds: 2),
    );
  }

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
  }) {
    final draft = invProv.creationDraft;
    if (draft != null && draft.hasMeaningfulData) {
      nameCtrl.text = draft.name;
      descCtrl.text = draft.description;
      imgUrlCtrl.text = draft.imageUrl;
      if (draft.barcode.isNotEmpty) {
        barcodeCtrl.text = draft.barcode;
      }

      for (var map in controllers) {
        ProductControllerFactory.disposeControllerMap(map);
      }
      keys.clear();
      controllers.clear();

      for (var p in draft.presentations) {
        final newMap = createControllerMapFromDraft(
          p: p,
          onSyncDraft: onSyncDraft,
          deferredProviderNames: deferredProviderNames,
        );
        keys[newMap['id']] = GlobalKey();
        controllers.add(newMap);
      }

      if (controllers.isEmpty) {
        ProductCreatePresentationOps.addPresentation(
          controllers: controllers,
          keys: keys,
          onSyncDraft: onSyncDraft,
          generalProviderId: draft.generalProviderId,
          generalState: generalState,
          isDefault: true,
        );
      }
      if (!controllers.any((c) => c['isDefault'] == true)) {
        controllers.first['isDefault'] = true;
      }

      _applyInitialBarcode(barcodeCtrl, controllers, initialBarcode);

      return ProductCreateHydratedData(
        brandId: draft.brandId,
        brandName: draft.deferredBrandName,
        categoryId: draft.categoryId,
        categoryName: draft.deferredCategoryName,
        generalProviderId: draft.generalProviderId,
        generalProviderName: draft.deferredGeneralProviderName,
        modoStock: draft.modoStock,
        stockCompartido: draft.stockCompartido,
        costoBase: draft.costoBase,
      );
    }

    if (controllers.isEmpty) {
      ProductCreatePresentationOps.addPresentation(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        generalProviderId: null,
        generalState: generalState,
        isDefault: true,
      );
    }

    _applyInitialBarcode(barcodeCtrl, controllers, initialBarcode);
    return null;
  }

  static void _applyInitialBarcode(
    TextEditingController barcodeCtrl,
    List<Map<String, dynamic>> controllers,
    String? initialBarcode,
  ) {
    if (initialBarcode != null && initialBarcode.trim().isNotEmpty) {
      final code = initialBarcode.trim();
      barcodeCtrl.text = code;
      if (controllers.isNotEmpty &&
          controllers.first['barcode'] is TextEditingController) {
        (controllers.first['barcode'] as TextEditingController).text = code;
      }
    }
  }

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
  }) {
    for (var map in controllers) {
      ProductControllerFactory.disposeControllerMap(map);
    }
    keys.clear();
    controllers.clear();

    final general = bundle.generalData;
    final detail = bundle.detailData;

    nameCtrl.text = detail.newProductName;
    descCtrl.text = general.copyDescription ? (general.description ?? "") : "";
    imgUrlCtrl.text = general.copyImages
        ? (general.imageUrl ?? "")
        : (detail.includeVariantImage ? (detail.variantImage ?? "") : "");
    barcodeCtrl.text = detail.includeBarcode ? (detail.barcode ?? "") : "";

    final bool hasStockToTransfer =
        detail.includeStock && detail.transferFullStock;
    final int safeFactor = detail.unitFactor <= 0 ? 1 : detail.unitFactor;
    final int safePackageUnits = hasStockToTransfer
        ? (detail.packageUnits > 0 ? detail.packageUnits : detail.stockUnits)
        : 0;
    final int safeBaseUnits = hasStockToTransfer
        ? (detail.baseUnits > 0
              ? detail.baseUnits
              : safePackageUnits * safeFactor)
        : 0;

    final bool hasDiscount = detail.hasDiscount;
    final String discountType = detail.discountType ?? "porcentaje";
    final double? origDiscountVal = detail.discountValue;
    final double? origOfferPrice = detail.offerPrice;

    final double? unitOfferPrice =
        (origOfferPrice != null && origOfferPrice > 0)
        ? double.parse((origOfferPrice / safeFactor).toStringAsFixed(2))
        : null;
    final double? unitDiscountVal = origDiscountVal != null
        ? ((discountType == 'monto' || discountType == 'fijo')
              ? double.parse((origDiscountVal / safeFactor).toStringAsFixed(2))
              : origDiscountVal)
        : null;
    final String unitDiscountValStr = unitDiscountVal != null
        ? (unitDiscountVal % 1 == 0
              ? unitDiscountVal.toInt().toString()
              : unitDiscountVal.toStringAsFixed(2))
        : "";

    String modoStockFinal = 'INDEPENDIENTE';
    int sharedStockFinal = 0;
    double baseCostFinal = 0.0;

    if (detail.targetStructure ==
        VariantExtractionStructure.bothUnitAndPackage) {
      modoStockFinal = 'COMPARTIDO';
      sharedStockFinal = safeBaseUnits;
      baseCostFinal = detail.includePricing ? detail.unitCostPrice : 0.0;

      _appendExtractionController(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        alertStock: detail.includeStockAlert ? (detail.alertStock ?? 5) : 5,
        map: ProductControllerFactory.createNewControllerMap(
          id: UniqueKey().toString(),
          isDefault: true,
          isExpanded: true,
          isEditMode: false,
          specificName: "",
          unidadVenta: "Unidad",
          unidadesVenta: "1",
          costoPres: detail.includePricing
              ? detail.unitCostPrice.toStringAsFixed(2)
              : "0.00",
          margen: detail.includePricing
              ? detail.margin.toStringAsFixed(2)
              : "1.35",
          precioVenta: detail.includePricing
              ? detail.unitSalePrice.toStringAsFixed(2)
              : "0.00",
          stockInicial: "0",
          stockFinal: safeBaseUnits.toString(),
          usaStockCompartido: true,
          cupoMaximoVariante: null,
          barcode: "",
          image: detail.includeVariantImage ? (detail.variantImage ?? "") : "",
          providerId: detail.variantProviderId,
          deferredProviderName: detail.variantProviderName,
          descuentoActivo: hasDiscount,
          tipoDescuento: discountType,
          valorDescuento: hasDiscount ? unitDiscountValStr : "",
          precioOfertaExacto: hasDiscount ? unitOfferPrice : null,
        ),
      );

      _appendExtractionController(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        alertStock: detail.includeStockAlert ? (detail.alertStock ?? 5) : 5,
        map: ProductControllerFactory.createNewControllerMap(
          id: UniqueKey().toString(),
          isDefault: false,
          isExpanded: true,
          isEditMode: false,
          specificName: detail.specificName ?? "",
          unidadVenta: detail.includeUnit ? detail.unitName : "Caja",
          unidadesVenta: detail.includeUnit
              ? detail.unitFactor.toString()
              : "1",
          costoPres: detail.includePricing
              ? detail.costPrice.toStringAsFixed(2)
              : "0.00",
          margen: detail.includePricing
              ? detail.margin.toStringAsFixed(2)
              : "1.35",
          precioVenta: detail.includePricing
              ? detail.salePrice.toStringAsFixed(2)
              : "0.00",
          stockInicial: "0",
          stockFinal: safePackageUnits.toString(),
          usaStockCompartido: true,
          cupoMaximoVariante: safePackageUnits > 0 ? safePackageUnits : null,
          barcode: detail.includeBarcode ? (detail.barcode ?? "") : "",
          image: detail.includeVariantImage ? (detail.variantImage ?? "") : "",
          providerId: detail.variantProviderId,
          deferredProviderName: detail.variantProviderName,
          descuentoActivo: hasDiscount,
          tipoDescuento: discountType,
          valorDescuento: origDiscountVal != null
              ? origDiscountVal.toString()
              : "",
          precioOfertaExacto: origOfferPrice,
          umpCompra: detail.umpCompra ?? "",
          unidadesLote: detail.unidadesLote.toString(),
          cantCompra: detail.cantCompra != null
              ? detail.cantCompra.toString()
              : "",
          totalPago: detail.totalPago != null
              ? detail.totalPago.toString()
              : "",
          desc: detail.variantDescription ?? "",
        ),
      );
    } else if (detail.targetStructure == VariantExtractionStructure.unitOnly) {
      _appendExtractionController(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        alertStock: detail.includeStockAlert ? (detail.alertStock ?? 5) : 5,
        map: ProductControllerFactory.createNewControllerMap(
          id: UniqueKey().toString(),
          isDefault: true,
          isExpanded: true,
          isEditMode: false,
          specificName: "",
          unidadVenta: "Unidad",
          unidadesVenta: "1",
          costoPres: detail.includePricing
              ? detail.unitCostPrice.toStringAsFixed(2)
              : "0.00",
          margen: detail.includePricing
              ? detail.margin.toStringAsFixed(2)
              : "1.35",
          precioVenta: detail.includePricing
              ? detail.unitSalePrice.toStringAsFixed(2)
              : "0.00",
          stockInicial: safeBaseUnits.toString(),
          stockFinal: safeBaseUnits.toString(),
          barcode: detail.includeBarcode ? (detail.barcode ?? "") : "",
          image: detail.includeVariantImage ? (detail.variantImage ?? "") : "",
          providerId: detail.variantProviderId,
          deferredProviderName: detail.variantProviderName,
          descuentoActivo: hasDiscount,
          tipoDescuento: discountType,
          valorDescuento: hasDiscount ? unitDiscountValStr : "",
          precioOfertaExacto: hasDiscount ? unitOfferPrice : null,
          desc: detail.variantDescription ?? "",
        ),
      );
    } else {
      _appendExtractionController(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        alertStock: detail.includeStockAlert ? (detail.alertStock ?? 5) : 5,
        map: ProductControllerFactory.createNewControllerMap(
          id: UniqueKey().toString(),
          isDefault: true,
          isExpanded: true,
          isEditMode: false,
          specificName: detail.specificName ?? "",
          unidadVenta: detail.includeUnit ? detail.unitName : "Unidad",
          unidadesVenta: detail.includeUnit
              ? detail.unitFactor.toString()
              : "1",
          costoPres: detail.includePricing
              ? detail.costPrice.toStringAsFixed(2)
              : "0.00",
          margen: detail.includePricing
              ? detail.margin.toStringAsFixed(2)
              : "1.35",
          precioVenta: detail.includePricing
              ? detail.salePrice.toStringAsFixed(2)
              : "0.00",
          stockInicial: safeBaseUnits.toString(),
          stockFinal: safePackageUnits.toString(),
          barcode: detail.includeBarcode ? (detail.barcode ?? "") : "",
          image: detail.includeVariantImage ? (detail.variantImage ?? "") : "",
          providerId: detail.variantProviderId,
          deferredProviderName: detail.variantProviderName,
          descuentoActivo: detail.hasDiscount,
          tipoDescuento: detail.discountType ?? "porcentaje",
          valorDescuento: detail.discountValue != null
              ? detail.discountValue.toString()
              : "",
          precioOfertaExacto: detail.offerPrice,
          umpCompra: detail.umpCompra ?? "",
          unidadesLote: detail.unidadesLote.toString(),
          cantCompra: detail.cantCompra != null
              ? detail.cantCompra.toString()
              : "",
          totalPago: detail.totalPago != null
              ? detail.totalPago.toString()
              : "",
          desc: detail.variantDescription ?? "",
        ),
      );
    }

    if (detail.variantProviderId != null &&
        detail.variantProviderId! < 0 &&
        detail.variantProviderName != null) {
      deferredProviderNames[detail.variantProviderId!] =
          detail.variantProviderName!;
    }

    final int? brandId = general.copyBrand ? general.brandId : null;
    final String? brandName = general.copyBrand ? general.brandName : null;
    final int? categoryId = general.copyCategory ? general.categoryId : null;
    final String? categoryName = general.copyCategory
        ? general.categoryName
        : null;
    final int? providerId = general.copyProvider
        ? general.generalProviderId
        : null;
    final String? providerName = general.copyProvider
        ? general.generalProviderName
        : null;

    if (providerId != null && providerId < 0 && providerName != null) {
      deferredProviderNames[providerId] = providerName;
    }

    return ProductCreateHydratedData(
      brandId: brandId,
      brandName: brandName,
      categoryId: categoryId,
      categoryName: categoryName,
      generalProviderId: providerId,
      generalProviderName: providerName,
      modoStock: modoStockFinal,
      stockCompartido: sharedStockFinal,
      costoBase: baseCostFinal,
    );
  }

  static void _appendExtractionController({
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required int alertStock,
    required Map<String, dynamic> map,
  }) {
    final id = map['id'] as String;
    keys[id] = GlobalKey();
    map['stockAlerta'] = alertStock;
    attachSyncListeners(map, onSyncDraft);
    controllers.add(map);
  }
}
