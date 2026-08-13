import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';

/// Servicio dedicado a la lógica de matching (coincidencia) entre
/// los items extraídos por la IA y los productos existentes en SQLite.
///
/// Responsabilidad única: Datos de IA → Datos de Staging con matches.
class ScannerMatchingEngine {
  final _dbHelper = LocalDatabase.instance;

  /// Ejecuta el proceso de matching contra la base de datos local.
  ///
  /// Toma la respuesta cruda de la IA y busca coincidencias en SQLite
  /// para proveedores, productos y presentaciones.
  ///
  /// Retorna un [StagingResponse] con los matches encontrados, o `null` si hay error.
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
        final searchName = item.productoPadreEstimado ?? item.descripcion;
        final prodQuery = await db.query(
          'productos',
          where: 'negocio_id = ? AND nombre LIKE ?',
          whereArgs: [negocioId, '%$searchName%'],
          limit: 1,
        );

        MatchResult prodMatch;
        MatchResult presMatch;

        if (prodQuery.isNotEmpty) {
          int prodId = prodQuery.first['id'] as int;
          prodMatch = MatchResult(
            estado: "MATCH_SUGERIDO",
            confianza: 85,
            datos: MatchData(
              id: prodId,
              nombre: prodQuery.first['nombre'] as String,
            ),
          );

          // Buscar presentaciones del producto encontrado
          final presQuery = await db.query(
            'presentaciones_producto',
            where: 'producto_id = ?',
            whereArgs: [prodId],
          );

          if (presQuery.isNotEmpty) {
            presMatch = MatchResult(
              estado: "MATCH_SUGERIDO",
              confianza: 80,
              datos: MatchData(
                id: presQuery.first['id'] as int,
                nombre: presQuery.first['nombre_especifico'] as String? ?? "General",
                stockActual: presQuery.first['stock_actual'] as int? ?? 0,
                precioVentaFinal: (presQuery.first['precio_venta_final'] as num?)?.toDouble() ?? 0.0,
                costoUnitarioCalculado: (presQuery.first['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0,
                unidadVenta: presQuery.first['unidad_venta'] as String? ?? "Unidad",
                umpCompra: presQuery.first['ump_compra'] as String? ?? "UND",
                availablePresentations: presQuery.cast<Map<String, dynamic>>(),
              ),
            );
          } else {
            presMatch = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0);
          }
        } else {
          prodMatch = MatchResult(estado: "NUEVO", confianza: 0);
          presMatch = MatchResult(estado: "NUEVO", confianza: 0);
        }

        // Calcular costos sugeridos
        double costoUnitario = item.unidadesPorLote > 0
            ? (item.precioUmpProveedor / item.unidadesPorLote)
            : 0;

        grupos.add(StagingProductGroup(
          nombrePadre: item.productoPadreEstimado ?? item.descripcion,
          nombreOriginalFactura: item.descripcion,
          marcaTexto: item.marcaDetectada ?? "",
          matchProducto: prodMatch,
          matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
          variantes: [
            StagingVariant(
              nombreEspecifico: item.varianteDetectada ?? item.descripcion,
              codigoBarra: item.codigo,
              umpCompra: item.umpCompra,
              cantidadUmpComprada: item.cantidadUmpComprada,
              precioUmpProveedor: item.precioUmpProveedor,
              totalPagoLote: item.totalPagoLote,
              unidadesPorLote: item.unidadesPorLote,
              unidadVenta: item.unidadVenta,
              unidadesPorVenta: 1,
              costoUnitarioSugerido: costoUnitario,
              factorGananciaVentaSugerido: 1.35,
              precioVentaSugerido: costoUnitario * 1.35,
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
}
