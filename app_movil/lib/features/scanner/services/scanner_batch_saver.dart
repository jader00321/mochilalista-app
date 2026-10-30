import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

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
    String? aiRawJson,
    String? imagePath,
    int? itemCount,
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
        
        final seqResult = await txn.rawQuery(
          'SELECT MAX(numero_secuencial) as max_seq FROM facturas_carga WHERE negocio_id = ?',
          [negocioId]
        );
        int nextSeq = (seqResult.first['max_seq'] as int? ?? 0) + 1;

        int idFactura = await txn.insert('facturas_carga', {
          'numero_secuencial': nextSeq,
          'negocio_id': negocioId,
          'proveedor_id': idProveedor,
          'estado': 'completado',
          'fecha_carga': DateTime.now().toIso8601String(),
          'fecha_emision': stagingData.fechaFactura,
          'monto_total_factura': stagingData.montoTotalFactura,
          'imagen_url': imagePath ?? 'local_ia_scan',
          'datos_crudos_ia_json': aiRawJson,
          'cantidad_items_extraidos': itemCount ?? 0,
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
          int? idMarca = group.matchMarca.datos?.id;
          bool hasMarcaUpdate = variantesActivas.any((v) => v.updateMarca);

          if (hasMarcaUpdate || !group.matchProducto.estado.contains("MATCH")) {
            String marcaTextToSave = group.marcaTexto.trim();
            if (hasMarcaUpdate) {
              var vWithMarca = variantesActivas.firstWhere((v) => v.updateMarca, orElse: () => variantesActivas.first);
              if (vWithMarca.editedMarca != null) marcaTextToSave = vWithMarca.editedMarca!.trim();
            }
            if (marcaTextToSave.isNotEmpty &&
                marcaTextToSave.toLowerCase() != 'genérica') {
              final existingMarca = await txn.query(
                'marcas',
                where: 'LOWER(nombre) = ? AND negocio_id = ?',
                whereArgs: [marcaTextToSave.toLowerCase(), negocioId],
              );
              if (existingMarca.isNotEmpty) {
                idMarca = existingMarca.first['id'] as int;
              } else {
                idMarca = await txn.insert('marcas', {
                  'negocio_id': negocioId,
                  'nombre': marcaTextToSave,
                  'activo': 1,
                });
              }
            } else {
              idMarca = null;
            }
          }

          if (!group.matchProducto.estado.contains("MATCH")) {
            idProducto = await txn.insert('productos', {
              'negocio_id': negocioId,
              'nombre': group.nombrePadre,
              'categoria_id': group.categoriaSugeridaId,
              'marca_id': idMarca,
              'estado': 'publico',
              'modo_stock': group.modoStock,
              'stock_compartido': group.stockCompartido,
              'costo_base': group.costoBase,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            });
          } else if (idProducto != null) {
            Map<String, dynamic> prodUpdates = {
              'modo_stock': group.modoStock,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            if (hasMarcaUpdate) {
              prodUpdates['marca_id'] = idMarca;
            }
            if (group.stockCompartido > 0) {
              prodUpdates['stock_compartido'] = group.stockCompartido;
            }
            if (group.costoBase > 0) {
              prodUpdates['costo_base'] = group.costoBase;
            }
            await txn.update(
              'productos',
              prodUpdates,
              where: 'id = ?',
              whereArgs: [idProducto],
            );
          }

          // 4. Procesar cada variante/presentación
          for (var v in variantesActivas) {
            int cantidadSumar = v.stockIngresanteBase;

            if (v.matchPresentacion.estado.contains("MATCH") &&
                v.matchPresentacion.estado != "NUEVO_EN_PADRE") {
              // Actualizar presentación existente
              int idPres = v.matchPresentacion.datos!.id;

              final oldP = await txn.query(
                'presentaciones_producto',
                where: 'id = ?',
                whereArgs: [idPres],
              );
              int stockActual = (oldP.first['stock_actual'] as int?) ?? 0;

              Map<String, dynamic> updateData = {
                'stock_actual': v.stockOperation == 'reemplazar'
                    ? cantidadSumar
                    : (stockActual + cantidadSumar),
                'factura_carga_id': idFactura,
                'proveedor_id': idProveedor,
              };

              // FASE 5 FIX: Datos de compra se guardan como BLOQUE ATÓMICO coherente
              // (no individualmente) para evitar inconsistencias entre campos dependientes.
              if (v.updateDatosCompra) {
                updateData['ump_compra'] = v.umpCompra;
                updateData['precio_ump_proveedor'] = v.precioUmpProveedor;
                updateData['cantidad_ump_comprada'] = v.cantidadUmpComprada;
                updateData['total_pago_lote'] = v.totalPagoLote;
                updateData['unidades_por_lote'] = v.unidadesPorLote;
              }
              int stockDiff = (updateData['stock_actual'] as int) - stockActual;

              // FASE 5 FIX: Unidad de venta se guarda con su propio flag
              // (antes dependía de updateCosto || updatePrecio)
              if (v.updateUnidadVenta) {
                updateData['unidad_venta'] = v.effectiveUnidadVenta;
                updateData['unidades_por_venta'] = v.effectiveFactorVenta;
              }

              if (v.updateCosto) {
                updateData['costo_unitario_calculado'] =
                    v.costoUnitarioSugerido;
              }
              if (v.updatePrecio) {
                updateData['precio_venta_final'] = v.precioVentaSugerido;
                updateData['factor_ganancia_venta'] =
                    v.factorGananciaVentaSugerido;

                // Lógica de descuentos
                if (oldP.first['precio_oferta'] != null) {
                  String mode =
                      v.discountMode ?? (v.keepDescuento ? 'keep' : 'remove');
                  if (mode == 'keep') {
                    double nuevoPrecioVenta = v.precioVentaSugerido;
                    String tipo =
                        oldP.first['tipo_descuento'] as String? ?? 'monto';
                    double valor =
                        (oldP.first['valor_descuento'] as num?)?.toDouble() ??
                        0.0;

                    double nuevoPrecioOferta = nuevoPrecioVenta;
                    if (tipo == 'porcentaje') {
                      nuevoPrecioOferta =
                          nuevoPrecioVenta - (nuevoPrecioVenta * (valor / 100));
                    } else {
                      nuevoPrecioOferta = nuevoPrecioVenta - valor;
                    }
                    if (nuevoPrecioOferta < 0) nuevoPrecioOferta = 0;
                    updateData['precio_oferta'] = nuevoPrecioOferta;
                  } else if (mode == 'edit' && v.discountManualValue != null) {
                    double manualOffer = v.discountManualValue!;
                    if (manualOffer < 0) manualOffer = 0;
                    updateData['precio_oferta'] = manualOffer;
                    updateData['tipo_descuento'] = 'monto';
                    updateData['valor_descuento'] =
                        v.precioVentaSugerido - manualOffer;
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
              if (v.updateCodigoBarra) {
                updateData['codigo_barras'] = v.codigoBarra;
              }

              final bool esCompartido = v.usaStockCompartido || (group.modoStock == 'COMPARTIDO');
              if (esCompartido) {
                updateData['usa_stock_compartido'] = 1;
                if (v.cupoMaximoVariante != null) {
                  updateData['cupo_maximo_variante'] = v.cupoMaximoVariante;
                }
              } else if (group.modoStock == 'INDEPENDIENTE') {
                updateData['usa_stock_compartido'] = 0;
              }

              await txn.update(
                'presentaciones_producto',
                updateData,
                where: 'id = ?',
                whereArgs: [idPres],
              );

              // 🔗 Si la presentación usa stock compartido, sincronizar el pool central y hermanos
              final bool usaCompartido = (oldP.first['usa_stock_compartido'] as int? ?? 0) == 1 || esCompartido;
              if (usaCompartido && idProducto != null) {
                final int nuevoStock = updateData['stock_actual'] as int;
                final factorVenta = (v.effectiveFactorVenta > 0) ? v.effectiveFactorVenta : 1;
                final Map<String, dynamic> prodUpdates = {
                  'stock_compartido': nuevoStock,
                  'fecha_actualizacion': DateTime.now().toIso8601String(),
                };
                if (v.updateCosto) {
                  prodUpdates['costo_base'] = v.costoUnitarioSugerido / factorVenta;
                }
                await txn.update(
                  'productos',
                  prodUpdates,
                  where: 'id = ?',
                  whereArgs: [idProducto],
                );
                await txn.update(
                  'presentaciones_producto',
                  {'stock_actual': nuevoStock},
                  where: 'producto_id = ? AND usa_stock_compartido = 1',
                  whereArgs: [idProducto],
                );
              }

              // Auditar cambios en descuentos si la factura modificó el precio/oferta
              if (updateData.containsKey('precio_oferta')) {
                double oldVenta = (oldP.first['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
                double? oldOferta = (oldP.first['precio_oferta'] as num?)?.toDouble();
                String? oldTipo = oldP.first['tipo_descuento']?.toString();
                double oldVal = (oldP.first['valor_descuento'] as num?)?.toDouble() ?? 0.0;
                bool hadOffer = oldOferta != null && oldOferta > 0 && oldOferta < oldVenta;

                double newVenta = (updateData['precio_venta_final'] as num?)?.toDouble() ?? oldVenta;
                double? newOferta = (updateData['precio_oferta'] as num?)?.toDouble();
                String? newTipo = updateData['tipo_descuento']?.toString() ?? oldTipo;
                double newVal = (updateData['valor_descuento'] as num?)?.toDouble() ?? oldVal;
                bool hasOffer = newOferta != null && newOferta > 0 && newOferta < newVenta;

                String pTag = (v.nombreEspecifico.trim().isNotEmpty && v.nombreEspecifico.trim() != 'Unidad')
                    ? ' (${v.nombreEspecifico.trim()})'
                    : '';

                if (hadOffer && !hasOffer) {
                  String valAnt = (oldTipo == 'porcentaje')
                      ? '${oldVal.toStringAsFixed(oldVal.truncateToDouble() == oldVal ? 0 : 1)}% OFF$pTag (${AppCurrency.format(oldOferta)})'
                      : '-${AppCurrency.format(oldVal)} OFF$pTag (${AppCurrency.format(oldOferta)})';
                  await txn.insert('product_history', {
                    'entidad_tipo': 'PRESENTACION',
                    'entidad_id': idPres,
                    'campo_modificado': 'descuento',
                    'valor_anterior': valAnt,
                    'valor_nuevo': 'Oferta finalizada$pTag por actualización de factura',
                    'fecha_cambio': DateTime.now().toIso8601String(),
                  });
                } else if (hasOffer) {
                  String valAnt = hadOffer 
                      ? ((oldTipo == 'porcentaje')
                          ? '${oldVal.toStringAsFixed(oldVal.truncateToDouble() == oldVal ? 0 : 1)}% OFF$pTag (${AppCurrency.format(oldOferta)})'
                          : '-${AppCurrency.format(oldVal)} OFF$pTag (${AppCurrency.format(oldOferta)})')
                      : 'Sin descuento';
                  String valNuevo = (newTipo == 'porcentaje')
                      ? 'Oferta actualizada$pTag: ${newVal.toStringAsFixed(newVal.truncateToDouble() == newVal ? 0 : 1)}% OFF → Precio Oferta: ${AppCurrency.format(newOferta)}'
                      : 'Oferta actualizada$pTag: -${AppCurrency.format(newVal)} OFF → Precio Oferta: ${AppCurrency.format(newOferta)}';
                  await txn.insert('product_history', {
                    'entidad_tipo': 'PRESENTACION',
                    'entidad_id': idPres,
                    'campo_modificado': 'descuento',
                    'valor_anterior': valAnt,
                    'valor_nuevo': valNuevo,
                    'fecha_cambio': DateTime.now().toIso8601String(),
                  });
                }
              }

              if (stockDiff != 0) {
                await txn.insert('stock_ledger', {
                  'presentation_id': idPres,
                  'negocio_id': negocioId,
                  'tipo_transaccion': 'COMPRA_LOTE',
                  'cantidad': stockDiff,
                  'costo_unitario':
                      updateData['costo_unitario_calculado'] ??
                      oldP.first['costo_unitario_calculado'],
                  'precio_venta':
                      updateData['precio_venta_final'] ??
                      oldP.first['precio_venta_final'],
                  'origen_id': idFactura,
                  'fecha_registro': DateTime.now().toIso8601String(),
                });
              }
            } else {
              // Asegurar que la primera presentación del producto sea la default principal
              final existingDefaults = await txn.query(
                'presentaciones_producto',
                columns: ['id'],
                where: 'producto_id = ? AND es_default = 1',
                whereArgs: [idProducto],
                limit: 1,
              );
              final int esDefaultValue = existingDefaults.isEmpty ? 1 : 0;
              final bool esCompartido = v.usaStockCompartido || (group.modoStock == 'COMPARTIDO');

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
                'unidad_venta': v.effectiveUnidadVenta,
                'unidades_por_venta': v.effectiveFactorVenta,
                'factor_ganancia_venta': v.factorGananciaVentaSugerido,
                'costo_unitario_calculado': v.costoUnitarioSugerido,
                'precio_venta_final': v.precioVentaSugerido,
                'stock_actual': (esCompartido && group.stockCompartido > 0) ? group.stockCompartido : cantidadSumar,
                'usa_stock_compartido': esCompartido ? 1 : 0,
                'cupo_maximo_variante': v.cupoMaximoVariante,
                'estado': 'publico',
                'activo': 1,
                'es_default': esDefaultValue,
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

          // Regla 3: Sincronización atómica de todas las variantes hermanas en SQLite dentro de la misma transacción
          if (idProducto != null && (group.modoStock == 'COMPARTIDO' || group.modoStock == 'MIXTO')) {
            int poolFinal = group.stockCompartido;
            double costoBaseFinal = group.costoBase;

            if (poolFinal <= 0) {
              final currentShared = await txn.rawQuery('''
                SELECT IFNULL(MAX(stock_actual), 0) as max_shared
                FROM presentaciones_producto
                WHERE producto_id = ? AND usa_stock_compartido = 1
              ''', [idProducto]);
              if (currentShared.isNotEmpty) {
                poolFinal = (currentShared.first['max_shared'] as num?)?.toInt() ?? 0;
              }
            }

            if (costoBaseFinal <= 0) {
              final costRow = await txn.rawQuery('''
                SELECT costo_unitario_calculado, unidades_por_venta
                FROM presentaciones_producto
                WHERE producto_id = ? AND usa_stock_compartido = 1
                ORDER BY unidades_por_venta ASC
                LIMIT 1
              ''', [idProducto]);
              if (costRow.isNotEmpty) {
                final c = (costRow.first['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
                final f = (costRow.first['unidades_por_venta'] as int?) ?? 1;
                if (f > 0) costoBaseFinal = c / f;
              }
            }

            // 1. Actualizar producto padre
            Map<String, dynamic> prodSync = {
              'modo_stock': group.modoStock,
              'stock_compartido': poolFinal,
              'fecha_actualizacion': DateTime.now().toIso8601String(),
            };
            if (costoBaseFinal > 0) {
              prodSync['costo_base'] = costoBaseFinal;
            }
            await txn.update('productos', prodSync, where: 'id = ?', whereArgs: [idProducto]);

            // 2. Actualizar stock atómicamente en todas las presentaciones compartidas
            await txn.rawUpdate('''
              UPDATE presentaciones_producto
              SET stock_actual = ?
              WHERE producto_id = ? AND usa_stock_compartido = 1
            ''', [poolFinal, idProducto]);

            // 3. Actualizar costo unitario proporcional si costo_base fue actualizado
            if (costoBaseFinal > 0) {
              await txn.rawUpdate('''
                UPDATE presentaciones_producto
                SET costo_unitario_calculado = ? * unidades_por_venta
                WHERE producto_id = ? AND usa_stock_compartido = 1
              ''', [costoBaseFinal, idProducto]);
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
