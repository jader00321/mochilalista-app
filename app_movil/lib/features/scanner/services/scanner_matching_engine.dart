import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/features/scanner/services/commercial_invoice_normalizer.dart';

/// Servicio dedicado a la lógica de matching (coincidencia) entre
/// los items extraídos por la IA y los productos existentes en SQLite.
class ScannerMatchingEngine {
  final _dbHelper = LocalDatabase.instance;

  Future<StagingResponse?> runMatching({
    required AIInvoiceResponse aiData,
    required int negocioId,
  }) async {
    try {
      final db = await _dbHelper.database;

      // --- Match de proveedor ---
      final provQuery = await db.query(
        'proveedores',
        where: 'negocio_id = ? AND nombre_empresa LIKE ?',
        whereArgs: [negocioId, '%${aiData.proveedorDetectado}%'],
        limit: 1,
      );
      MatchResult provMatch = provQuery.isNotEmpty
          ? MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: 80,
              datos: MatchData(
                id: provQuery.first['id'] as int,
                nombre: provQuery.first['nombre_empresa'] as String,
              ),
            )
          : MatchResult(estado: "NUEVO", confianza: 0);

      // --- Match de productos ---
      List<StagingProductGroup> grupos = [];

      for (var item in aiData.items) {
        // MATCH DE MARCA
        MatchResult marcaMatch = MatchResult(estado: "NUEVO", confianza: 0);
        if (item.marcaDetectada != null && item.marcaDetectada!.isNotEmpty) {
          final marcaQuery = await db.query(
            'marcas',
            where: 'negocio_id = ? AND nombre LIKE ?',
            whereArgs: [negocioId, '%${item.marcaDetectada}%'],
            limit: 1,
          );
          if (marcaQuery.isNotEmpty) {
            marcaMatch = MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: 90,
              datos: MatchData(
                id: marcaQuery.first['id'] as int,
                nombre: marcaQuery.first['nombre'] as String,
              ),
            );
          }
        }

        // MATCH DE PRODUCTO PADRE (Tokenizado)
        final searchName = item.productoPadreEstimado ?? item.descripcion;
        final originalTokens = searchName
            .split(' ')
            .where((t) => t.length > 2)
            .toList();

        List<Map<String, dynamic>> prodQuery = [];
        if (originalTokens.isNotEmpty) {
          String whereClause = 'p.negocio_id = ?';
          List<dynamic> whereArgs = [negocioId];

          for (var i = 0; i < originalTokens.length; i++) {
            String originalToken = originalTokens[i];
            String lemmatizedToken = SpanishLemmatizer.lemmatize(originalToken);
            if (i == 0) {
              whereClause += ' AND (p.nombre LIKE ? OR p.nombre LIKE ?';
            } else {
              whereClause += ' OR p.nombre LIKE ? OR p.nombre LIKE ?';
            }
            whereArgs.add('%$originalToken%');
            whereArgs.add('%$lemmatizedToken%');
          }
          if (originalTokens.isNotEmpty) {
            whereClause += ')';
          }

          prodQuery = await db.rawQuery('''
            SELECT p.id, p.nombre, p.marca_id, p.categoria_id, p.modo_stock, p.stock_compartido, p.costo_base,
                   m.nombre as marca_nombre, c.nombre as categoria_nombre,
                   IFNULL(SUM(pp.stock_actual), 0) as stock_total
            FROM productos p
            LEFT JOIN marcas m ON p.marca_id = m.id
            LEFT JOIN categorias c ON p.categoria_id = c.id
            LEFT JOIN presentaciones_producto pp ON pp.producto_id = p.id AND pp.activo = 1
            WHERE $whereClause
            GROUP BY p.id
            LIMIT 10
          ''', whereArgs);
        }

        MatchResult prodMatch;
        MatchResult presMatch;

        if (prodQuery.isNotEmpty) {
          // --- Scoring System ---
          Map<String, dynamic>? bestCandidate;
          int highestScore = -1;
          List<Map<String, dynamic>> bestSiblings = [];
          Map<String, dynamic>? bestSiblingOfBestCandidate;
          int bestSiblingScore = -1;

          for (var candidate in prodQuery) {
            int score = 0;

            // 1. Nombre Principal (50% max) -> _calculateSimilarity returns 0-100.
            int nameSim = _calculateSimilarity(
              searchName,
              candidate['nombre'] as String,
            );
            score += (nameSim * 0.50).toInt();

            // 2. Marca (15%)
            if (item.marcaDetectada != null &&
                item.marcaDetectada!.isNotEmpty &&
                candidate['marca_nombre'] != null) {
              String marcaA = item.marcaDetectada!.toLowerCase();
              String marcaB = (candidate['marca_nombre'] as String)
                  .toLowerCase();
              if (marcaA == marcaB) {
                score += 15;
              } else if (marcaB.contains(marcaA) || marcaA.contains(marcaB)) {
                score += 10;
              }
            }

            // Consultar siblings para Variante y Unidad
            final presQuery = await db.query(
              'presentaciones_producto',
              where: 'producto_id = ?',
              whereArgs: [candidate['id']],
            );

            List<Map<String, dynamic>> normalizedSiblings = presQuery.map((p) {
              return {
                "id": p['id'],
                "nombre_presentacion": p['unidad_venta'] ?? "Unidad",
                "nombre_especifico": p['nombre_especifico'],
                "nombre_completo":
                    "${p['unidad_venta'] ?? 'Unidad'} ${p['nombre_especifico'] ?? ''}"
                        .trim(),
                "stock_actual": p['stock_actual'],
                "precio_venta": p['precio_venta_final'],
                "precio_costo": p['costo_unitario_calculado'],
                "factor_conversion": p['unidades_por_venta'],
                "unidad": p['unidad_venta'] ?? "Unidad",
                "factor_ganancia_venta": p['factor_ganancia_venta'],
                "precio_oferta": p['precio_oferta'],
                "tipo_descuento": p['tipo_descuento'],
                "valor_descuento": p['valor_descuento'],
                "ump_compra": p['ump_compra'],
                "precio_ump_proveedor": p['precio_ump_proveedor'],
                "cantidad_ump_comprada": p['cantidad_ump_comprada'],
                "total_pago_lote": p['total_pago_lote'],
                "unidades_por_lote": p['unidades_por_lote'],
                "usa_stock_compartido": p['usa_stock_compartido'] == 1 || p['usa_stock_compartido'] == true,
                "cupo_maximo_variante": p['cupo_maximo_variante'],
              };
            }).toList();

            // 3. Variante/Detalle (25%) & Unidad (15%)
            String variantToMatch = item.varianteDetectada ?? item.descripcion;
            String unitToMatch = item.umpCompra.isNotEmpty
                ? item.umpCompra
                : item.unidadVenta;
            
            int factorToMatch = UnitCatalogService.resolveUnit(unitToMatch)?.factor ?? 1;

            Map<String, dynamic>? currentBestSibling;
            int currentBestSiblingScore = -1;

            int maxVariantScore = 0;
            int maxUnitScore = 0;

            for (var sibling in normalizedSiblings) {
              String sName = sibling['nombre_especifico'] as String? ?? "";
              String sUnit = sibling['unidad'] as String? ?? "";
              int sFactor = sibling['factor_conversion'] as int? ?? 1;

              int varSim = _calculateSimilarity(variantToMatch, sName);
              int vScore = (varSim * 0.25).toInt();
              if (vScore > maxVariantScore) maxVariantScore = vScore;

              int uScore = 0;
              if (factorToMatch == sFactor && factorToMatch > 1) {
                // Perfect match por factor (para cajas, docenas, etc)
                uScore = 15;
              } else if (factorToMatch == sFactor && factorToMatch == 1) {
                // Ambos son unidades sueltas, damos buen score
                uScore = 10;
              } else if (unitToMatch.isNotEmpty) {
                // Fallback a nombre
                String unA = unitToMatch.toLowerCase();
                String unB = sUnit.toLowerCase();
                if (unA == unB) {
                  uScore = 10;
                } else if (unB.contains(unA) || unA.contains(unB)) {
                  uScore = 5;
                }
              }
              if (uScore > maxUnitScore) maxUnitScore = uScore;

              int totalSiblingScore = varSim + (uScore > 0 ? 20 : 0);
              if (totalSiblingScore > currentBestSiblingScore) {
                currentBestSiblingScore = totalSiblingScore;
                currentBestSibling = sibling;
              }
            }

            // EVALUACIÓN MULTI-CAMPO COMPUESTA (Fase 1: Cobertura total Factura vs [Padre + Variante + Marca + SKU])
            final composite = CommercialInvoiceNormalizer.evaluateCompositeMatch(
              facturaDescripcion: item.descripcion,
              productoNombre: candidate['nombre'] as String,
              marcaNombre: candidate['marca_nombre'] as String?,
              variantes: normalizedSiblings,
              facturaMarca: item.marcaDetectada,
            );

            if (composite.score > score) {
              score = composite.score;
            }
            if (composite.bestSibling != null && (currentBestSibling == null || composite.bestSiblingScore > currentBestSiblingScore)) {
              currentBestSibling = composite.bestSibling;
              currentBestSiblingScore = composite.bestSiblingScore;
            }

            if (score > highestScore) {
              highestScore = score;
              bestCandidate = candidate;
              bestSiblings = normalizedSiblings;
              bestSiblingOfBestCandidate = currentBestSibling;
              bestSiblingScore = currentBestSiblingScore;
            }
          }

          if (bestCandidate != null && highestScore >= 50) { // FASE 4: Subido de 40 → 50
            prodMatch = MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: highestScore,
              datos: MatchData(
                id: bestCandidate['id'] as int,
                nombre: bestCandidate['nombre'] as String,
                stockActual: (bestCandidate['stock_total'] as num).toInt(),
                marcaNombre: bestCandidate['marca_nombre'] as String?,
                categoriaNombre: bestCandidate['categoria_nombre'] as String?,
                availablePresentations: bestSiblings,
                modoStock: bestCandidate['modo_stock'] as String? ?? 'INDEPENDIENTE',
                stockCompartido: (bestCandidate['stock_compartido'] as num?)?.toInt() ?? 0,
                costoBase: (bestCandidate['costo_base'] as num?)?.toDouble() ?? 0.0,
              ),
            );

            if (bestSiblings.isNotEmpty) {
              bestSiblingOfBestCandidate ??= bestSiblings.first;
              presMatch = MatchResult(
                estado: "MATCH_SUGERIDO",
                confianza: bestSiblingScore > 50 ? 90 : 70,
                datos: MatchData(
                  id: bestSiblingOfBestCandidate['id'] as int,
                  nombre:
                      bestSiblingOfBestCandidate['nombre_especifico']
                          as String? ??
                      "General",
                  stockActual:
                      bestSiblingOfBestCandidate['stock_actual'] as int? ?? 0,
                  precioVentaFinal:
                      (bestSiblingOfBestCandidate['precio_venta'] as num?)
                          ?.toDouble() ??
                      0.0,
                  costoUnitarioCalculado:
                      (bestSiblingOfBestCandidate['precio_costo'] as num?)
                          ?.toDouble() ??
                      0.0,
                  unidadVenta:
                      bestSiblingOfBestCandidate['unidad'] as String? ??
                      "Unidad",
                  umpCompra:
                      bestSiblingOfBestCandidate['ump_compra'] as String? ??
                      "UND",
                  availablePresentations: bestSiblings,
                  usaStockCompartido: bestSiblingOfBestCandidate['usa_stock_compartido'] == true,
                  cupoMaximoVariante: bestSiblingOfBestCandidate['cupo_maximo_variante'] as int?,
                ),
              );
            } else {
              presMatch = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0);
            }
          } else {
            prodMatch = MatchResult(estado: "NUEVO", confianza: 0);
            presMatch = MatchResult(estado: "NUEVO", confianza: 0);
          }
        } else {
          prodMatch = MatchResult(estado: "NUEVO", confianza: 0);
          presMatch = MatchResult(estado: "NUEVO", confianza: 0);
        }

        // --- CÁLCULO DE COSTOS USANDO ScannerCostEngine ---
        double costoUnitarioIndividual = ScannerCostEngine.calculateUnitCost(
          totalPago: item.totalPagoLote,
          cantidadUmp: item.cantidadUmpComprada,
          unidadesPorLote: item.unidadesPorLote,
        );

        double costoPresentacion = ScannerCostEngine.calculatePresentationCost(
          unitCost: costoUnitarioIndividual,
          unidadesPorVenta: 1, // Por defecto al staging asume venta x 1
        );

        double margenSugerido = ScannerCostEngine.suggestDynamicMargin(
          negocioId: negocioId,
          fallbackMargin: 1.35,
        );

        double precioSugerido = ScannerCostEngine.suggestSalePrice(
          presentationCost: costoPresentacion,
          marginFactor: margenSugerido,
        );

        String cleanedNombrePadre =
            item.productoPadreEstimado ?? item.descripcion;
        if (item.productoPadreEstimado == null ||
            item.productoPadreEstimado!.isEmpty) {
          String raw = item.descripcion;
          if (item.marcaDetectada != null && item.marcaDetectada!.isNotEmpty) {
            raw = raw
                .replaceAll(
                  RegExp(item.marcaDetectada!, caseSensitive: false),
                  '',
                )
                .trim();
          }
          if (item.varianteDetectada != null &&
              item.varianteDetectada!.isNotEmpty) {
            raw = raw
                .replaceAll(
                  RegExp(item.varianteDetectada!, caseSensitive: false),
                  '',
                )
                .trim();
          }
          cleanedNombrePadre = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
        }

        String cleanedVariante = item.varianteDetectada ?? item.descripcion;
        if (item.varianteDetectada == null || item.varianteDetectada!.isEmpty) {
          // If no variant detected, it's better to leave it empty or generic than the whole description
          cleanedVariante = "General";
        }

        final modoStockGrupo = prodMatch.datos?.modoStock ?? 'INDEPENDIENTE';
        final stockCompartidoGrupo = prodMatch.datos?.stockCompartido ?? 0;
        final costoBaseGrupo = prodMatch.datos?.costoBase ?? 0.0;

        grupos.add(
          StagingProductGroup(
            nombrePadre: cleanedNombrePadre,
            nombreOriginalFactura: item.descripcion,
            marcaOriginalFactura: item.marcaDetectada ?? "",
            marcaTexto: item.marcaDetectada ?? "",
            matchProducto: prodMatch,
            matchMarca: marcaMatch,
            modoStock: modoStockGrupo,
            stockCompartido: stockCompartidoGrupo,
            costoBase: costoBaseGrupo,
            variantes: [
              StagingVariant(
                nombreEspecifico: cleanedVariante,
                codigoBarra: item.codigo,
                umpCompra: item.umpCompra,
                cantidadUmpComprada: item.cantidadUmpComprada,
                precioUmpProveedor: item
                    .precioUmpProveedor, // Ya viene calculado de la IA (Lote / Cantidad) o se recalcula si es nulo
                totalPagoLote: item.totalPagoLote,
                unidadesPorLote: item.unidadesPorLote,
                unidadVenta: item.unidadVenta,
                unidadesPorVenta: 1,
                costoUnitarioSugerido: costoPresentacion,
                factorGananciaVentaSugerido: margenSugerido,
                precioVentaSugerido: precioSugerido,
                matchPresentacion: presMatch,
              )..usaStockCompartido = presMatch.datos?.usaStockCompartido ?? (modoStockGrupo == 'COMPARTIDO')
               ..cupoMaximoVariante = presMatch.datos?.cupoMaximoVariante,
            ],
          ),
        );
      }

      final stagingResponse = StagingResponse(
        proveedorMatch: provMatch,
        proveedorTexto: aiData.proveedorDetectado,
        rucProveedor: aiData.rucDetectado,
        fechaFactura: aiData.fechaDetectada,
        montoTotalFactura: aiData.montoTotalFactura,
        productosAgrupados: grupos,
      );
      stagingResponse.invoiceId = aiData.invoiceId;

      return stagingResponse;
    } catch (e, stack) {
      AppLogger.error('ScannerMatchingEngine.runMatching', e, stack);
      rethrow;
    }
  }

  /// Función utilitaria para medir qué tanto se parecen dos strings usando
  /// lematización y distancia de Levenshtein (fuzzy matching).
  /// FASE 4: Mejorado con penalización por baja cobertura de tokens.
  int _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;

    a = a.toLowerCase().trim();
    b = b.toLowerCase().trim();

    // Coincidencia exacta
    if (a == b) return 100;
    if (a.contains(b) || b.contains(a)) return 90;

    // Coincidencia lematizada (Lápiz == Lápices)
    String lemA = SpanishLemmatizer.lemmatize(a);
    String lemB = SpanishLemmatizer.lemmatize(b);
    if (lemA == lemB) return 85;

    // Fuzzy matching con Levenshtein global
    double globalSim = SpanishLemmatizer.calculateSimilarity(lemA, lemB);
    if (globalSim >= 0.8) return (globalSim * 100).toInt();

    String normA = CommercialInvoiceNormalizer.normalizeCommercialString(a);
    String normB = CommercialInvoiceNormalizer.normalizeCommercialString(b);
    if (normA == normB) return 100;
    if (normA.contains(normB) || normB.contains(normA)) return 90;

    // Conteo de tokens coincidentes con prefix stemming y normalización
    var tokensA = CommercialInvoiceNormalizer.extractTokens(a);
    var tokensB = CommercialInvoiceNormalizer.extractTokens(b);
    double score = 0;
    int matchingTokenCount = 0;

    for (var ta in tokensA) {
      double bestTokenSim = 0;
      for (var tb in tokensB) {
        double m = CommercialInvoiceNormalizer.matchTokens(ta, tb);
        if (m > bestTokenSim) bestTokenSim = m;
      }
      // Solo sumamos puntos por tokens similares >= 75%
      if (bestTokenSim >= 0.75) {
        score += bestTokenSim;
        matchingTokenCount++;
      }
    }

    if (tokensA.isEmpty) return 0;
    int baseScore = ((score / tokensA.length) * 100).toInt();

    // FASE 4: Penalización por baja cobertura de tokens.
    // Si solo 1 token coincide y hay 3+ tokens, es muy probable un falso positivo.
    // Ej: "CHOCOLATE MAXI MANI" vs "MAXI COFFE TOFFI" → solo "maxi" coincide.
    if (matchingTokenCount <= 1 && tokensA.length >= 3) {
      baseScore = (baseScore * 0.4).toInt(); // Penalizar al 40%
    } else if (matchingTokenCount <= 1 && tokensA.length == 2) {
      baseScore = (baseScore * 0.6).toInt(); // Penalizar al 60%
    }

    // FASE 4: Bonus por cobertura completa de tokens.
    // Si la mayoría de los tokens coinciden, aumentar confianza.
    if (tokensA.isNotEmpty) {
      double coverage = matchingTokenCount / tokensA.length;
      baseScore += (coverage * 15).toInt(); // Hasta 15 puntos extra
    }

    return baseScore.clamp(0, 100);
  }
}
