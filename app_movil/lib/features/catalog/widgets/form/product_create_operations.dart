import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/product_create_draft.dart';
import 'package:app_movil/features/catalog/models/variant_extraction_models.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/product_clear_form_dialog.dart';
import 'package:app_movil/features/catalog/widgets/product_save_success_dialog.dart';

class ProductCreateOperations {
  /// Crea un mapa de controladores a partir del borrador de una variante
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

    spec.addListener(onSyncDraft);
    pVenta.addListener(onSyncDraft);
    costoPres.addListener(onSyncDraft);
    img.addListener(onSyncDraft);
    bar.addListener(onSyncDraft);
    stockFinal.addListener(onSyncDraft);

    final int? pId = p['providerId'] as int?;
    final String? defProv = p['deferredProviderName'] as String?;
    if (pId != null && pId < 0 && defProv != null) {
      deferredProviderNames[pId] = defProv;
    }

    return {
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
  }

  /// Construye el borrador actual en memoria
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
        'deferredProviderName':
            pId != null && pId < 0 ? deferredProviderNames[pId] : null,
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

  /// Añade una nueva presentación a la lista
  static void addPresentation({
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required int? generalProviderId,
    required int generalState,
    bool isDefault = false,
  }) {
    final spec = TextEditingController();
    final pVenta = TextEditingController(text: "");
    final costo = TextEditingController(text: "0.00");
    final img = TextEditingController();
    final bar = TextEditingController();
    final stockFinal = TextEditingController(text: "0");

    spec.addListener(onSyncDraft);
    pVenta.addListener(onSyncDraft);
    costo.addListener(onSyncDraft);
    img.addListener(onSyncDraft);
    bar.addListener(onSyncDraft);
    stockFinal.addListener(onSyncDraft);

    final String newId = UniqueKey().toString();
    keys[newId] = GlobalKey();

    final newMap = {
      'id': newId,
      'childId': null,
      'isEditMode': false,
      'isExpanded': true,
      'leftoverCreated': false,
      'specific': spec,
      'unidadVenta': TextEditingController(text: "Unidad"),
      'unidadesVenta': TextEditingController(text: "1"),
      'costoPres': costo,
      'margen': TextEditingController(text: "1.35"),
      'precioVenta': pVenta,
      'descuentoActivo': false,
      'tipoDescuento': 'porcentaje',
      'valorDescuento': TextEditingController(text: ""),
      'stockInicial': TextEditingController(text: "0"),
      'nuevoIngreso': TextEditingController(text: ""),
      'stockDescuento': TextEditingController(text: "0"),
      'stockFinal': stockFinal,
      'umpCompra': TextEditingController(text: ""),
      'unidadesLote': TextEditingController(text: ""),
      'cantCompra': TextEditingController(text: ""),
      'totalPago': TextEditingController(text: ""),
      'barcode': bar,
      'desc': TextEditingController(),
      'image': img,
      'ajusteBase': TextEditingController(),
      'providerId': generalProviderId == -2 ? null : generalProviderId,
      'isDefault': isDefault,
      'estado': generalState == 0 ? 'privado' : 'publico',
      'activeRoundingTarget': null,
      'preRoundedPrice': null,
      'preRoundedMargen': null,
    };

    controllers.add(newMap);
    onSyncDraft();
  }

  /// Clona una presentación existente
  static void clonePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    final source = controllers[index];
    final String newId = UniqueKey().toString();
    keys[newId] = GlobalKey();

    final spec = TextEditingController(text: (source['specific'] as TextEditingController).text);
    final pVenta = TextEditingController(text: (source['precioVenta'] as TextEditingController).text);
    final costo = TextEditingController(text: (source['costoPres'] as TextEditingController).text);
    final img = TextEditingController(text: (source['image'] as TextEditingController).text);
    final bar = TextEditingController(text: (source['barcode'] as TextEditingController).text);
    final stockFinal = TextEditingController(text: (source['stockFinal'] as TextEditingController).text);

    spec.addListener(onSyncDraft);
    pVenta.addListener(onSyncDraft);
    costo.addListener(onSyncDraft);
    img.addListener(onSyncDraft);
    bar.addListener(onSyncDraft);
    stockFinal.addListener(onSyncDraft);

    final newMap = {
      'id': newId,
      'childId': null,
      'isEditMode': false,
      'isExpanded': true,
      'leftoverCreated': false,
      'specific': spec,
      'unidadVenta': TextEditingController(text: (source['unidadVenta'] as TextEditingController).text),
      'unidadesVenta': TextEditingController(text: (source['unidadesVenta'] as TextEditingController).text),
      'costoPres': costo,
      'margen': TextEditingController(text: (source['margen'] as TextEditingController).text),
      'precioVenta': pVenta,
      'descuentoActivo': source['descuentoActivo'] == true,
      'tipoDescuento': source['tipoDescuento'] ?? 'porcentaje',
      'valorDescuento': TextEditingController(text: (source['valorDescuento'] as TextEditingController).text),
      'stockInicial': TextEditingController(text: (source['stockInicial'] as TextEditingController).text),
      'nuevoIngreso': TextEditingController(text: (source['nuevoIngreso'] as TextEditingController).text),
      'stockDescuento': TextEditingController(text: (source['stockDescuento'] as TextEditingController).text),
      'stockFinal': stockFinal,
      'umpCompra': TextEditingController(text: (source['umpCompra'] as TextEditingController).text),
      'unidadesLote': TextEditingController(text: (source['unidadesLote'] as TextEditingController).text),
      'cantCompra': TextEditingController(text: (source['cantCompra'] as TextEditingController).text),
      'totalPago': TextEditingController(text: (source['totalPago'] as TextEditingController).text),
      'barcode': bar,
      'desc': TextEditingController(text: (source['desc'] as TextEditingController).text),
      'image': img,
      'ajusteBase': TextEditingController(text: (source['ajusteBase'] as TextEditingController).text),
      'providerId': source['providerId'],
      'isDefault': false,
      'estado': source['estado'] ?? 'publico',
      'activeRoundingTarget': source['activeRoundingTarget'] as double?,
      'preRoundedPrice': source['preRoundedPrice'] as String?,
      'preRoundedMargen': source['preRoundedMargen'] as String?,
      'usaStockCompartido': source['usaStockCompartido'] == true,
      'cupoMaximoVariante': source['cupoMaximoVariante'] as int?,
    };

    controllers.insert(index + 1, newMap);
    onSyncDraft();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 Variante clonada exitosamente"),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Crea variante sobrante fraccionada
  static void createLeftover({
    required String parentId,
    required int leftoverUnits,
    required double costoBaseIndividual,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex == -1) return;

    Map<String, dynamic> sourceMap = controllers[parentIndex];
    sourceMap['leftoverCreated'] = true;

    String newChildId = UniqueKey().toString();
    sourceMap['childId'] = newChildId;

    final newChild = ProductControllerFactory.createLeftoverControllerMap(
      parentMap: sourceMap,
      newChildId: newChildId,
      leftoverUnits: leftoverUnits,
      costoBaseIndividual: costoBaseIndividual,
    );

    (newChild['specific'] as TextEditingController).addListener(onSyncDraft);
    (newChild['precioVenta'] as TextEditingController).addListener(onSyncDraft);
    (newChild['costoPres'] as TextEditingController).addListener(onSyncDraft);
    (newChild['image'] as TextEditingController).addListener(onSyncDraft);
    (newChild['barcode'] as TextEditingController).addListener(onSyncDraft);
    (newChild['stockFinal'] as TextEditingController).addListener(onSyncDraft);

    keys[newChildId] = GlobalKey();
    controllers.insert(parentIndex + 1, newChild);

    final parentEngine = sourceMap['mathEngine'] as PresentationMathEngine?;
    parentEngine?.syncLeftoverState(false, true);

    onSyncDraft();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Variante sobrante creada debajo"),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Invalida variante sobrante fraccionada
  static void invalidateLeftover({
    required String parentId,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) {
    int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex != -1) {
      String? childId = controllers[parentIndex]['childId'];
      if (childId != null) {
        int childIndex = controllers.indexWhere((c) => c['id'] == childId);
        if (childIndex != -1) {
          ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
          controllers.removeAt(childIndex);
        }
      }
      controllers[parentIndex]['childId'] = null;
      controllers[parentIndex]['leftoverCreated'] = false;
      final parentEngine = controllers[parentIndex]['mathEngine'] as PresentationMathEngine?;
      parentEngine?.syncLeftoverState(true, false);
      onSyncDraft();
    }
  }

  /// Elimina una presentación y su variante sobrante si existe
  static void removePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    if (controllers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Debe haber al menos una presentación")),
      );
      return;
    }

    final item = controllers[index];
    final bool wasDefault = item['isDefault'] == true;
    String idToDelete = item['id'];
    String? childId = item['childId'];
    String? sourceParentId = item['sourceParentId'] as String?;
    final int transferred = (item['transferredBaseUnits'] as int?) ?? 0;

    // Reintegrar automáticamente a la variante padre si esta era su variante unitaria
    for (var c in controllers) {
      if (c['id'] == sourceParentId || c['childId'] == idToDelete) {
        c['childId'] = null;
        c['leftoverCreated'] = false;
        final parentEngine = c['mathEngine'] as PresentationMathEngine?;
        if (parentEngine != null) {
          if (transferred > 0) {
            parentEngine.originalBaseStock = parentEngine.originalBaseStock + transferred;
            parentEngine.trueOriginalBaseStock = parentEngine.originalBaseStock;
          }
          c['originalBaseStock'] = parentEngine.originalBaseStock;
          parentEngine.syncLeftoverState(true, false);
          parentEngine.calcularStockFinal();
        } else {
          if (transferred > 0) {
            c['originalBaseStock'] =
                ((c['originalBaseStock'] as int?) ?? 0) + transferred;
          }
        }
      }
    }

    ProductControllerFactory.disposeControllerMap(controllers[index]);
    controllers.removeAt(index);
    keys.remove(idToDelete);

    if (wasDefault && controllers.isNotEmpty) {
      controllers.first['isDefault'] = true;
    }

    if (childId != null) {
      int childIndex = controllers.indexWhere((c) => c['id'] == childId);
      if (childIndex != -1) {
        ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
        controllers.removeAt(childIndex);
        keys.remove(childId);
      }
    }

    onSyncDraft();
  }

  /// Asigna variante principal y mueve al inicio
  static void setDefault({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    if (index < 0 || index >= controllers.length) return;
    for (int i = 0; i < controllers.length; i++) {
      controllers[i]['isDefault'] = (i == index);
    }
    final item = controllers.removeAt(index);
    controllers.insert(0, item);
    item['isExpanded'] = true;
    onSyncDraft();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Presentación Principal actualizada"),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Reordena hacia arriba
  static void moveUp({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) {
    if (index <= 0) return;
    final item = controllers.removeAt(index);
    controllers.insert(index - 1, item);
    onSyncDraft();
    HapticFeedback.selectionClick();
  }

  /// Reordena hacia abajo
  static void moveDown({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) {
    if (index >= controllers.length - 1) return;
    final item = controllers.removeAt(index);
    controllers.insert(index + 1, item);
    onSyncDraft();
    HapticFeedback.selectionClick();
  }

  /// Limpieza total del formulario y borrador
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Formulario limpiado por completo"),
        backgroundColor: Colors.blueGrey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Guarda el nuevo producto con todas sus presentaciones
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
  }) async {
    if (!formKey.currentState!.validate()) return false;
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Completa la Información General (Nombre)"),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Validación preventiva de Caso C (Stock Base insuficiente para formar paquetes en variantes compartidas)
    if (modoStock == 'COMPARTIDO' || modoStock == 'MIXTO') {
      final sharedControllers = controllers.where((c) {
        if (modoStock == 'COMPARTIDO') return true;
        return c['usaStockCompartido'] == true;
      }).toList();

      if (sharedControllers.isNotEmpty && stockCompartido > 0) {
        final allZeroFormable = sharedControllers.every((c) {
          final factor = int.tryParse((c['unidadesVenta'] as TextEditingController?)?.text ?? '1') ?? 1;
          final safeFactor = factor <= 0 ? 1 : factor;
          return stockCompartido < safeFactor;
        });

        if (allZeroFormable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("El stock compartido no alcanza para formar ningún paquete. Agrega una variante por Unidad o ajusta el inventario."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }
      }
    }

    final String pDesc = descCtrl.text.trim();
    final String pImg = imgUrlCtrl.text.trim();
    final String pCode = barcodeCtrl.text.trim();
    List<ProductPresentation> presentations = [];

    try {
      for (var c in controllers) {
        String specific = (c['specific'] as TextEditingController).text.trim();
        String uVenta = (c['unidadVenta'] as TextEditingController).text.trim();
        int factorVenta = int.tryParse((c['unidadesVenta'] as TextEditingController).text) ?? 1;
        double margen = double.tryParse((c['margen'] as TextEditingController).text) ?? 1.35;
        double pVenta = double.tryParse((c['precioVenta'] as TextEditingController).text) ?? 0.0;
        int stockVisual = int.tryParse((c['stockFinal'] as TextEditingController).text) ?? 0;

        int stockBaseGuardar = stockVisual * factorVenta;
        String ajusteText = (c['ajusteBase'] as TextEditingController).text.trim();
        if (ajusteText.isNotEmpty) {
          stockBaseGuardar = int.tryParse(ajusteText) ?? stockBaseGuardar;
        }

        bool isShared = false;
        if (modoStock == 'COMPARTIDO') {
          isShared = true;
        } else if (modoStock == 'MIXTO') {
          isShared = c['usaStockCompartido'] == true;
        }

        int finalStockBase = isShared ? stockCompartido : stockBaseGuardar;

        if (factorVenta > 1 && !isShared) {
          StockValidationResult? validation = c['stockValidation'] as StockValidationResult?;
          if (validation == null) {
            int baseUnits = 0;
            if (ajusteText.isNotEmpty) {
              baseUnits = int.tryParse(ajusteText) ?? 0;
            } else {
              baseUnits = int.tryParse((c['stockInicial'] as TextEditingController).text) ?? 0;
              final cant = double.tryParse((c['cantCompra'] as TextEditingController).text) ?? 0.0;
              final lote = int.tryParse((c['unidadesLote'] as TextEditingController).text) ?? 1;
              if (baseUnits == 0 && cant > 0 && lote > 0) {
                baseUnits = (cant * lote).toInt();
              }
            }
            validation = UnitCatalogService.validateStockForUnit(
              totalUnitsBase: baseUnits,
              presentationFactor: factorVenta,
              baseUnitCost: 0.0,
              unitName: uVenta,
            );
          }

          if (validation.status == StockValidationStatus.deficit) {
            final key = keys?[c['id']];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ '${specific.isNotEmpty ? specific : uVenta}': ${validation.userMessage(uVenta, factorVenta)}"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            return false;
          }
          if (validation.status == StockValidationStatus.hasLeftover && c['leftoverCreated'] != true) {
            final key = keys?[c['id']];
            if (key?.currentContext != null) {
              Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300));
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ '${specific.isNotEmpty ? specific : uVenta}': ${validation.userMessage(uVenta, factorVenta)}"),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
            return false;
          }
        }

        String umpC = (c['umpCompra'] as TextEditingController).text.trim();
        double cantC = double.tryParse((c['cantCompra'] as TextEditingController).text) ?? 0.0;
        double totalP = double.tryParse((c['totalPago'] as TextEditingController).text) ?? 0.0;
        int loteC = int.tryParse((c['unidadesLote'] as TextEditingController).text) ?? 1;
        double costoPresFinal = double.tryParse((c['costoPres'] as TextEditingController).text) ?? 0.0;

        String rawDesc = (c['desc'] as TextEditingController).text.trim();
        String? finalDesc = (rawDesc.isEmpty && pDesc.isNotEmpty) ? pDesc : (rawDesc.isEmpty ? null : rawDesc);
        String rawImg = (c['image'] as TextEditingController).text.trim();
        String? finalImg = rawImg.isEmpty ? null : rawImg;
        String rawCode = (c['barcode'] as TextEditingController).text.trim();
        String? finalCode = (rawCode.isEmpty && pCode.isNotEmpty) ? pCode : (rawCode.isEmpty ? null : rawCode);

        bool descuentoActivo = c['descuentoActivo'] == true;
        String tipoDescuento = c['tipoDescuento'] as String;
        double valorDescuento = double.tryParse((c['valorDescuento'] as TextEditingController).text) ?? 0.0;

        double? precioOferta;
        if (descuentoActivo && valorDescuento > 0 && pVenta > 0) {
          if (c['precioOfertaExacto'] != null &&
              (c['precioOfertaExacto'] as num) > 0 &&
              (c['precioOfertaExacto'] as num) < pVenta) {
            precioOferta = (c['precioOfertaExacto'] as num).toDouble();
          } else if (tipoDescuento == 'porcentaje') {
            precioOferta = pVenta - (pVenta * (valorDescuento / 100));
          } else {
            precioOferta = pVenta - valorDescuento;
          }
        }

        final pId = c['providerId'] as int?;
        String? defVariantProvName;
        if (pId != null && pId < 0) {
          defVariantProvName = deferredProviderNames[pId];
        }

        presentations.add(
          ProductPresentation(
            nombreEspecifico: specific.isEmpty ? null : specific,
            unidadVenta: uVenta.isEmpty ? "Unidad" : uVenta,
            unidadesPorVenta: factorVenta,
            costoUnitarioCalculado: costoPresFinal,
            factorGananciaVenta: margen,
            precioVentaFinal: pVenta,
            stockActual: finalStockBase,
            usaStockCompartido: isShared,
            umpCompra: umpC.isEmpty ? null : umpC,
            cantidadUmpComprada: cantC > 0 ? cantC : null,
            totalPagoLote: totalP > 0 ? totalP : null,
            unidadesPorLote: loteC,
            precioUmpProveedor: cantC > 0 ? (totalP / cantC) : null,
            descripcion: finalDesc,
            imagenUrl: finalImg,
            codigoBarras: finalCode,
            estado: c['estado'] as String,
            esDefault: c['isDefault'] == true,
            proveedorId: (pId != null && pId > 0) ? pId : null,
            deferredProviderName: defVariantProvName,
            tipoDescuento: descuentoActivo ? tipoDescuento : null,
            valorDescuento: descuentoActivo && valorDescuento > 0 ? valorDescuento : null,
            precioOferta: precioOferta,
          ),
        );
      }
    } catch (e) {
      debugPrint("LOG: Error procesando controladores: $e");
      return false;
    }

    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String? defBrandName = (selectedBrandId != null && selectedBrandId < 0) ? selectedBrandName : null;
    final int? safeBrandId = (selectedBrandId != null && selectedBrandId > 0) ? selectedBrandId : null;
    final String? defCategoryName = (selectedCategoryId != null && selectedCategoryId < 0) ? selectedCategoryName : null;
    final int? safeCategoryId = (selectedCategoryId != null && selectedCategoryId > 0) ? selectedCategoryId : null;

    final String? defGenProvName = (generalProviderId != null && generalProviderId < 0)
        ? (deferredProviderNames[generalProviderId] ?? generalProviderName)
        : null;
    final int? safeGenProvId = (generalProviderId != null && generalProviderId > 0) ? generalProviderId : null;

    final success = await invProv.createFullProduct(
      nombre: nameCtrl.text.trim(),
      marcaId: safeBrandId,
      categoriaId: safeCategoryId,
      proveedorId: safeGenProvId,
      estado: generalState == 2 ? 'publico' : 'privado',
      descripcion: pDesc.isEmpty ? null : pDesc,
      imagenUrl: pImg.isEmpty ? null : pImg,
      codigoBarras: pCode.isEmpty ? null : pCode,
      presentaciones: presentations,
      deferredBrandName: defBrandName,
      deferredCategoryName: defCategoryName,
      deferredProviderName: defGenProvName,
      modoStock: modoStock,
      stockCompartido: stockCompartido,
      costoBase: costoBase,
    );

    if (success && context.mounted) {
      invProv.clearCreationDraft();
      await ProductSaveSuccessDialog.show(
        context: context,
        productName: nameCtrl.text.trim(),
        presentationCount: presentations.length,
        mode: ProductSaveDialogMode.create,
      );
      return true;
    } else if (context.mounted) {
      final msg = invProv.errorMessage.isNotEmpty
          ? invProv.errorMessage
          : "No se pudo registrar el producto";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
      );
    }
    return false;
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
      if (draft.barcode.isNotEmpty) barcodeCtrl.text = draft.barcode;

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
        addPresentation(
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

      // 🛡️ Situación 4: Inyección garantizada de initialBarcode en Padre y primera Variante con borrador
      if (initialBarcode != null && initialBarcode.trim().isNotEmpty) {
        final code = initialBarcode.trim();
        barcodeCtrl.text = code;
        if (controllers.isNotEmpty && controllers.first['barcode'] is TextEditingController) {
          (controllers.first['barcode'] as TextEditingController).text = code;
        }
      }

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
      addPresentation(
        controllers: controllers,
        keys: keys,
        onSyncDraft: onSyncDraft,
        generalProviderId: null,
        generalState: generalState,
        isDefault: true,
      );
    }

    // 🛡️ Situación 4: Inyección garantizada de initialBarcode en Padre y primera Variante sin borrador
    if (initialBarcode != null && initialBarcode.trim().isNotEmpty) {
      final code = initialBarcode.trim();
      barcodeCtrl.text = code;
      if (controllers.isNotEmpty && controllers.first['barcode'] is TextEditingController) {
        (controllers.first['barcode'] as TextEditingController).text = code;
      }
    }
    return null;
  }

  /// Hidrata el formulario de Crear Producto desde un bundle de extracción de variante
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
    // 1. Limpiar controladores previos
    for (var map in controllers) {
      ProductControllerFactory.disposeControllerMap(map);
    }
    keys.clear();
    controllers.clear();

    final general = bundle.generalData;
    final detail = bundle.detailData;

    // 2. Hidratar datos generales
    nameCtrl.text = detail.newProductName;
    descCtrl.text = general.copyDescription ? (general.description ?? "") : "";
    imgUrlCtrl.text = general.copyImages
        ? (general.imageUrl ?? "")
        : (detail.includeVariantImage ? (detail.variantImage ?? "") : "");
    barcodeCtrl.text = detail.includeBarcode ? (detail.barcode ?? "") : "";

    final String variantStock = detail.includeStock
        ? (detail.transferFullStock ? detail.stockUnits.toString() : "0")
        : "0";

    // 3. Crear variante principal en posición 0
    final String newId = UniqueKey().toString();
    keys[newId] = GlobalKey();

    final newMap = ProductControllerFactory.createNewControllerMap(
      id: newId,
      isDefault: true,
      isExpanded: true,
      isEditMode: false,
      specificName: detail.specificName ?? "",
      unidadVenta: detail.includeUnit ? detail.unitName : "Unidad",
      unidadesVenta: detail.includeUnit ? detail.unitFactor.toString() : "1",
      costoPres: detail.includePricing ? detail.costPrice.toStringAsFixed(2) : "0.00",
      margen: detail.includePricing ? detail.margin.toStringAsFixed(2) : "1.35",
      precioVenta: detail.includePricing ? detail.salePrice.toStringAsFixed(2) : "0.00",
      stockInicial: variantStock,
      stockFinal: variantStock,
      barcode: detail.includeBarcode ? (detail.barcode ?? "") : "",
      image: detail.includeVariantImage ? (detail.variantImage ?? "") : "",
      providerId: detail.variantProviderId,
      deferredProviderName: detail.variantProviderName,
      descuentoActivo: detail.hasDiscount,
      tipoDescuento: detail.discountType ?? "porcentaje",
      valorDescuento: detail.discountValue != null ? detail.discountValue.toString() : "",
    );
    newMap['stockAlerta'] = detail.includeStockAlert ? (detail.alertStock ?? 5) : 5;

    (newMap['specific'] as TextEditingController).addListener(onSyncDraft);
    (newMap['precioVenta'] as TextEditingController).addListener(onSyncDraft);
    (newMap['costoPres'] as TextEditingController).addListener(onSyncDraft);
    (newMap['image'] as TextEditingController).addListener(onSyncDraft);
    (newMap['barcode'] as TextEditingController).addListener(onSyncDraft);
    (newMap['stockFinal'] as TextEditingController).addListener(onSyncDraft);

    if (detail.variantProviderId != null &&
        detail.variantProviderId! < 0 &&
        detail.variantProviderName != null) {
      deferredProviderNames[detail.variantProviderId!] = detail.variantProviderName!;
    }

    controllers.add(newMap);

    final int? brandId = general.copyBrand ? general.brandId : null;
    final String? brandName = general.copyBrand ? general.brandName : null;
    final int? categoryId = general.copyCategory ? general.categoryId : null;
    final String? categoryName = general.copyCategory ? general.categoryName : null;
    final int? providerId = general.copyProvider ? general.generalProviderId : null;
    final String? providerName = general.copyProvider ? general.generalProviderName : null;

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
      modoStock: 'INDEPENDIENTE',
      stockCompartido: 0,
      costoBase: 0.0,
    );
  }

  static Future<bool> applyGeneralProviderChange({
    required BuildContext context,
    required int? newId,
    required String? newName,
    required bool isDark,
    required int? computedGeneralProviderId,
    required List<Map<String, dynamic>> controllers,
  }) async {
    if (computedGeneralProviderId != -2 && controllers.length <= 1) {
      for (var c in controllers) {
        c['providerId'] = newId;
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
          "Esta acción cambiará el proveedor de TODAS las presentaciones.",
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
      }
      return true;
    }
    return false;
  }
}

class ProductCreateHydratedData {
  final int? brandId;
  final String? brandName;
  final int? categoryId;
  final String? categoryName;
  final int? generalProviderId;
  final String? generalProviderName;
  final String modoStock;
  final int stockCompartido;
  final double costoBase;

  const ProductCreateHydratedData({
    this.brandId,
    this.brandName,
    this.categoryId,
    this.categoryName,
    this.generalProviderId,
    this.generalProviderName,
    this.modoStock = 'INDEPENDIENTE',
    this.stockCompartido = 0,
    this.costoBase = 0.0,
  });
}
