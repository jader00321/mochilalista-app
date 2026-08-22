import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';

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
        final originalTokens = searchName.split(' ').where((t) => t.length > 2).toList();
        
        List<Map<String, dynamic>> prodQuery = [];
        if (originalTokens.isNotEmpty) {
          String whereClause = 'negocio_id = ?';
          List<dynamic> whereArgs = [negocioId];
          
          for (var originalToken in originalTokens) {
            String lemmatizedToken = SpanishLemmatizer.lemmatize(originalToken);
            whereClause += ' AND (nombre LIKE ? OR nombre LIKE ?)';
            whereArgs.add('%$originalToken%');
            whereArgs.add('%$lemmatizedToken%');
          }
          
          prodQuery = await db.query(
            'productos',
            where: whereClause,
            whereArgs: whereArgs,
            limit: 5, // Traer hasta 5 candidatos
          );
        }

        MatchResult prodMatch;
        MatchResult presMatch;

        if (prodQuery.isNotEmpty) {
          // Tomamos el primer resultado del token matching
          int prodId = prodQuery.first['id'] as int;
          
          // Calcular confianza básica
          int confianza = originalTokens.length == 1 ? 95 : 85;

          prodMatch = MatchResult(
            estado: "MATCH_SUGERIDO",
            confianza: confianza,
            datos: MatchData(
              id: prodId,
              nombre: prodQuery.first['nombre'] as String,
            ),
          );

          // MATCH DE PRESENTACIÓN INTELIGENTE
          final presQuery = await db.query(
            'presentaciones_producto',
            where: 'producto_id = ?',
            whereArgs: [prodId],
          );

          if (presQuery.isNotEmpty) {
            List<Map<String, dynamic>> normalizedSiblings = presQuery.map((p) {
              return {
                "id": p['id'],
                "nombre_presentacion": p['unidad_venta'] ?? "Unidad",
                "nombre_especifico": p['nombre_especifico'],
                "nombre_completo": "${p['unidad_venta'] ?? 'Unidad'} ${p['nombre_especifico'] ?? ''}".trim(),
                "stock_actual": p['stock_actual'],
                "precio_venta": p['precio_venta_final'],
                "precio_costo": p['costo_unitario_calculado'],
                "factor_conversion": p['unidades_por_venta'],
                "unidad": p['unidad_venta'] ?? "Unidad",
                "factor_ganancia_venta": p['factor_ganancia_venta'],
                "precio_oferta": p['precio_oferta'],
                "tipo_descuento": p['tipo_descuento'],
                "valor_descuento": p['valor_descuento']
              };
            }).toList();

            Map<String, dynamic>? bestPres;
            int bestScore = -1;
            String variantToMatch = item.varianteDetectada ?? item.descripcion;

            for (var pres in normalizedSiblings) {
              String nombreEsp = pres['nombre_especifico'] as String? ?? "";
              int score = _calculateSimilarity(variantToMatch, nombreEsp);
              if (score > bestScore) {
                bestScore = score;
                bestPres = pres;
              }
            }

            bestPres ??= normalizedSiblings.first;

            presMatch = MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: bestScore > 50 ? 90 : 70, // Confianza dinámica
              datos: MatchData(
                id: bestPres['id'] as int,
                nombre: bestPres['nombre_especifico'] as String? ?? "General",
                stockActual: bestPres['stock_actual'] as int? ?? 0,
                precioVentaFinal: (bestPres['precio_venta'] as num?)?.toDouble() ?? 0.0,
                costoUnitarioCalculado: (bestPres['precio_costo'] as num?)?.toDouble() ?? 0.0,
                unidadVenta: bestPres['unidad'] as String? ?? "Unidad",
                umpCompra: "UND", // Ya no viene en el norm
                availablePresentations: normalizedSiblings,
              ),
            );
          } else {
            presMatch = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0);
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
          fallbackMargin: 1.35
        );

        double precioSugerido = ScannerCostEngine.suggestSalePrice(
          presentationCost: costoPresentacion,
          marginFactor: margenSugerido,
        );

        grupos.add(StagingProductGroup(
          nombrePadre: item.productoPadreEstimado ?? item.descripcion,
          nombreOriginalFactura: item.descripcion,
          marcaTexto: item.marcaDetectada ?? "",
          matchProducto: prodMatch,
          matchMarca: marcaMatch,
          variantes: [
            StagingVariant(
              nombreEspecifico: item.varianteDetectada ?? item.descripcion,
              codigoBarra: item.codigo,
              umpCompra: item.umpCompra,
              cantidadUmpComprada: item.cantidadUmpComprada,
              precioUmpProveedor: item.precioUmpProveedor, // Ya viene calculado de la IA (Lote / Cantidad) o se recalcula si es nulo
              totalPagoLote: item.totalPagoLote,
              unidadesPorLote: item.unidadesPorLote,
              unidadVenta: item.unidadVenta,
              unidadesPorVenta: 1,
              costoUnitarioSugerido: costoPresentacion,
              factorGananciaVentaSugerido: margenSugerido,
              precioVentaSugerido: precioSugerido,
              matchPresentacion: presMatch,
            ),
          ],
        ));
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

    // Conteo básico de tokens coincidentes lematizados y difusos
    var tokensA = a.split(' ');
    var tokensB = b.split(' ');
    double score = 0;
    
    for (var ta in tokensA) {
      String lta = SpanishLemmatizer.lemmatize(ta);
      double bestTokenSim = 0;
      for (var tb in tokensB) {
         String ltb = SpanishLemmatizer.lemmatize(tb);
         if (lta == ltb) {
           bestTokenSim = 1.0;
           break;
         } else {
           double sim = SpanishLemmatizer.calculateSimilarity(lta, ltb);
           if (sim > bestTokenSim) bestTokenSim = sim;
         }
      }
      // Solo sumamos puntos por tokens similares >= 75%
      if (bestTokenSim >= 0.75) {
        score += bestTokenSim;
      }
    }
    
    if (tokensA.isEmpty) return 0;
    return ((score / tokensA.length) * 100).toInt();
  }
}
