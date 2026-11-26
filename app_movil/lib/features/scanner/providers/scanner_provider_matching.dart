part of 'scanner_provider.dart';

mixin _ScannerProviderMatchingMixin on _ScannerProviderBase {
  // --- Operaciones de linking manual ---
  void manualLinkProductGroup(
    String groupUuid,
    Map<String, dynamic> product,
    List<Map<String, dynamic>> siblings, {
    int? selectedPresentationId,
  }) {
    var group = _findGroup(groupUuid);
    if (group == null) return;

    group.matchProducto = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: product['id'],
        nombre: product['nombre'],
        stockActual: product['stock_total_unidades'] ?? 0,
        marcaNombre: product['marca_nombre'],
        categoriaNombre: product['categoria_nombre'],
        availablePresentations: siblings,
      ),
    );
    group.nombrePadre = product['nombre'];
    group.marcaTexto = product['marca_nombre'] ?? "Genérica";

    bool isFirstVariant = true;

    for (var v in group.variantes) {
      String invoiceName = v.nombreEspecifico.toLowerCase().trim();

      Map<String, dynamic>? bestMatch;
      double highestScore = -1;

      if (isFirstVariant && selectedPresentationId != null) {
        bestMatch = siblings.firstWhere(
          (s) => s['id'] == selectedPresentationId,
          orElse: () => <String, dynamic>{},
        );
        if (bestMatch.isEmpty) bestMatch = null;
        if (bestMatch != null) highestScore = 100.0; // Alto score para bypass
      } else {
        int factorToMatch = UnitCatalogService.resolveUnit(v.unidadVenta)?.factor ?? 1;

        for (var s in siblings) {
          String sName = (s['nombre_especifico'] ?? "").toLowerCase().trim();
          int sFactor = s['factor_conversion'] as int? ?? 1;

          double score = SpanishLemmatizer.calculateSimilarity(
            invoiceName,
            sName,
          );
          
          // Boost based on factor matching
          if (factorToMatch == sFactor && factorToMatch > 1) {
            score += 2.0; // Perfect match por factor (asegura superar cualquier similitud de texto que maximo es 1.0)
          } else if (factorToMatch == sFactor && factorToMatch == 1) {
            score += 0.5; // Ligero boost para unidades sueltas
          }

          if (score > highestScore) {
            highestScore = score;
            bestMatch = s;
          }
        }
      }

      if (bestMatch != null && highestScore > 0.5) {
        v.matchPresentacion = MatchResult(
          estado: "MATCH_MANUAL",
          confianza: 100,
          datos: MatchData(
            id: bestMatch['id'],
            nombre: bestMatch['nombre_especifico'] ?? "General",
            stockActual: bestMatch['stock_actual'] ?? 0,
            precioVentaFinal: (bestMatch['precio_venta'] ?? 0).toDouble(),
            costoUnitarioCalculado: (bestMatch['precio_costo'] ?? 0).toDouble(),
            unidadesPorLote: 1,
            unidadesPorVenta: bestMatch['factor_conversion'] ?? 1,
            umpCompra: bestMatch['unidad'] ?? 'Unidad',
            unidadVenta: bestMatch['unidad'] ?? 'Unidad',
            availablePresentations: siblings,
          ),
        );
      } else {
        v.matchPresentacion = MatchResult(
          estado: "NUEVO_EN_PADRE",
          confianza: 0,
          datos: MatchData(
            id: -1,
            nombre: "Nueva Variante",
            availablePresentations: siblings,
          ),
        );
      }
      isFirstVariant = false;
    }
    notifyListeners();
  }

  String _cleanAndCapitalizeName(
    String original,
    String brand,
    List<StagingVariant> variants,
  ) {
    String cleaned = original.toLowerCase();

    if (brand.isNotEmpty && brand.toLowerCase() != "genérica") {
      cleaned = cleaned.replaceAll(brand.toLowerCase(), "");
    }

    for (var v in variants) {
      String vName = v.nombreEspecifico.toLowerCase();
      if (vName.isNotEmpty && vName != "general") {
        cleaned = cleaned.replaceAll(vName, "");
      }
    }

    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) return original; // fallback
    List<String> words = cleaned.split(" ");
    return words
        .map((w) {
          if (w.isEmpty) return "";
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(" ");
  }

  void unlinkProductGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    if (group.nombreOriginalFactura != null) {
      group.marcaTexto = group.marcaOriginalFactura ?? "";
      group.nombrePadre = _cleanAndCapitalizeName(
        group.nombreOriginalFactura!,
        group.marcaTexto,
        group.variantes,
      );
    }
    group.matchProducto = MatchResult(
      estado: "NUEVO",
      confianza: 0,
      datos: null,
    );
    group.matchMarca = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
    group.categoriaSugeridaId = null;
    for (var v in group.variantes) {
      v.matchPresentacion = MatchResult(
        estado: "NUEVO",
        confianza: 0,
        datos: null,
      );
    }
    notifyListeners();
  }

  void switchVariantLink(String variantUuid, int newPresentationId) {
    StagingVariant? variant;
    StagingProductGroup? parentGroup;

    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      int idx = group.variantes.indexWhere(
        (v) => v.uuidTemporal == variantUuid,
      );
      if (idx != -1) {
        variant = group.variantes[idx];
        parentGroup = group;
        break;
      }
    }

    if (variant == null || parentGroup == null) return;

    var availablePresentations =
        parentGroup.matchProducto.datos?.availablePresentations;
    if (availablePresentations == null || availablePresentations.isEmpty) {
      return;
    }

    var selectedSibling = availablePresentations.firstWhere(
      (p) => p['id'] == newPresentationId,
      orElse: () => <String, dynamic>{},
    );
    if (selectedSibling.isEmpty) return;

    variant.matchPresentacion = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: selectedSibling['id'],
        nombre: selectedSibling['nombre_especifico'] ?? "General",
        stockActual: selectedSibling['stock_actual'] ?? 0,
        precioVentaFinal: (selectedSibling['precio_venta'] ?? 0).toDouble(),
        costoUnitarioCalculado: (selectedSibling['precio_costo'] ?? 0)
            .toDouble(),
        unidadesPorVenta: selectedSibling['factor_conversion'] ?? 1,
        unidadVenta: selectedSibling['unidad'] ?? 'Unidad',
        umpCompra:
            selectedSibling['ump_compra'] ??
            selectedSibling['unidad'] ??
            'Unidad',
        availablePresentations: availablePresentations,
      ),
    );
    notifyListeners();
  }

  void switchVariantToNew(String variantUuid) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;
    var siblingsBackup =
        variant.matchPresentacion.datos?.availablePresentations;
    variant.matchPresentacion = MatchResult(
      estado: "NUEVO_EN_PADRE",
      confianza: 0,
      datos: MatchData(
        id: -1,
        nombre: "Nueva Variante",
        availablePresentations: siblingsBackup,
      ),
    );
    variant.factorGananciaVentaSugerido = 1.35;
    variant.precioVentaSugerido =
        variant.costoUnitarioSugerido * variant.factorGananciaVentaSugerido;
    notifyListeners();
  }

  void adoptDbUnitForVariant(String variantUuid) {
    if (_currentState.stagingData == null) return;
    var variant = _findVariant(variantUuid);
    if (variant == null) return;

    var dbData = variant.matchPresentacion.datos;
    if (dbData == null) return;

    variant.unidadVenta = dbData.unidadVenta;
    variant.unidadesPorVenta = dbData.unidadesPorVenta;

    int totalUnidadesBase = variant.stockIngresanteOverride ?? (variant.cantidadUmpComprada * variant.unidadesPorLote).toInt();
    double costoBaseIndiv = 0.0;
    if (totalUnidadesBase > 0) {
      costoBaseIndiv = variant.totalPagoLote / totalUnidadesBase;
    }

    variant.costoUnitarioSugerido = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoBaseIndiv,
      unidadesPorVenta: variant.unidadesPorVenta,
    );

    variant.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
      presentationCost: variant.costoUnitarioSugerido,
      marginFactor: variant.factorGananciaVentaSugerido,
    );
    notifyListeners();
  }
}
