part of 'scanner_provider.dart';

mixin _ScannerProviderLeftoverAndStockMixin on _ScannerProviderBase {
  String? createLeftoverVariant(String sourceVariantUuid, int leftoverAmount) {
    if (_currentState.stagingData == null) return null;
    StagingVariant? sourceVariant;
    StagingProductGroup? parentGroup;

    for (var group in _currentState.stagingData!.productosAgrupados) {
      int idx = group.variantes.indexWhere((v) => v.uuidTemporal == sourceVariantUuid);
      if (idx != -1) {
        sourceVariant = group.variantes[idx];
        parentGroup = group;
        break;
      }
    }

    if (sourceVariant == null || parentGroup == null) return null;

    int factor = sourceVariant.effectiveFactorVenta;
    final int stockBD = sourceVariant.matchPresentacion.datos?.stockActual ?? 0;
    final int totalBaseActual = sourceVariant.calculateTotalUnitsBase(stockActualBD: stockBD);
    final int totalSinSobrante = max(0, totalBaseActual - leftoverAmount);

    final bool isExisting = sourceVariant.matchPresentacion.estado.contains("MATCH");
    final int prevOverride = sourceVariant.stockIngresanteOverride ??
        (sourceVariant.cantidadUmpComprada * sourceVariant.unidadesPorLote).toInt();

    // Blindaje Matemático: Si en producto vinculado sumar el sobrante excede el ingreso de la factura,
    // el ajuste de ingreso efectivo en la madre debe ser (totalSinSobrante - stockBD) para que el
    // nuevo total quede exactamente en (completas * factor) con 0 errores de stock.
    int nuevoIngresoPrincipal;
    if (isExisting && sourceVariant.stockOperation == 'sumar') {
      nuevoIngresoPrincipal = totalSinSobrante - stockBD;
    } else {
      nuevoIngresoPrincipal = totalSinSobrante;
    }

    sourceVariant.stockIngresanteOverride = nuevoIngresoPrincipal;
    sourceVariant.allowLeftoverInReserve = false;
    sourceVariant.allowDeficitApproved = false;

    // Calcular costo unitario base del lote actual
    double costoBase = 0.0;
    if (prevOverride > 0) {
      costoBase = sourceVariant.totalPagoLote / prevOverride;
    } else if (sourceVariant.costoUnitarioSugerido > 0) {
      costoBase = sourceVariant.costoUnitarioSugerido / max(1, factor);
    }

    double totalPagoSobrante = leftoverAmount * costoBase;
    if (totalPagoSobrante > sourceVariant.totalPagoLote) {
      totalPagoSobrante = sourceVariant.totalPagoLote;
    }

    // Descontar proporcionalmente el pago del lote de la madre para mantener la ecuación total
    sourceVariant.totalPagoLote = max(0.0, sourceVariant.totalPagoLote - totalPagoSobrante);
    if (sourceVariant.unidadesPorLote > 0 && nuevoIngresoPrincipal >= 0) {
      sourceVariant.cantidadUmpComprada = nuevoIngresoPrincipal / sourceVariant.unidadesPorLote;
    }
    if (nuevoIngresoPrincipal > 0) {
      double newMotherUnitCost = sourceVariant.totalPagoLote / nuevoIngresoPrincipal;
      sourceVariant.costoUnitarioSugerido = newMotherUnitCost * factor;
      sourceVariant.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
        presentationCost: sourceVariant.costoUnitarioSugerido,
        marginFactor: sourceVariant.factorGananciaVentaSugerido,
      );
    }

    double margen = sourceVariant.factorGananciaVentaSugerido > 0
        ? sourceVariant.factorGananciaVentaSugerido
        : 1.35;
    double pVentaSugerido = ScannerCostEngine.suggestSalePrice(
      presentationCost: costoBase,
      marginFactor: margen,
    );

    // Verificar si en el parentGroup ya existe una variante con factor 1 (Unidad)
    StagingVariant? existingUnitVariant = parentGroup.variantes
        .where((v) => v != sourceVariant && v.effectiveFactorVenta == 1)
        .firstOrNull;

    String resultingUuid;

    if (existingUnitVariant != null) {
      // Sumar al ingreso de la variante unitaria existente
      int prevUnitOverride = existingUnitVariant.stockIngresanteOverride ??
          (existingUnitVariant.cantidadUmpComprada * existingUnitVariant.unidadesPorLote).toInt();
      existingUnitVariant.stockIngresanteOverride = prevUnitOverride + leftoverAmount;
      existingUnitVariant.allocatedBaseUnits = (existingUnitVariant.allocatedBaseUnits ?? 0) + leftoverAmount;
      existingUnitVariant.allocatedPurchaseCost = (existingUnitVariant.allocatedPurchaseCost ?? 0.0) + totalPagoSobrante;
      existingUnitVariant.originalMotherIngresoOverride = prevOverride;
      existingUnitVariant.cantidadUmpComprada = existingUnitVariant.cantidadUmpComprada + leftoverAmount.toDouble();
      existingUnitVariant.totalPagoLote = existingUnitVariant.totalPagoLote + totalPagoSobrante;
      existingUnitVariant.precioUmpProveedor = costoBase;
      existingUnitVariant.costoUnitarioSugerido = costoBase;
      existingUnitVariant.factorGananciaVentaSugerido = margen;
      existingUnitVariant.precioVentaSugerido = pVentaSugerido;
      existingUnitVariant.sourceVariantUuid = sourceVariantUuid;
      existingUnitVariant.updateUnidadVenta = true;
      resultingUuid = existingUnitVariant.uuidTemporal;
    } else {
      // Crear nueva variante 'Unidad (x1)' con nombre determinista garantizado sin colisión
      String nombreHeredado = sourceVariant.nombreEspecifico.trim();
      String baseName = (nombreHeredado.isNotEmpty && nombreHeredado != "General")
          ? "$nombreHeredado - Unidad"
          : "Unidad (x1)";
      final existingNames = parentGroup.variantes.map((v) => v.nombreEspecifico.trim().toLowerCase()).toSet();
      String newName = baseName;
      int counter = 2;
      while (existingNames.contains(newName.toLowerCase())) {
        newName = "$baseName #$counter";
        counter++;
      }

      StagingVariant leftoverVariant = StagingVariant(
        nombreEspecifico: newName,
        umpCompra: "Unidad",
        cantidadUmpComprada: leftoverAmount.toDouble(),
        precioUmpProveedor: costoBase,
        totalPagoLote: totalPagoSobrante,
        unidadesPorLote: 1,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        costoUnitarioSugerido: costoBase,
        factorGananciaVentaSugerido: margen,
        precioVentaSugerido: pVentaSugerido,
        matchPresentacion: MatchResult(
          estado: "NUEVO_EN_PADRE",
          confianza: 0,
          datos: MatchData(
            id: -1,
            nombre: newName,
            availablePresentations: sourceVariant.matchPresentacion.datos?.availablePresentations,
            unidadVenta: "Unidad",
            unidadesPorVenta: 1,
          ),
        ),
      );
      leftoverVariant.stockIngresanteOverride = leftoverAmount;
      leftoverVariant.sourceVariantUuid = sourceVariantUuid;
      leftoverVariant.allocatedBaseUnits = leftoverAmount;
      leftoverVariant.allocatedPurchaseCost = totalPagoSobrante;
      leftoverVariant.originalMotherIngresoOverride = prevOverride;
      leftoverVariant.updateUnidadVenta = true;
      leftoverVariant.updateCosto = true;
      leftoverVariant.updatePrecio = true;

      int parentIndex = parentGroup.variantes.indexOf(sourceVariant);
      parentGroup.variantes.insert(parentIndex + 1, leftoverVariant);
      resultingUuid = leftoverVariant.uuidTemporal;
    }

    notifyListeners();
    return resultingUuid;
  }

  /// Revierte los fondos y unidades transferidas desde una variante hija hacia su variante madre
  @override
  bool revertLeftoverToMother(String childVariantUuid) {
    if (_currentState.stagingData == null) return false;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      int cIdx = group.variantes.indexWhere((v) => v.uuidTemporal == childVariantUuid);
      if (cIdx != -1) {
        final child = group.variantes[cIdx];
        if (child.sourceVariantUuid != null) {
          final mother = group.variantes
              .where((v) => v.uuidTemporal == child.sourceVariantUuid)
              .firstOrNull;
          if (mother != null) {
            final int unitsToRestore = child.allocatedBaseUnits ?? child.stockIngresanteBase;
            final double costToRestore = child.allocatedPurchaseCost ?? child.totalPagoLote;

            if (child.originalMotherIngresoOverride != null) {
              mother.stockIngresanteOverride = child.originalMotherIngresoOverride;
            } else {
              final int motherIngresoActual = mother.stockIngresanteOverride ?? mother.stockIngresanteBase;
              mother.stockIngresanteOverride = motherIngresoActual + unitsToRestore;
            }

            mother.totalPagoLote = mother.totalPagoLote + costToRestore;
            final int newIngreso = mother.stockIngresanteOverride ?? mother.stockIngresanteBase;
            if (mother.unidadesPorLote > 0 && newIngreso >= 0) {
              mother.cantidadUmpComprada = newIngreso / mother.unidadesPorLote;
            }
            if (newIngreso > 0) {
              double unitCost = mother.totalPagoLote / newIngreso;
              mother.costoUnitarioSugerido = unitCost * mother.effectiveFactorVenta;
              mother.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
                presentationCost: mother.costoUnitarioSugerido,
                marginFactor: mother.factorGananciaVentaSugerido,
              );
            }
            // Reset flags so leftover alert re-evaluates immediately!
            mother.allowLeftoverInReserve = false;
            mother.allowDeficitApproved = false;

            return true;
          }
        }
      }
    }
    return false;
  }

  /// Sincroniza el Stock Base Compartido y Costo Base Unitario del grupo
  /// a partir de los datos de compra de la variante maestra/compartida (a 0ms).
  @override
  void syncGroupSharedPurchaseFromMasterVariant(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null || group.variantes.isEmpty) return;

    final master = group.variantes.where((v) => v.usaStockCompartido).firstOrNull ?? group.variantes.first;
    int masterBase = master.stockIngresanteOverride ?? (master.cantidadUmpComprada * master.unidadesPorLote).toInt();
    double masterTotal = master.totalPagoLote;
    if (masterTotal == 0.0 && master.precioUmpProveedor > 0 && master.cantidadUmpComprada > 0) {
      masterTotal = master.cantidadUmpComprada * master.precioUmpProveedor;
    }

    int totalPool = masterBase;
    if (group.matchProducto.estado.contains("MATCH")) {
      totalPool += group.matchProducto.datos?.stockActual ?? 0;
    }
    group.stockCompartido = totalPool;
    group.costoBase = masterBase > 0 ? (masterTotal / masterBase) : 0.0;

    // Recalcular costos y cupos de las variantes que comparten este stock
    for (var v in group.variantes) {
      if (group.modoStock == 'COMPARTIDO' || v.usaStockCompartido) {
        v.costoUnitarioSugerido = group.costoBase * v.effectiveFactorVenta;
        v.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
          presentationCost: v.costoUnitarioSugerido,
          marginFactor: v.factorGananciaVentaSugerido,
        );
        int maxFormable = v.effectiveFactorVenta > 0 ? (group.stockCompartido ~/ v.effectiveFactorVenta) : 0;
        if (v.cupoMaximoVariante != null && v.cupoMaximoVariante! > maxFormable) {
          v.cupoMaximoVariante = maxFormable;
        }
      }
    }
    notifyListeners();
  }

  /// Añade una presentación 'Unidad (x1)' al pool compartido desde el Asesor de Stock
  void addUnitVariantToSharedGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    if (group.variantes.any((v) => v.effectiveFactorVenta == 1)) return;

    double baseCost = group.costoBase;
    double margen = group.variantes.isNotEmpty ? group.variantes.first.factorGananciaVentaSugerido : 1.35;
    double pVenta = ScannerCostEngine.suggestSalePrice(presentationCost: baseCost, marginFactor: margen);

    final available = group.matchProducto.datos?.availablePresentations ?? [];
    var dbUnit = available
        .where((p) => (p['factor_conversion'] == 1 || p['factor_conversion'] == null))
        .firstOrNull;

    StagingVariant unitVariant = StagingVariant(
      nombreEspecifico: dbUnit != null ? (dbUnit['nombre_especifico'] ?? 'Unidad (x1)') : 'Unidad (x1)',
      umpCompra: 'UND',
      cantidadUmpComprada: 0,
      precioUmpProveedor: baseCost,
      totalPagoLote: 0.0,
      unidadesPorLote: 1,
      unidadVenta: dbUnit != null ? (dbUnit['unidad'] ?? 'Unidad') : 'Unidad',
      unidadesPorVenta: 1,
      costoUnitarioSugerido: baseCost,
      factorGananciaVentaSugerido: margen,
      precioVentaSugerido: dbUnit != null && dbUnit['precio_venta'] != null
          ? (dbUnit['precio_venta'] as num).toDouble()
          : pVenta,
      matchPresentacion: dbUnit != null
          ? MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: 95,
              datos: MatchData(
                id: dbUnit['id'] as int,
                nombre: dbUnit['nombre_especifico'] as String? ?? 'Unidad (x1)',
                stockActual: dbUnit['stock_actual'] as int? ?? group.stockCompartido,
                precioVentaFinal: (dbUnit['precio_venta'] as num?)?.toDouble() ?? pVenta,
                costoUnitarioCalculado: (dbUnit['precio_costo'] as num?)?.toDouble() ?? baseCost,
                unidadVenta: dbUnit['unidad'] as String? ?? 'Unidad',
                unidadesPorVenta: 1,
                availablePresentations: available,
                usaStockCompartido: true,
              ),
            )
          : MatchResult(
              estado: group.matchProducto.estado.contains("MATCH") ? "NUEVO_EN_PADRE" : "NUEVO",
              confianza: 0,
              datos: MatchData(id: -1, nombre: 'Unidad (x1)', availablePresentations: available, usaStockCompartido: true),
            ),
    )..usaStockCompartido = true;

    group.variantes.add(unitVariant);
    notifyListeners();
  }

  /// Activa la estrategia de Stock Compartido (Pool único) para el grupo
  void activateSharedStockForGroup(String groupUuid, [String? variantUuid]) {
    setGroupStockStrategy(groupUuid, 'COMPARTIDO');
    addUnitVariantToSharedGroup(groupUuid);
  }

  /// Cambia la estrategia de stock del grupo ('COMPARTIDO', 'INDEPENDIENTE', 'MIXTO')
  void setGroupStockStrategy(String groupUuid, String modoStock) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    group.modoStock = modoStock;

    if (modoStock == 'COMPARTIDO') {
      for (var v in group.variantes) {
        v.usaStockCompartido = true;
      }
      syncGroupSharedPurchaseFromMasterVariant(groupUuid);
    } else if (modoStock == 'INDEPENDIENTE') {
      for (var v in group.variantes) {
        v.usaStockCompartido = false;
        v.cupoMaximoVariante = null;
      }
    } else if (modoStock == 'MIXTO') {
      if (group.variantes.isNotEmpty) {
        group.variantes.first.usaStockCompartido = true;
      }
      syncGroupSharedPurchaseFromMasterVariant(groupUuid);
    }
    notifyListeners();
  }

  /// Alterna el flag usaStockCompartido para una variante individual (Modo Mixto)
  void toggleVariantSharedStock(String variantUuid) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;
    variant.usaStockCompartido = !variant.usaStockCompartido;
    if (_currentState.stagingData != null) {
      for (var group in _currentState.stagingData!.productosAgrupados) {
        if (group.variantes.any((v) => v.uuidTemporal == variantUuid)) {
          syncGroupSharedPurchaseFromMasterVariant(group.uuidTemporal);
          break;
        }
      }
    }
    notifyListeners();
  }

  /// Adapta la unidad de venta y factor de una variante en 1 toque
  void adaptVariantUnit(String variantUuid, [String unitName = "Unidad", int factor = 1]) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          v.unidadVenta = unitName;
          v.unidadesPorVenta = factor;
          v.updateUnidadVenta = true;
          double costoBase = (v.cantidadUmpComprada > 0 && v.unidadesPorLote > 0)
              ? v.totalPagoLote / (v.cantidadUmpComprada * v.unidadesPorLote)
              : v.costoUnitarioSugerido / v.effectiveFactorVenta;
          v.costoUnitarioSugerido = costoBase * factor;
          v.precioVentaSugerido = v.costoUnitarioSugerido * v.factorGananciaVentaSugerido;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Completa el ingreso de factura para alcanzar al menos 1 presentación
  void completeBatchToFullPackage(String variantUuid, [int? unitsNeeded]) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          int stockBD = v.matchPresentacion.datos?.stockActual ?? 0;
          int factor = v.effectiveFactorVenta;
          int totalBase = v.calculateTotalUnitsBase(stockActualBD: stockBD);
          int needed = unitsNeeded ?? (factor > totalBase ? factor - totalBase : 0);
          if (needed > 0) {
            int currentIngreso = v.stockIngresanteBase;
            v.stockIngresanteOverride = currentIngreso + needed;
            notifyListeners();
          }
          return;
        }
      }
    }
  }

  void removeLeftoverVariantForSource(String sourceVariantUuid) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      if (group.variantes.any((v) => v.uuidTemporal == sourceVariantUuid)) {
        var leftovers = group.variantes.where((v) => v.sourceVariantUuid == sourceVariantUuid).toList();
        for (var child in leftovers) {
          revertLeftoverToMother(child.uuidTemporal);
        }
        group.variantes.removeWhere((v) => v.sourceVariantUuid == sourceVariantUuid);
        notifyListeners();
        break;
      }
    }
  }
}
