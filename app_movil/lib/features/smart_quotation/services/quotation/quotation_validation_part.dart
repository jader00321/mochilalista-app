part of '../quotation_service.dart';

extension _QuotationValidationPart on QuotationService {
  Future<void> _validateBundleQuotationItem(
    dynamic db,
    Map<String, dynamic> item,
    _ValidationAccumulator acc,
  ) async {
    final int bId = item['bundle_id'] as int;
    final int qty = item['quantity'] as int;
    final String? itemName = item['product_name'] as String?;

    final bItems = await db.query(
      'items_paquete',
      where: 'paquete_id = ?',
      whereArgs: [bId],
    );
    for (final bItem in bItems) {
      final int pId = bItem['presentacion_id'] as int;
      final int reqQty = (bItem['cantidad_requerida'] as int?) ?? 1;
      final int factor = acc.factorPerPres[pId] ?? 1;
      final int totalDeductBase = reqQty * qty * factor;
      final int demandedBase = acc.totalDemandPerPres[pId] ?? totalDeductBase;
      final int currentStock = acc.currentStockPerPres[pId] ?? 0;

      if (!acc.currentStockPerPres.containsKey(pId) ||
          (currentStock == 0 && !acc.factorPerPres.containsKey(pId))) {
        acc.hasIssues = true;
        acc.canSell = false;
        acc.warnings.add(
          StockWarning(
            itemId: item['id'] as int,
            productName: itemName ?? "Paquete",
            requested: reqQty * qty,
            available: 0,
            message: "Un componente del paquete ya no existe en el catálogo.",
          ),
        );
      } else if (currentStock < demandedBase) {
        acc.hasIssues = true;
        acc.canSell = false;
        final int availableUnits = (currentStock / factor).floor();
        final int reqTotal = (demandedBase / factor).ceil();
        acc.warnings.add(
          StockWarning(
            itemId: item['id'] as int,
            productName: itemName ?? "Paquete",
            requested: reqTotal,
            available: availableUnits,
            message:
                "Componente sin stock suficiente (requiere $reqTotal, disponible $availableUnits).",
          ),
        );
      }
    }

    // --- Validación adicional para bundles (Deep Compare) ---
    final bRows = await db.query('paquetes', where: 'id = ?', whereArgs: [bId]);
    if (bRows.isEmpty) {
      acc.hasIssues = true;
      acc.canSell = false;
      acc.bundleChanges.add(
        BundleChange(
          itemId: item['id'] as int,
          bundleId: bId,
          bundleName: item['product_name'] as String? ?? "Oferta",
          changes: ["La oferta fue eliminada del catálogo"],
          isDeleted: true,
        ),
      );
      return;
    }

    final bundle = bRows.first;
    final bool bundleActive = (bundle['activo'] as int?) == 1;
    if (!bundleActive) {
      acc.hasIssues = true;
      acc.canSell = false;
      acc.bundleChanges.add(
        BundleChange(
          itemId: item['id'] as int,
          bundleId: bId,
          bundleName: bundle['nombre_paquete'] as String? ?? "Oferta",
          changes: ["La oferta fue desactivada por el administrador"],
          isDeactivated: true,
        ),
      );
      return;
    }

    final List<String> detectedChanges = [];
    bool isBlockingChange = false;

    final String currentName = bundle['nombre_paquete'] as String? ?? "";
    final String savedName = item['product_name'] as String? ?? "";
    if (currentName.toLowerCase() != savedName.toLowerCase()) {
      detectedChanges.add("Nombre: \"$savedName\" → \"$currentName\"");
    }

    final double currentPrice = (bundle['precio_venta_total'] as num)
        .toDouble();
    final double appliedPrice = (item['unit_price_applied'] as num).toDouble();
    final bool isManual =
        item['is_manual_price'] == 1 || item['is_manual_price'] == true;
    if (!isManual && (appliedPrice - currentPrice).abs() > 0.01) {
      detectedChanges.add(
        "Precio: ${AppCurrency.format(appliedPrice)} → ${AppCurrency.format(currentPrice)}",
      );
    }

    final String currentType = bundle['tipo_promocion'] as String? ?? "paquete";
    final String? savedSnapshotJson = item['bundle_items_snapshot'] as String?;

    if (savedSnapshotJson != null && savedSnapshotJson.isNotEmpty) {
      try {
        final savedSnapshot = jsonDecode(savedSnapshotJson);
        final savedItems = (savedSnapshot['items'] as List?) ?? [];
        final currentBundleItems = await db.query(
          'items_paquete',
          where: 'paquete_id = ?',
          whereArgs: [bId],
        );

        if (savedItems.length != currentBundleItems.length) {
          detectedChanges.add(
            "Composición: ${savedItems.length} productos → ${currentBundleItems.length} productos",
          );
          isBlockingChange = true;
        } else {
          for (final savedItem in savedItems) {
            final int savedPresId = savedItem['presentacion_id'] as int;
            final int savedQty = savedItem['cantidad_requerida'] as int;
            final match = currentBundleItems
                .where((ci) => ci['presentacion_id'] == savedPresId)
                .firstOrNull;
            if (match == null) {
              detectedChanges.add(
                "Se removió un producto de la oferta (ID: $savedPresId)",
              );
              isBlockingChange = true;
            } else if ((match['cantidad_requerida'] as int? ?? 1) != savedQty) {
              detectedChanges.add(
                "Cambió la cantidad de un componente de la oferta",
              );
              isBlockingChange = true;
            }
          }
          for (final current in currentBundleItems) {
            final int currentPresId = current['presentacion_id'] as int;
            if (!savedItems.any(
              (si) => si['presentacion_id'] == currentPresId,
            )) {
              detectedChanges.add("Se agregó un nuevo producto a la oferta");
              isBlockingChange = true;
            }
          }
        }

        final String? savedType = savedSnapshot['bundle_type'] as String?;
        if (savedType != null && savedType != currentType) {
          detectedChanges.add("Tipo: \"$savedType\" → \"$currentType\"");
          isBlockingChange = true;
        }
      } catch (e) {
        debugPrint("Error parseando snapshot del bundle: $e");
      }
    } else {
      // Si no hay snapshot, igual comparamos descripción por retrocompatibilidad
      final String currentDesc = bundle['descripcion'] as String? ?? "";
      final String? specificName = item['specific_name'] as String?;
      if (specificName != null &&
          specificName.toLowerCase() != currentDesc.toLowerCase()) {
        detectedChanges.add("La descripción de la oferta cambió.");
        isBlockingChange = true;
      }
    }

    if (detectedChanges.isNotEmpty) {
      acc.hasIssues = true;
      if (isBlockingChange) acc.canSell = false;

      acc.bundleChanges.add(
        BundleChange(
          itemId: item['id'] as int,
          bundleId: bId,
          bundleName: currentName,
          changes: detectedChanges,
          oldPrice: appliedPrice,
          newPrice: currentPrice,
          isCompositionChange: isBlockingChange,
        ),
      );
    }
  }

  Future<void> _validatePresentationQuotationItem(
    dynamic db,
    Map<String, dynamic> item,
    _ValidationAccumulator acc,
  ) async {
    final int pId = item['presentation_id'] as int;
    final prRows = await db.query(
      'presentaciones_producto',
      where: 'id = ?',
      whereArgs: [pId],
    );
    if (prRows.isEmpty) {
      acc.hasIssues = true;
      acc.canSell = false;
      acc.warnings.add(
        StockWarning(
          itemId: item['id'] as int,
          productName: item['product_name'] as String? ?? "Desconocido",
          requested: item['quantity'] as int,
          available: 0,
          message: "Este producto ya no existe en el catálogo.",
        ),
      );
      return;
    }

    final pres = prRows.first;

    // --- Validación de Nombre y Variante/Presentación ---
    final String? itemName = item['product_name'] as String?;
    String? realName;
    final prodRows = await db.query(
      'productos',
      where: 'id = ?',
      whereArgs: [item['product_id']],
    );
    if (prodRows.isNotEmpty) {
      realName = prodRows.first['nombre'] as String?;
    }

    final String? itemSpecific = item['specific_name'] as String?;
    final String? realSpecific = pres['nombre_especifico'] as String?;

    if (itemName != null &&
        realName != null &&
        itemName.toLowerCase() != realName.toLowerCase()) {
      acc.hasIssues = true;
      acc.nameChanges.add(
        NameChange(
          itemId: item['id'] as int,
          oldName: itemName,
          newName: realName,
          message: "El nombre del producto cambió en el catálogo.",
        ),
      );
    } else if (itemSpecific != null &&
        realSpecific != null &&
        itemSpecific.toLowerCase() != realSpecific.toLowerCase()) {
      acc.hasIssues = true;
      acc.nameChanges.add(
        NameChange(
          itemId: item['id'] as int,
          oldName: "${itemName ?? ''} ($itemSpecific)",
          newName: "${itemName ?? ''} ($realSpecific)",
          message: "La presentación o variante cambió en el catálogo.",
        ),
      );
    }

    // --- Validación de Precios y Ofertas ---
    final double basePrice = (pres['precio_venta_final'] as num).toDouble();
    final double currentPrice =
        (pres['precio_oferta'] != null && (pres['precio_oferta'] as num) > 0)
        ? (pres['precio_oferta'] as num).toDouble()
        : basePrice;

    final int currentStock = pres['stock_actual'] as int;

    final bool isManual =
        item['is_manual_price'] == 1 || item['is_manual_price'] == true;
    final double appliedPrice = (item['unit_price_applied'] as num).toDouble();
    final double originalPrice = (item['original_unit_price'] as num)
        .toDouble();

    if (!isManual && appliedPrice != currentPrice) {
      acc.hasIssues = true;

      String message = "";
      if (appliedPrice == originalPrice && currentPrice < basePrice) {
        message = "¡Se activó un descuento en la tienda!";
      } else if (appliedPrice < originalPrice && currentPrice == basePrice) {
        message = "El producto ya no está en oferta.";
      }

      acc.prices.add(
        PriceChange(
          itemId: item['id'] as int,
          productName: itemName ?? "Desconocido",
          oldPrice: appliedPrice,
          newPrice: currentPrice,
          newBasePrice: basePrice,
          message: message,
        ),
      );
    }

    // --- Validación de stock Factor-Aware y Acumulada ---
    final int factor = acc.factorPerPres[pId] ?? 1;
    final bool isShared = acc.usaSharedStockPerPres[pId] ?? false;
    final int prodId = acc.productIdPerPres[pId] ?? 0;
    final int? cupo = acc.cupoPerPres[pId];
    final int qty = item['quantity'] as int;

    final int demandedBase;
    final int effectiveAvailableStock;

    if (isShared && prodId > 0) {
      demandedBase = acc.totalDemandPerSharedProduct[prodId] ?? (qty * factor);
      effectiveAvailableStock =
          acc.sharedStockPerProduct[prodId] ?? currentStock;
    } else {
      demandedBase = acc.totalDemandPerPres[pId] ?? (qty * factor);
      effectiveAvailableStock = currentStock;
    }

    final int physicalAvailableUnits = (effectiveAvailableStock / factor)
        .floor();
    final int vendibleAvailableUnits = (cupo != null && isShared)
        ? physicalAvailableUnits.clamp(0, cupo)
        : physicalAvailableUnits;

    if (isShared && prodId > 0) {
      if (acc.conflictProdIds.contains(prodId)) {
        // Ya registrado en sharedStockConflicts a nivel de pozo común.
        // Solo verificamos si individualmente además viola su cupo
        if (cupo != null && qty > cupo) {
          acc.hasIssues = true;
          acc.canSell = false;
          acc.warnings.add(
            StockWarning(
              itemId: item['id'] as int,
              productName: itemName ?? "Desconocido",
              requested: qty,
              available: cupo,
              message:
                  "La variante tiene un cupo asignado de $cupo disp. (requiere $qty).",
            ),
          );
        }
      } else if (cupo != null && qty > cupo) {
        acc.hasIssues = true;
        acc.canSell = false;
        acc.warnings.add(
          StockWarning(
            itemId: item['id'] as int,
            productName: itemName ?? "Desconocido",
            requested: qty,
            available: cupo,
            message:
                "La variante tiene un cupo asignado de $cupo disp. (requiere $qty).",
          ),
        );
      }
    } else if (effectiveAvailableStock < demandedBase) {
      acc.hasIssues = true;
      acc.canSell = false;
      final int requestedUnits = (demandedBase / factor).ceil();
      final String warningMsg = demandedBase > (qty * factor)
          ? "Stock insuficiente por demanda acumulada en la lista (requiere $requestedUnits, disponible $physicalAvailableUnits)."
          : "Stock insuficiente (requiere $requestedUnits, disponible $physicalAvailableUnits).";
      acc.warnings.add(
        StockWarning(
          itemId: item['id'] as int,
          productName: itemName ?? "Desconocido",
          requested: requestedUnits,
          available: vendibleAvailableUnits,
          message: warningMsg,
        ),
      );
    }

    // --- Validación de Unidad de Venta ---
    final String? savedUnit = item['sales_unit'] as String?;
    final String? currentUnit = pres['unidad_venta'] as String?;
    final int currentFactor = (pres['unidades_por_venta'] as int?) ?? 1;
    if (savedUnit != null &&
        currentUnit != null &&
        savedUnit.toLowerCase() != currentUnit.toLowerCase()) {
      acc.hasIssues = true;
      acc.canSell = false;
      acc.unitChanges.add(
        UnitChange(
          itemId: item['id'] as int,
          productName: itemName ?? "Desconocido",
          oldUnit: savedUnit,
          newUnit: currentUnit,
          newFactor: currentFactor,
          message:
              "La unidad de venta cambió de \"$savedUnit\" a \"$currentUnit\". Se debe sincronizar antes de vender.",
        ),
      );
    }
  }

  Future<ValidationResult> _validateIntegrityImpl(int quotationId) async {
    try {
      final db = await dbHelper.database;
      final iRows = await db.query(
        'smart_quotation_items',
        where: 'quotation_id = ?',
        whereArgs: [quotationId],
      );
      final acc = _ValidationAccumulator();

      await _collectDemandAndSharedConflicts(db, iRows, acc);

      for (final item in iRows) {
        if (item['bundle_id'] != null) {
          await _validateBundleQuotationItem(db, item, acc);
          continue;
        }
        if (item['presentation_id'] == null) continue;
        await _validatePresentationQuotationItem(db, item, acc);
      }

      return ValidationResult(
        hasIssues: acc.hasIssues,
        canSell: acc.canSell,
        stockWarnings: acc.warnings,
        priceChanges: acc.prices,
        nameChanges: acc.nameChanges,
        bundleChanges: acc.bundleChanges,
        unitChanges: acc.unitChanges,
        sharedStockConflicts: acc.sharedConflicts,
      );
    } catch (e) {
      throw Exception("Error local al validar integridad: $e");
    }
  }
}
