part of '../product_edit_operations.dart';

void _restoreParentTransferredStock(
  Map<String, dynamic> parentCtrl,
  int transferred,
) {
  parentCtrl['childId'] = null;
  parentCtrl['leftoverCreated'] = false;
  final parentEngine = parentCtrl['mathEngine'] as PresentationMathEngine?;
  if (parentEngine != null) {
    if (transferred > 0) {
      parentEngine.originalBaseStock =
          parentEngine.originalBaseStock + transferred;
      parentEngine.trueOriginalBaseStock = parentEngine.originalBaseStock;
    }
    parentCtrl['originalBaseStock'] = parentEngine.originalBaseStock;
    parentEngine.syncLeftoverState(true, false);
    parentEngine.matematicaSimpleEdicion();
  } else if (transferred > 0) {
    parentCtrl['originalBaseStock'] =
        ((parentCtrl['originalBaseStock'] as int?) ?? 0) + transferred;
  }
}

void _createLeftoverImpl({
  required BuildContext context,
  required String parentId,
  required int leftoverUnits,
  required double costoBaseIndividual,
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
}) {
  final int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
  if (parentIndex == -1) {
    return;
  }

  final Map<String, dynamic> sourceMap = controllers[parentIndex];
  sourceMap['leftoverCreated'] = true;

  final String newChildId = UniqueKey().toString();
  sourceMap['childId'] = newChildId;
  keys[newChildId] = GlobalKey();

  final newChild = ProductControllerFactory.createLeftoverControllerMap(
    parentMap: sourceMap,
    newChildId: newChildId,
    leftoverUnits: leftoverUnits,
    costoBaseIndividual: costoBaseIndividual,
  );

  controllers.insert(parentIndex + 1, newChild);

  final parentEngine = sourceMap['mathEngine'] as PresentationMathEngine?;
  if (parentEngine != null) {
    parentEngine.originalBaseStock =
        (parentEngine.originalBaseStock - leftoverUnits).clamp(0, 99999999);
    parentEngine.trueOriginalBaseStock = parentEngine.originalBaseStock;
    sourceMap['originalBaseStock'] = parentEngine.originalBaseStock;
    parentEngine.syncLeftoverState(false, true);
    parentEngine.matematicaSimpleEdicion();
  } else {
    sourceMap['originalBaseStock'] =
        (((sourceMap['originalBaseStock'] as int?) ?? 0) - leftoverUnits).clamp(
          0,
          99999999,
        );
  }

  AppFeedbackHelper.showSnackBar(
    context,
    "Variante sobrante creada debajo",
    backgroundColor: Colors.green,
  );
}

void _invalidateLeftoverImpl({
  required String parentId,
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
}) {
  final int parentIndex = controllers.indexWhere((c) => c['id'] == parentId);
  if (parentIndex == -1) {
    return;
  }

  final String? childId = controllers[parentIndex]['childId'] as String?;
  int transferred = 0;
  if (childId != null) {
    final int childIndex = controllers.indexWhere((c) => c['id'] == childId);
    if (childIndex != -1) {
      transferred =
          (controllers[childIndex]['transferredBaseUnits'] as int?) ?? 0;
      ProductControllerFactory.disposeControllerMap(controllers[childIndex]);
      controllers.removeAt(childIndex);
      keys.remove(childId);
    }
  }
  _restoreParentTransferredStock(controllers[parentIndex], transferred);
}

Future<void> _deletePresentationImpl({
  required BuildContext context,
  required int index,
  required bool isDark,
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
  required List<int> idsToDelete,
  required VoidCallback onDeleted,
}) async {
  if (controllers.length <= 1) {
    AppFeedbackHelper.showSnackBar(
      context,
      "El producto debe tener al menos una presentación.",
      backgroundColor: Colors.orange,
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

  if (confirm != true) {
    return;
  }

  if (item['db_id'] != null) {
    idsToDelete.add(item['db_id']);
  }

  final String deletedId = item['id'];
  final String? sourceParentId = item['sourceParentId'] as String?;
  final int transferred = (item['transferredBaseUnits'] as int?) ?? 0;

  for (final c in controllers) {
    if (c['id'] == sourceParentId || c['childId'] == deletedId) {
      _restoreParentTransferredStock(c, transferred);
    }
  }

  final String? childId = item['childId'] as String?;
  ProductControllerFactory.disposeControllerMap(controllers[index]);
  controllers.removeAt(index);
  keys.remove(item['id']);

  if (childId != null) {
    final int childIndex = controllers.indexWhere((c) => c['id'] == childId);
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
    AppFeedbackHelper.showSnackBar(
      context,
      wasDefault
          ? "Variante eliminada. La siguiente fue promovida a Principal."
          : "Variante eliminada.",
      backgroundColor: wasDefault ? Colors.teal : Colors.grey[800],
    );
  }
}

Future<void> _finalizeVariantExtractionCutImpl({
  required BuildContext context,
  required ProductExtractionResult result,
  required List<Map<String, dynamic>> controllers,
  required Map<String, GlobalKey> keys,
  required int originProductId,
  required VoidCallback onCompleted,
  InventoryProvider? inventoryProvider,
  TextEditingController? sharedStockCtrl,
}) async {
  int index = -1;
  if (result.variantDbId != null) {
    index = controllers.indexWhere((c) => c['db_id'] == result.variantDbId);
  }
  if (index == -1) {
    index = controllers.indexWhere((c) => c['id'] == result.variantLocalId);
  }
  if (index == -1 && controllers.isNotEmpty) {
    index = 0;
  }
  if (index == -1) {
    return;
  }

  final targetMap = controllers[index];
  final bool wasDefault =
      targetMap['isDefault'] == true || result.wasOriginDefault;

  final String deletedId = targetMap['id']?.toString() ?? '';
  final String? sourceParentId = targetMap['sourceParentId'] as String?;
  for (final c in controllers) {
    if (c['id'] == sourceParentId || c['childId'] == deletedId) {
      c['childId'] = null;
      c['leftoverCreated'] = false;
    }
    if (c['sourceParentId'] == deletedId) {
      c['sourceParentId'] = null;
    }
  }

  if (result.isSharedOrigin &&
      result.shouldDeductSharedPool &&
      result.transferredBaseUnits > 0 &&
      sharedStockCtrl != null) {
    final int currentShared = int.tryParse(sharedStockCtrl.text) ?? 0;
    final int newShared = (currentShared - result.transferredBaseUnits) > 0
        ? (currentShared - result.transferredBaseUnits)
        : 0;
    sharedStockCtrl.text = newShared.toString();

    for (final c in controllers) {
      if (c['id'] != targetMap['id'] && c['usaStockCompartido'] == true) {
        final int factor =
            int.tryParse(
              (c['unidadesVenta'] as TextEditingController?)?.text ?? '1',
            ) ??
            1;
        final int safeFactor = factor <= 0 ? 1 : factor;
        final int availableUnits = newShared ~/ safeFactor;
        final int? cupo = c['cupoMaximoVariante'] as int?;
        if (cupo == null || cupo > availableUnits) {
          (c['stockFinal'] as TextEditingController?)?.text = availableUnits
              .toString();
        }
      }
    }
  }

  controllers.removeAt(index);
  keys.remove(targetMap['id']);

  for (int i = 0; i < controllers.length; i++) {
    controllers[i]['orden'] = i;
  }

  int? newDefaultDbId;
  if (wasDefault && controllers.isNotEmpty) {
    controllers.first['isDefault'] = true;
    newDefaultDbId = controllers.first['db_id'] as int?;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ProductControllerFactory.disposeControllerMap(targetMap);
  });

  InventoryProvider? invProv;
  try {
    invProv =
        inventoryProvider ??
        (context.mounted
            ? Provider.of<InventoryProvider>(context, listen: false)
            : null);
  } catch (_) {}

  if (result.variantDbId != null && invProv != null) {
    await invProv.cutVariantFromProduct(
      presentationId: result.variantDbId!,
      originProductId: originProductId,
      promoteToDefaultPresentationId: newDefaultDbId,
      transferredBarcode: result.transferredBarcode,
      transferredStock: result.transferredStock,
      transferredBaseUnits: result.transferredBaseUnits,
      isSharedVariant: result.isSharedOrigin,
      shouldDeductSharedPool: result.shouldDeductSharedPool,
    );
  } else if (invProv != null) {
    await invProv.loadMasterData(showAll: true);
  }

  onCompleted();
}
