import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/widgets/presentation_card/presentation_math_engine.dart';
import 'package:app_movil/features/catalog/widgets/form/product_controller_factory.dart';
import 'package:app_movil/features/catalog/widgets/form/create_operations/product_create_draft_and_hydration.dart';

class ProductCreatePresentationOps {
  ProductCreatePresentationOps._();

  static void addPresentation({
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required int? generalProviderId,
    required int generalState,
    bool isDefault = false,
  }) {
    final String newId = UniqueKey().toString();
    keys[newId] = GlobalKey();

    final newMap = <String, dynamic>{
      'id': newId,
      'childId': null,
      'isEditMode': false,
      'isExpanded': true,
      'leftoverCreated': false,
      'specific': TextEditingController(),
      'unidadVenta': TextEditingController(text: "Unidad"),
      'unidadesVenta': TextEditingController(text: "1"),
      'costoPres': TextEditingController(text: "0.00"),
      'margen': TextEditingController(text: "1.35"),
      'precioVenta': TextEditingController(text: ""),
      'descuentoActivo': false,
      'tipoDescuento': 'porcentaje',
      'valorDescuento': TextEditingController(text: ""),
      'stockInicial': TextEditingController(text: "0"),
      'nuevoIngreso': TextEditingController(text: ""),
      'stockDescuento': TextEditingController(text: "0"),
      'stockFinal': TextEditingController(text: "0"),
      'umpCompra': TextEditingController(text: ""),
      'unidadesLote': TextEditingController(text: ""),
      'cantCompra': TextEditingController(text: ""),
      'totalPago': TextEditingController(text: ""),
      'barcode': TextEditingController(),
      'desc': TextEditingController(),
      'image': TextEditingController(),
      'ajusteBase': TextEditingController(),
      'providerId': generalProviderId == -2 ? null : generalProviderId,
      'isDefault': isDefault,
      'estado': generalState == 0 ? 'privado' : 'publico',
      'activeRoundingTarget': null,
      'preRoundedPrice': null,
      'preRoundedMargen': null,
    };

    ProductCreateDraftAndHydration.attachSyncListeners(newMap, onSyncDraft);
    controllers.add(newMap);
    onSyncDraft();
  }

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

    String readCtrl(String k) => (source[k] as TextEditingController).text;

    final newMap = <String, dynamic>{
      'id': newId,
      'childId': null,
      'isEditMode': false,
      'isExpanded': true,
      'leftoverCreated': false,
      'specific': TextEditingController(text: readCtrl('specific')),
      'unidadVenta': TextEditingController(text: readCtrl('unidadVenta')),
      'unidadesVenta': TextEditingController(text: readCtrl('unidadesVenta')),
      'costoPres': TextEditingController(text: readCtrl('costoPres')),
      'margen': TextEditingController(text: readCtrl('margen')),
      'precioVenta': TextEditingController(text: readCtrl('precioVenta')),
      'descuentoActivo': source['descuentoActivo'] == true,
      'tipoDescuento': source['tipoDescuento'] ?? 'porcentaje',
      'valorDescuento': TextEditingController(text: readCtrl('valorDescuento')),
      'stockInicial': TextEditingController(text: readCtrl('stockInicial')),
      'nuevoIngreso': TextEditingController(text: readCtrl('nuevoIngreso')),
      'stockDescuento': TextEditingController(text: readCtrl('stockDescuento')),
      'stockFinal': TextEditingController(text: readCtrl('stockFinal')),
      'umpCompra': TextEditingController(text: readCtrl('umpCompra')),
      'unidadesLote': TextEditingController(text: readCtrl('unidadesLote')),
      'cantCompra': TextEditingController(text: readCtrl('cantCompra')),
      'totalPago': TextEditingController(text: readCtrl('totalPago')),
      'barcode': TextEditingController(text: readCtrl('barcode')),
      'desc': TextEditingController(text: readCtrl('desc')),
      'image': TextEditingController(text: readCtrl('image')),
      'ajusteBase': TextEditingController(text: readCtrl('ajusteBase')),
      'providerId': source['providerId'],
      'isDefault': false,
      'estado': source['estado'] ?? 'publico',
      'activeRoundingTarget': source['activeRoundingTarget'] as double?,
      'preRoundedPrice': source['preRoundedPrice'] as String?,
      'preRoundedMargen': source['preRoundedMargen'] as String?,
      'usaStockCompartido': source['usaStockCompartido'] == true,
      'cupoMaximoVariante': source['cupoMaximoVariante'] as int?,
    };

    ProductCreateDraftAndHydration.attachSyncListeners(newMap, onSyncDraft);
    controllers.insert(index + 1, newMap);
    onSyncDraft();
    HapticFeedback.mediumImpact();
    AppFeedbackHelper.showSnackBar(
      context,
      "Variante clonada exitosamente",
      backgroundColor: Colors.teal,
      duration: const Duration(seconds: 2),
    );
  }

  static void createLeftover({
    required String parentId,
    required int leftoverUnits,
    required double costoBaseIndividual,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    final int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex == -1) return;

    final Map<String, dynamic> sourceMap = controllers[parentIndex];
    sourceMap['leftoverCreated'] = true;

    final String newChildId = UniqueKey().toString();
    sourceMap['childId'] = newChildId;

    final newChild = ProductControllerFactory.createLeftoverControllerMap(
      parentMap: sourceMap,
      newChildId: newChildId,
      leftoverUnits: leftoverUnits,
      costoBaseIndividual: costoBaseIndividual,
    );

    ProductCreateDraftAndHydration.attachSyncListeners(newChild, onSyncDraft);

    keys[newChildId] = GlobalKey();
    controllers.insert(parentIndex + 1, newChild);

    final parentEngine = sourceMap['mathEngine'] as PresentationMathEngine?;
    parentEngine?.syncLeftoverState(false, true);

    onSyncDraft();
    AppFeedbackHelper.showSnackBar(
      context,
      "Variante sobrante creada debajo",
      backgroundColor: Colors.green,
    );
  }

  static void invalidateLeftover({
    required String parentId,
    required List<Map<String, dynamic>> controllers,
    required VoidCallback onSyncDraft,
  }) {
    final int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
    if (parentIndex != -1) {
      final String? childId = controllers[parentIndex]['childId'];
      if (childId != null) {
        final int childIndex = controllers.indexWhere(
          (c) => c['id'] == childId,
        );
        if (childIndex != -1) {
          ProductControllerFactory.disposeControllerMap(
            controllers[childIndex],
          );
          controllers.removeAt(childIndex);
        }
      }
      controllers[parentIndex]['childId'] = null;
      controllers[parentIndex]['leftoverCreated'] = false;
      final parentEngine =
          controllers[parentIndex]['mathEngine'] as PresentationMathEngine?;
      parentEngine?.syncLeftoverState(true, false);
      onSyncDraft();
    }
  }

  static void removePresentation({
    required int index,
    required List<Map<String, dynamic>> controllers,
    required Map<String, GlobalKey> keys,
    required VoidCallback onSyncDraft,
    required BuildContext context,
  }) {
    if (controllers.length <= 1) {
      AppFeedbackHelper.showSnackBar(
        context,
        "Debe haber al menos una presentación",
      );
      return;
    }

    final item = controllers[index];
    final bool wasDefault = item['isDefault'] == true;
    final String idToDelete = item['id'];
    final String? childId = item['childId'];
    final String? sourceParentId = item['sourceParentId'] as String?;
    final int transferred = (item['transferredBaseUnits'] as int?) ?? 0;

    for (var c in controllers) {
      if (c['id'] == sourceParentId || c['childId'] == idToDelete) {
        c['childId'] = null;
        c['leftoverCreated'] = false;
        final parentEngine = c['mathEngine'] as PresentationMathEngine?;
        if (parentEngine != null) {
          if (transferred > 0) {
            parentEngine.originalBaseStock =
                parentEngine.originalBaseStock + transferred;
            parentEngine.trueOriginalBaseStock = parentEngine.originalBaseStock;
          }
          c['originalBaseStock'] = parentEngine.originalBaseStock;
          parentEngine.syncLeftoverState(true, false);
          parentEngine.calcularStockFinal();
        } else if (transferred > 0) {
          c['originalBaseStock'] =
              ((c['originalBaseStock'] as int?) ?? 0) + transferred;
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
      final int childIndex = controllers.indexWhere((c) => c['id'] == childId);
      if (childIndex != -1) {
        ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
        controllers.removeAt(childIndex);
        keys.remove(childId);
      }
    }

    onSyncDraft();
  }

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
    AppFeedbackHelper.showSnackBar(
      context,
      "Presentación Principal actualizada",
      backgroundColor: Colors.teal,
      duration: const Duration(seconds: 2),
    );
  }

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
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "Esta acción cambiará el proveedor de TODAS las presentaciones.",
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
      for (var c in controllers) {
        c['providerId'] = newId;
      }
      return true;
    }
    return false;
  }
}
