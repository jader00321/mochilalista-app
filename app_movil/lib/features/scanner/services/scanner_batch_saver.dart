import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';

/// Servicio dedicado al guardado masivo (batch save) de los datos
/// del staging de facturas en la base de datos SQLite local.
///
/// Responsabilidad única: StagingData → Transacción SQLite atómica.
class ScannerBatchSaver {
  final _dbHelper = LocalDatabase.instance;

  /// Ejecuta el guardado masivo dentro de una transacción atómica.
  ///
  /// Crea/actualiza proveedores, productos y presentaciones según
  /// el estado de matching de cada item (MATCH vs NUEVO).
  ///
  /// Retorna `true` si el guardado fue exitoso, `false` en caso de error.
  Future<bool> executeBatchSave({
    required StagingResponse stagingData,
    required int negocioId,
    required int usuarioId,
    void Function(String)? onProgress,
  }) async {
    try {
      final db = await _dbHelper.database;

      await db.transaction((txn) async {
        // 1. Resolver proveedor
        onProgress?.call("Verificando proveedor...");
        int? idProveedor = stagingData.proveedorMatch.datos?.id;
        if (!stagingData.proveedorMatch.estado.contains("MATCH")) {
          idProveedor = await txn.insert('proveedores', {
            'negocio_id': negocioId,
            'nombre_empresa': stagingData.proveedorTexto,
            'ruc': stagingData.rucProveedor,
            'activo': 1,
            'fecha_creacion': DateTime.now().toIso8601String(),
          });
        }

        // 2. Crear registro de factura
        onProgress?.call("Registrando factura...");
        int idFactura = await txn.insert('facturas_carga', {
          'negocio_id': negocioId,
          'proveedor_id': idProveedor,
          'estado': 'completado',
          'fecha_carga': DateTime.now().toIso8601String(),
          'fecha_emision': stagingData.fechaFactura,
          'monto_total_factura': stagingData.montoTotalFactura,
          'imagen_url': 'local_ia_scan',
        });

        // 3. Procesar cada grupo de productos
        int totalGrupos = stagingData.productosAgrupados.length;
        for (int i = 0; i < totalGrupos; i++) {
          var group = stagingData.productosAgrupados[i];
          onProgress?.call("Procesando grupo ${i + 1} de $totalGrupos...");
          var variantesActivas = group.variantes
              .where((v) => v.isConfirmed)
              .toList();
          if (variantesActivas.isEmpty) continue;

          // Resolver producto padre
          int? idProducto = group.matchProducto.datos?.id;
          if (!group.matchProducto.estado.contains("MATCH")) {
            idProducto = await txn.insert('productos', {
              'negocio_id': negocioId,
              'nombre': group.nombrePadre,
              'categoria_id': group.categoriaSugeridaId,
              'estado': 'publico',
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            });
          }

          // 4. Procesar cada variante/presentación
          for (var v in variantesActivas) {
            int cantidadSumar =
                ((v.cantidadUmpComprada * v.unidadesPorLote) / v.unidadesPorVenta)
                    .toInt();

            if (v.matchPresentacion.estado.contains("MATCH") &&
                v.matchPresentacion.estado != "NUEVO_EN_PADRE") {
              // Actualizar presentación existente
              int idPres = v.matchPresentacion.datos!.id;

              final oldP = await txn.query(
                'presentaciones_producto',
                where: 'id = ?',
                whereArgs: [idPres],
              );
              int stockActual =
                  (oldP.first['stock_actual'] as int?) ?? 0;

              Map<String, dynamic> updateData = {
                'stock_actual': v.stockOperation == 'reemplazar' ? cantidadSumar : (stockActual + cantidadSumar),
              };
              int stockDiff = (updateData['stock_actual'] as int) - stockActual;
              
              if (v.updateCosto || v.updatePrecio) {
                updateData['unidad_venta'] = v.unidadVenta;
                updateData['unidades_por_venta'] = v.unidadesPorVenta;
              }
              
              if (v.updateCosto) {
                updateData['costo_unitario_calculado'] = v.costoUnitarioSugerido;
              }
              if (v.updatePrecio) {
                updateData['precio_venta_final'] = v.precioVentaSugerido;
                updateData['factor_ganancia_venta'] = v.factorGananciaVentaSugerido;
                
                // Lógica de descuentos
                if (oldP.first['precio_oferta'] != null) {
                  if (v.keepDescuento) {
                    double nuevoPrecioVenta = v.precioVentaSugerido;
                    String tipo = oldP.first['tipo_descuento'] as String? ?? 'monto';
                    double valor = (oldP.first['valor_descuento'] as num?)?.toDouble() ?? 0.0;
                    
                    double nuevoPrecioOferta = nuevoPrecioVenta;
                    if (tipo == 'porcentaje') {
                       nuevoPrecioOferta = nuevoPrecioVenta - (nuevoPrecioVenta * (valor / 100));
                    } else {
                       nuevoPrecioOferta = nuevoPrecioVenta - valor;
                    }
                    if (nuevoPrecioOferta < 0) nuevoPrecioOferta = 0;
                    updateData['precio_oferta'] = nuevoPrecioOferta;
                  } else {
                    updateData['precio_oferta'] = null;
                    updateData['tipo_descuento'] = null;
                    updateData['valor_descuento'] = null;
                  }
                }
              }
              if (v.updateNombre) {
                updateData['nombre_especifico'] = v.nombreEspecifico;
              }

              await txn.update(
                'presentaciones_producto',
                updateData,
                where: 'id = ?',
                whereArgs: [idPres],
              );
              
              if (stockDiff != 0) {
                await txn.insert('stock_ledger', {
                  'presentation_id': idPres,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'COMPRA_LOTE',
                  'cantidad': stockDiff,
                  'costo_unitario': updateData['costo_unitario_calculado'] ?? oldP.first['costo_unitario_calculado'],
                  'precio_venta': updateData['precio_venta_final'] ?? oldP.first['precio_venta_final'],
                  'origen_id': idFactura,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }
            } else {
              int newPresId = await txn.insert('presentaciones_producto', {
                'producto_id': idProducto,
                'proveedor_id': idProveedor,
                'factura_carga_id': idFactura,
                'nombre_especifico': v.nombreEspecifico,
                'codigo_barras': v.codigoBarra,
                'ump_compra': v.umpCompra,
                'precio_ump_proveedor': v.precioUmpProveedor,
                'cantidad_ump_comprada': v.cantidadUmpComprada,
                'total_pago_lote': v.totalPagoLote,
                'unidades_por_lote': v.unidadesPorLote,
                'unidad_venta': v.unidadVenta,
                'unidades_por_venta': v.unidadesPorVenta,
                'factor_ganancia_venta': v.factorGananciaVentaSugerido,
                'costo_unitario_calculado': v.costoUnitarioSugerido,
                'precio_venta_final': v.precioVentaSugerido,
                'stock_actual': cantidadSumar,
                'estado': 'publico',
                'activo': 1,
                'es_default': 0,
              });
              
              if (cantidadSumar > 0) {
                await txn.insert('stock_ledger', {
                  'presentation_id': newPresId,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'COMPRA_LOTE',
                  'cantidad': cantidadSumar,
                  'costo_unitario': v.costoUnitarioSugerido,
                  'precio_venta': v.precioVentaSugerido,
                  'origen_id': idFactura,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }
            }
          }
        }
      });

      return true;
    } catch (e, stack) {
      AppLogger.error('ScannerBatchSaver.executeBatchSave', e, stack);
      rethrow;
    }
  }
}
