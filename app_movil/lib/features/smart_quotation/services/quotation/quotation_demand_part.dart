part of '../quotation_service.dart';

class _ValidationAccumulator {
  final Map<int, int> totalDemandPerPres = {};
  final Map<int, int> factorPerPres = {};
  final Map<int, int> currentStockPerPres = {};
  final Map<int, int?> cupoPerPres = {};
  final Map<int, bool> usaSharedStockPerPres = {};
  final Map<int, int> productIdPerPres = {};
  final Map<int, int> totalDemandPerSharedProduct = {};
  final Map<int, int> sharedStockPerProduct = {};
  final Set<int> conflictProdIds = {};

  bool hasIssues = false;
  bool canSell = true;
  final List<StockWarning> warnings = [];
  final List<PriceChange> prices = [];
  final List<NameChange> nameChanges = [];
  final List<BundleChange> bundleChanges = [];
  final List<UnitChange> unitChanges = [];
  final List<SharedStockConflict> sharedConflicts = [];
}

extension _QuotationDemandPart on QuotationService {
  Future<void> _ensurePresentationStockLoaded(
    dynamic db,
    _ValidationAccumulator acc,
    int pId,
  ) async {
    if (acc.factorPerPres.containsKey(pId)) return;

    final prRows = await db.query(
      'presentaciones_producto',
      columns: [
        'producto_id',
        'stock_actual',
        'unidades_por_venta',
        'usa_stock_compartido',
        'cupo_maximo_variante',
      ],
      where: 'id = ?',
      whereArgs: [pId],
    );
    if (prRows.isNotEmpty) {
      int factor = (prRows.first['unidades_por_venta'] as int?) ?? 1;
      if (factor <= 0) factor = 1;
      acc.factorPerPres[pId] = factor;
      acc.currentStockPerPres[pId] =
          (prRows.first['stock_actual'] as int?) ?? 0;
      acc.cupoPerPres[pId] = prRows.first['cupo_maximo_variante'] as int?;
      final int prodId = (prRows.first['producto_id'] as int?) ?? 0;
      final bool isShared =
          (prRows.first['usa_stock_compartido'] as int? ?? 0) == 1;
      acc.usaSharedStockPerPres[pId] = isShared;
      acc.productIdPerPres[pId] = prodId;
      if (isShared &&
          prodId > 0 &&
          !acc.sharedStockPerProduct.containsKey(prodId)) {
        final pRows = await db.query(
          'productos',
          columns: ['stock_compartido'],
          where: 'id = ?',
          whereArgs: [prodId],
        );
        acc.sharedStockPerProduct[prodId] = pRows.isNotEmpty
            ? ((pRows.first['stock_compartido'] as int?) ??
                  acc.currentStockPerPres[pId]!)
            : acc.currentStockPerPres[pId]!;
      }
    } else {
      acc.factorPerPres[pId] = 1;
      acc.currentStockPerPres[pId] = 0;
      acc.cupoPerPres[pId] = null;
      acc.usaSharedStockPerPres[pId] = false;
      acc.productIdPerPres[pId] = 0;
    }
  }

  void _accumulateDemand(_ValidationAccumulator acc, int pId, int unitQty) {
    final int factor = acc.factorPerPres[pId]!;
    final int totalBaseUnits = unitQty * factor;
    final bool isShared = acc.usaSharedStockPerPres[pId] ?? false;
    final int prodId = acc.productIdPerPres[pId] ?? 0;
    if (isShared && prodId > 0) {
      acc.totalDemandPerSharedProduct[prodId] =
          (acc.totalDemandPerSharedProduct[prodId] ?? 0) + totalBaseUnits;
    } else {
      acc.totalDemandPerPres[pId] =
          (acc.totalDemandPerPres[pId] ?? 0) + totalBaseUnits;
    }
  }

  Future<void> _collectDemandAndSharedConflicts(
    dynamic db,
    List<Map<String, dynamic>> iRows,
    _ValidationAccumulator acc,
  ) async {
    // 1. Acumular demanda total en unidades base para detectar colisiones y desabastecimiento
    for (final item in iRows) {
      if (item['bundle_id'] != null) {
        final int bId = item['bundle_id'] as int;
        final int qty = (item['quantity'] as int?) ?? 1;
        final bItems = await db.query(
          'items_paquete',
          where: 'paquete_id = ?',
          whereArgs: [bId],
        );
        for (final bItem in bItems) {
          final int pId = bItem['presentacion_id'] as int;
          final int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
          await _ensurePresentationStockLoaded(db, acc, pId);
          _accumulateDemand(acc, pId, reqQty * qty);
        }
      } else if (item['presentation_id'] != null) {
        final int pId = item['presentation_id'] as int;
        final int qty = (item['quantity'] as int?) ?? 1;
        await _ensurePresentationStockLoaded(db, acc, pId);
        _accumulateDemand(acc, pId, qty);
      }
    }

    // 1.1 Detección precisa de conflictos de stock compartido acumulado (a nivel de pool)
    final Map<int, List<QuoteItemConflictDetail>> sharedConflictItemsByProd =
        {};

    for (final item in iRows) {
      if (item['presentation_id'] != null) {
        final int pId = item['presentation_id'] as int;
        final bool isShared = acc.usaSharedStockPerPres[pId] ?? false;
        final int prodId = acc.productIdPerPres[pId] ?? 0;
        if (isShared && prodId > 0) {
          final pool = acc.sharedStockPerProduct[prodId] ?? 0;
          final demanded = acc.totalDemandPerSharedProduct[prodId] ?? 0;
          if (demanded > pool) {
            acc.conflictProdIds.add(prodId);
            final factor = acc.factorPerPres[pId] ?? 1;
            final qty = (item['quantity'] as int?) ?? 1;
            sharedConflictItemsByProd
                .putIfAbsent(prodId, () => [])
                .add(
                  QuoteItemConflictDetail(
                    itemId: item['id'] as int,
                    presentationId: pId,
                    presentationName:
                        (item['specific_name'] as String?) ??
                        (item['product_name'] as String? ?? ''),
                    requestedQty: qty,
                    conversionFactor: factor,
                    requestedBaseUnits: qty * factor,
                    cupoMaximo: acc.cupoPerPres[pId],
                  ),
                );
          }
        }
      }
    }

    for (final prodId in acc.conflictProdIds) {
      final pool = acc.sharedStockPerProduct[prodId] ?? 0;
      final demanded = acc.totalDemandPerSharedProduct[prodId] ?? 0;
      final items = sharedConflictItemsByProd[prodId] ?? [];
      String pName = "Producto compartido";
      final pRow = await db.query(
        'productos',
        columns: ['nombre'],
        where: 'id = ?',
        whereArgs: [prodId],
      );
      if (pRow.isNotEmpty) {
        pName = (pRow.first['nombre'] as String?) ?? pName;
      }
      acc.hasIssues = true;
      acc.canSell = false;
      acc.sharedConflicts.add(
        SharedStockConflict(
          productId: prodId,
          productName: pName,
          totalSharedPool: pool,
          totalRequestedBaseUnits: demanded,
          excessBaseUnits: demanded - pool,
          conflictingItems: items,
        ),
      );
    }
  }
}
