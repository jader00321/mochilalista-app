part of 'scanner_provider.dart';

mixin _ScannerProviderStagingMixin on _ScannerProviderBase {
  // ==========================================
  // MANIPULACIÓN DE STAGING (UI)
  // ==========================================

  void updateStagingProvider({
    required String nombre,
    int? idExistente,
    String? ruc,
    String? fecha,
  }) {
    if (_currentState.stagingData == null) return;
    _currentState.stagingData!.proveedorTexto = nombre;
    if (ruc != null) _currentState.stagingData!.rucProveedor = ruc;
    if (fecha != null) _currentState.stagingData!.fechaFactura = fecha;

    if (idExistente != null) {
      _currentState.stagingData!.proveedorMatch = MatchResult(
        estado: "MATCH_MANUAL",
        confianza: 100,
        datos: MatchData(id: idExistente, nombre: nombre),
      );
    } else {
      _currentState.stagingData!.proveedorMatch = MatchResult(
        estado: "NUEVO",
        confianza: 0,
        datos: null,
      );
    }
    notifyListeners();
  }

  void addNewProductGroup() {
    if (_currentState.stagingData == null) return;
    final newGroup = StagingProductGroup(
      nombrePadre: "",
      marcaOriginalFactura: "",
      marcaTexto: "",
      matchProducto: MatchResult(estado: "NUEVO", confianza: 0),
      matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
      variantes: [
        StagingVariant(
          nombreEspecifico: "Variante A",
          umpCompra: "UND",
          cantidadUmpComprada: 1.0,
          precioUmpProveedor: 0.0,
          totalPagoLote: 0.0,
          unidadesPorLote: 1,
          unidadVenta: "Unidad",
          unidadesPorVenta: 1,
          costoUnitarioSugerido: 0.0,
          factorGananciaVentaSugerido: 1.35,
          precioVentaSugerido: 0.0,
          matchPresentacion: MatchResult(estado: "NUEVO", confianza: 0),
        ),
      ],
    );
    _currentState.stagingData!.productosAgrupados.add(newGroup);
    notifyListeners();
  }

  /// Genera un nombre determinista único para evitar colisiones en presentaciones del mismo grupo
  /// conservando siempre el nombre específico extraído de la factura como raíz.
  @override
  String generateUniqueVariantName(StagingProductGroup group, {required bool isShared}) {
    String baseName = "";
    if (group.nombreOriginalFactura != null && group.nombreOriginalFactura!.trim().isNotEmpty) {
      baseName = group.nombreOriginalFactura!.trim();
    } else if (group.variantes.isNotEmpty && group.variantes.first.nombreEspecifico.trim().isNotEmpty) {
      baseName = group.variantes.first.nombreEspecifico.trim();
    } else if (group.nombrePadre.trim().isNotEmpty) {
      baseName = group.nombrePadre.trim();
    } else {
      baseName = "Presentación";
    }

    // Limpiar sufijos generados previamente para evitar acumulación
    baseName = baseName.replaceAll(RegExp(r'\s*\((?:[0-9]+)\)$'), '').trim();
    baseName = baseName.replaceAll(RegExp(r'\s*-\s*(?:Comp\.|Propio)(?:\s+[0-9]+)?$'), '').trim();
    if (baseName.isEmpty) baseName = "Presentación";

    final existingNames = group.variantes.map((v) => v.nombreEspecifico.trim().toLowerCase()).toSet();

    // 1. Si no hay variantes aún en el grupo, conserva exactamente el nombre extraído
    if (group.variantes.isEmpty) {
      return baseName;
    }

    // Determinar si hay convivencia de modos (Mixto o conviven variantes con distinto modo)
    final bool hasMixedModes = group.modoStock == 'MIXTO' ||
        group.variantes.any((v) => v.usaStockCompartido != isShared);

    String candidate;
    if (hasMixedModes) {
      final String tag = isShared ? "Comp." : "Propio";
      final String baseTag = "$baseName - $tag";
      if (!existingNames.contains(baseTag.toLowerCase())) {
        candidate = baseTag;
      } else {
        int counter = 2;
        candidate = "$baseName - $tag $counter";
        while (existingNames.contains(candidate.toLowerCase())) {
          counter++;
          candidate = "$baseName - $tag $counter";
        }
      }
    } else {
      // Modo puramente Independiente o Compartido: sufijo secuencial (2), (3)...
      int counter = 2;
      candidate = "$baseName ($counter)";
      while (existingNames.contains(candidate.toLowerCase())) {
        counter++;
        candidate = "$baseName ($counter)";
      }
    }

    // Verificación final estricta anti-colisión
    int safetyCounter = 2;
    String finalCandidate = candidate;
    while (existingNames.contains(finalCandidate.toLowerCase())) {
      finalCandidate = "$candidate ($safetyCounter)";
      safetyCounter++;
    }

    return finalCandidate;
  }

  void removeVariantByUuid(String variantUuid) {
    if (_currentState.stagingData == null) return;
    for (int g = 0; g < _currentState.stagingData!.productosAgrupados.length; g++) {
      var group = _currentState.stagingData!.productosAgrupados[g];
      int vIndex = group.variantes.indexWhere(
        (v) => v.uuidTemporal == variantUuid,
      );
      if (vIndex != -1) {
        final variantToRemove = group.variantes[vIndex];
        if (variantToRemove.sourceVariantUuid != null) {
          revertLeftoverToMother(variantUuid);
        }
        group.variantes.removeAt(vIndex);
        if (group.variantes.isEmpty) {
          _currentState.stagingData!.productosAgrupados.removeAt(g);
        }
        notifyListeners();
        return;
      }
    }
  }

  void toggleVariantUpdate(String variantUuid, String field) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;
    if (field == 'costo') variant.updateCosto = !variant.updateCosto;
    if (field == 'precio') variant.updatePrecio = !variant.updatePrecio;
    if (field == 'nombre') variant.updateNombre = !variant.updateNombre;
    notifyListeners();
  }

  void addNewVariantToGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    List<Map<String, dynamic>>? siblings;
    if (group.matchProducto.estado.contains("MATCH") &&
        group.variantes.isNotEmpty) {
      siblings =
          group.variantes.first.matchPresentacion.datos?.availablePresentations;
    }

    final bool isShared = group.modoStock == 'COMPARTIDO';
    final String uniqueName = generateUniqueVariantName(group, isShared: isShared);

    // Herencia estricta de datos de factura extraídos de la variante principal (NUNCA CEROS)
    final master = group.variantes.isNotEmpty ? group.variantes.first : null;

    final String umpCompra = master?.umpCompra ?? "UND";
    final double cantidadUmp = master?.cantidadUmpComprada ?? 1.0;
    final double precioUmp = master?.precioUmpProveedor ?? 0.0;
    final double totalPago = master?.totalPagoLote ?? 0.0;
    final int unidadesLote = master?.unidadesPorLote ?? 1;

    final String unidadVenta = master?.unidadVenta ?? "Unidad";
    final int unidadesVenta = master?.unidadesPorVenta ?? 1;
    final double costoSugerido = isShared 
        ? (group.costoBase * unidadesVenta)
        : (master?.costoUnitarioSugerido ?? 0.0);
    final double margen = master?.factorGananciaVentaSugerido ?? 1.35;
    final double precioSugerido = ScannerCostEngine.suggestSalePrice(
      presentationCost: costoSugerido,
      marginFactor: margen,
    );

    final newVariant = StagingVariant(
      nombreEspecifico: uniqueName,
      umpCompra: umpCompra,
      cantidadUmpComprada: cantidadUmp,
      precioUmpProveedor: precioUmp,
      totalPagoLote: totalPago,
      unidadesPorLote: unidadesLote,
      unidadVenta: unidadVenta,
      unidadesPorVenta: unidadesVenta,
      costoUnitarioSugerido: costoSugerido,
      factorGananciaVentaSugerido: margen,
      precioVentaSugerido: precioSugerido,
      matchPresentacion: MatchResult(
        estado: group.matchProducto.estado.contains("MATCH")
            ? "NUEVO_EN_PADRE"
            : "NUEVO",
        confianza: 0,
        datos: siblings != null
            ? MatchData(id: -1, nombre: uniqueName, availablePresentations: siblings)
            : null,
      ),
    )..usaStockCompartido = isShared;

    group.variantes.add(newVariant);
    notifyListeners();
  }
}
