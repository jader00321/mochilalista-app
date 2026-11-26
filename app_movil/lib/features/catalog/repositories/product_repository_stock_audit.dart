part of 'product_repository.dart';

mixin _ProductRepositoryStockAuditMixin on _ProductRepositoryBase {
  @override
  Future<void> _recordInitialDiscountTxn(
    dynamic txnOrDb,
    int presentationId,
    Map<String, dynamic> data,
  ) async {
    final double price = (data['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
    final double? offer = (data['precio_oferta'] as num?)?.toDouble();
    final String? type = data['tipo_descuento']?.toString();
    final double val = (data['valor_descuento'] as num?)?.toDouble() ?? 0.0;

    final bool hasOffer = offer != null && offer > 0 && offer < price;
    if (hasOffer) {
      String presTag = (data['nombre_especifico'] != null &&
              data['nombre_especifico'].toString().trim().isNotEmpty &&
              data['nombre_especifico'].toString().trim() != 'Unidad')
          ? ' (${data['nombre_especifico'].toString().trim()})'
          : '';

      String valNuevo = (type == 'porcentaje')
          ? 'Oferta activada$presTag: ${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}% OFF → Precio Oferta: ${AppCurrency.format(offer)}'
          : 'Oferta activada$presTag: -${AppCurrency.format(val)} OFF → Precio Oferta: ${AppCurrency.format(offer)}';

      await txnOrDb.insert('product_history', {
        'entidad_tipo': 'PRESENTACION',
        'entidad_id': presentationId,
        'campo_modificado': 'descuento',
        'valor_anterior': 'Sin descuento',
        'valor_nuevo': valNuevo,
        'fecha_cambio': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<int> updatePresentation(int id, Map<String, dynamic> data) async {
    final db = await _dbHelper.database;
    return await db.transaction(
      (txn) async => _updatePresentationTxn(txn, id, data),
    );
  }

  @override
  Future<int> _updatePresentationTxn(
    dynamic txn,
    int id,
    Map<String, dynamic> data,
  ) async {
    final oldRows = await txn.query(
      'presentaciones_producto',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (oldRows.isEmpty) return 0;
    final old = oldRows.first;

    int res = await txn.update(
      'presentaciones_producto',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Interceptar cambio de stock para stock_ledger
    if (data.containsKey('stock_actual')) {
      int oldStock = (old['stock_actual'] as num?)?.toInt() ?? 0;
      int newStock = (data['stock_actual'] as num?)?.toInt() ?? 0;
      int diff = newStock - oldStock;

      if (diff != 0) {
        int? prodId = old['producto_id'] as int?;
        int negocioId = 0;
        bool isShared = (old['usa_stock_compartido'] == 1);
        if (prodId != null) {
          final pRows = await txn.query(
            'productos',
            columns: ['negocio_id', 'modo_stock'],
            where: 'id = ?',
            whereArgs: [prodId],
          );
          if (pRows.isNotEmpty) {
            negocioId = (pRows.first['negocio_id'] as num?)?.toInt() ?? 0;
            final modoStock = pRows.first['modo_stock'] as String?;
            if (modoStock == 'COMPARTIDO') {
              isShared = true;
            }
          }
        }

        // Sincronizar atómicamente el pool de stock compartido y sus variantes vinculadas
        if (isShared && prodId != null) {
          await txn.rawUpdate(
            'UPDATE productos SET stock_compartido = ? WHERE id = ?',
            [newStock, prodId],
          );
          await txn.rawUpdate(
            'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
            [newStock, prodId, id],
          );

          // Acotar cupos de variantes compartidas que superen el nuevo máximo físico
          final sharedVars = await txn.query(
            'presentaciones_producto',
            columns: ['id', 'unidades_por_venta', 'cupo_maximo_variante'],
            where: 'producto_id = ? AND usa_stock_compartido = 1',
            whereArgs: [prodId],
          );
          for (var sv in sharedVars) {
            int svId = sv['id'] as int;
            int svFactor = (sv['unidades_por_venta'] as int?) ?? 1;
            if (svFactor <= 0) svFactor = 1;
            int svMaxFisico = newStock ~/ svFactor;
            int? svCupo = sv['cupo_maximo_variante'] as int?;
            if (svCupo != null && svCupo > svMaxFisico) {
              await txn.update(
                'presentaciones_producto',
                {'cupo_maximo_variante': svMaxFisico},
                where: 'id = ?',
                whereArgs: [svId],
              );
            }
          }
        }

        await txn.insert('stock_ledger', {
          'presentation_id': id,
          'negocio_id': negocioId,
          'tipo_transaccion': 'AJUSTE_INVENTARIO',
          'cantidad': diff,
          'costo_unitario':
              data['costo_unitario_calculado'] ??
              old['costo_unitario_calculado'],
          'precio_venta':
              data['precio_venta_final'] ?? old['precio_venta_final'],
          'fecha_registro': DateTime.now().toIso8601String(),
        });
      }
    }

    // Interceptar otros cambios para product_history
    List<String> fieldsToTrack = [
      'precio_venta_final',
      'costo_unitario_calculado',
      'estado',
    ];
    for (String field in fieldsToTrack) {
      if (data.containsKey(field)) {
        String oldVal = old[field]?.toString() ?? '';
        String newVal = data[field]?.toString() ?? '';
        if (oldVal != newVal) {
          // Si es campo monetario, ignorar diferencias despreciables por coma flotante
          if (field == 'precio_venta_final' ||
              field == 'costo_unitario_calculado') {
            double oldNum = double.tryParse(oldVal) ?? 0.0;
            double newNum = double.tryParse(newVal) ?? 0.0;
            if ((newNum - oldNum).abs() < 0.005) {
              continue;
            }
          }

          await txn.insert('product_history', {
            'entidad_tipo': 'PRESENTACION',
            'entidad_id': id,
            'campo_modificado': field,
            'valor_anterior': oldVal,
            'valor_nuevo': newVal,
            'fecha_cambio': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    // Interceptar cambios en Descuentos y Promociones para product_history (REGLA TÉCNICA 1)
    final bool hasDiscountKey = data.containsKey('precio_oferta') ||
        data.containsKey('tipo_descuento') ||
        data.containsKey('valor_descuento');

    if (hasDiscountKey) {
      double oldPrice = (old['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
      double? oldOffer = (old['precio_oferta'] as num?)?.toDouble();
      String? oldType = old['tipo_descuento']?.toString();
      double oldVal = (old['valor_descuento'] as num?)?.toDouble() ?? 0.0;
      bool oldHasOffer = oldOffer != null && oldOffer > 0 && oldOffer < oldPrice;

      double newPrice = data.containsKey('precio_venta_final')
          ? ((data['precio_venta_final'] as num?)?.toDouble() ?? oldPrice)
          : oldPrice;
      double? newOffer = data.containsKey('precio_oferta')
          ? (data['precio_oferta'] == null
              ? null
              : (data['precio_oferta'] as num?)?.toDouble())
          : oldOffer;
      String? newType = data.containsKey('tipo_descuento')
          ? data['tipo_descuento']?.toString()
          : oldType;
      double newVal = data.containsKey('valor_descuento')
          ? ((data['valor_descuento'] as num?)?.toDouble() ?? 0.0)
          : oldVal;
      bool newHasOffer = newOffer != null && newOffer > 0 && newOffer < newPrice;

      String presTag = (old['nombre_especifico'] != null &&
              old['nombre_especifico'].toString().trim().isNotEmpty &&
              old['nombre_especifico'].toString().trim() != 'Unidad')
          ? ' (${old['nombre_especifico'].toString().trim()})'
          : '';

      String formatOfferLabel(String? type, double val, double offer) {
        if (type == 'porcentaje') {
          String pctStr =
              val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1);
          return '$pctStr% OFF$presTag (${AppCurrency.format(offer)})';
        } else {
          return '-${AppCurrency.format(val)} OFF$presTag (${AppCurrency.format(offer)})';
        }
      }

      if (!oldHasOffer && newHasOffer) {
        // 1. DESCUENTO_ACTIVADO
        String valNuevo = (newType == 'porcentaje')
            ? 'Oferta activada$presTag: ${newVal.toStringAsFixed(newVal.truncateToDouble() == newVal ? 0 : 1)}% OFF → Precio Oferta: ${AppCurrency.format(newOffer)}'
            : 'Oferta activada$presTag: -${AppCurrency.format(newVal)} OFF → Precio Oferta: ${AppCurrency.format(newOffer)}';

        await txn.insert('product_history', {
          'entidad_tipo': 'PRESENTACION',
          'entidad_id': id,
          'campo_modificado': 'descuento',
          'valor_anterior': 'Sin descuento',
          'valor_nuevo': valNuevo,
          'fecha_cambio': DateTime.now().toIso8601String(),
        });
      } else if (oldHasOffer && !newHasOffer) {
        // 2. DESCUENTO_ELIMINADO
        String valAnt = formatOfferLabel(oldType, oldVal, oldOffer);
        String valNuevo =
            'Oferta finalizada$presTag → Regresa a precio normal: ${AppCurrency.format(newPrice)}';

        await txn.insert('product_history', {
          'entidad_tipo': 'PRESENTACION',
          'entidad_id': id,
          'campo_modificado': 'descuento',
          'valor_anterior': valAnt,
          'valor_nuevo': valNuevo,
          'fecha_cambio': DateTime.now().toIso8601String(),
        });
      } else if (oldHasOffer && newHasOffer) {
        // 3. DESCUENTO_MODIFICADO
        bool diffOffer = (oldOffer - newOffer).abs() > 0.005;
        bool diffType = oldType != newType;
        bool diffVal = (oldVal - newVal).abs() > 0.005;

        if (diffOffer || diffType || diffVal) {
          String valAnt = formatOfferLabel(oldType, oldVal, oldOffer);
          String valNuevo = formatOfferLabel(newType, newVal, newOffer);

          await txn.insert('product_history', {
            'entidad_tipo': 'PRESENTACION',
            'entidad_id': id,
            'campo_modificado': 'descuento',
            'valor_anterior': valAnt,
            'valor_nuevo': valNuevo,
            'fecha_cambio': DateTime.now().toIso8601String(),
          });
        }
      }
    }

    return res;
  }

  /// Realiza el corte atómico diferido de una variante en SQLite:
  /// Desactiva la variante origen (soft-delete), libera el código de barras si se transfirió,
  /// descuenta el stock del pool compartido si correspondía,
  /// registra la salida en stock_ledger si hubo stock trasladado,
  /// y promueve la siguiente variante a principal si la original era default.
  Future<void> cutVariantFromProductTransaction({
    required int presentationId,
    required int originProductId,
    int? promoteToDefaultPresentationId,
    String? transferredBarcode,
    int transferredStock = 0,
    int transferredBaseUnits = 0,
    bool isSharedVariant = false,
    bool shouldDeductSharedPool = true,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // 1. Obtener datos de la presentación a cortar
      final presRows = await txn.query(
        'presentaciones_producto',
        where: 'id = ?',
        whereArgs: [presentationId],
        limit: 1,
      );
      if (presRows.isEmpty) return;
      final pres = presRows.first;

      // Obtener datos del producto origen (negocio_id y stock_compartido)
      final prodRows = await txn.query(
        'productos',
        columns: ['negocio_id', 'stock_compartido', 'modo_stock'],
        where: 'id = ?',
        whereArgs: [originProductId],
        limit: 1,
      );
      final int negocioId = prodRows.isNotEmpty
          ? (prodRows.first['negocio_id'] as num?)?.toInt() ?? 1
          : 1;

      final bool isShared = isSharedVariant ||
          (pres['usa_stock_compartido'] == 1) ||
          (prodRows.isNotEmpty &&
              prodRows.first['modo_stock']?.toString() == 'COMPARTIDO');

      final int unitsToDeduct =
          transferredBaseUnits > 0 ? transferredBaseUnits : transferredStock;

      // 2. Registrar salida en stock_ledger si se trasladó stock
      if (unitsToDeduct > 0) {
        final double cost =
            (pres['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0;
        final double price =
            (pres['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        await txn.insert('stock_ledger', {
          'presentation_id': presentationId,
          'negocio_id': negocioId,
          'tipo_transaccion': 'TRANSFERENCIA_EXTRACCIÓN',
          'cantidad': -unitsToDeduct,
          'costo_unitario': cost,
          'precio_venta': price,
          'fecha_registro': DateTime.now().toIso8601String(),
        });
      }

      // 2.1. Descuento atómico del pool de stock compartido si corresponde
      if (isShared && shouldDeductSharedPool && unitsToDeduct > 0) {
        final int currentPool = prodRows.isNotEmpty
            ? (prodRows.first['stock_compartido'] as num?)?.toInt() ?? 0
            : 0;
        final int newPool =
            (currentPool - unitsToDeduct) > 0 ? (currentPool - unitsToDeduct) : 0;

        await txn.update(
          'productos',
          {'stock_compartido': newPool},
          where: 'id = ?',
          whereArgs: [originProductId],
        );

        await txn.rawUpdate(
          'UPDATE presentaciones_producto SET stock_actual = ? WHERE producto_id = ? AND usa_stock_compartido = 1 AND id != ?',
          [newPool, originProductId, presentationId],
        );
      }

      // 3. Desactivar variante origen y liberar código de barras si se transfirió
      final Map<String, dynamic> updateValues = {
        'activo': 0,
        'es_default': 0,
        'stock_actual': 0,
      };
      if (transferredBarcode != null && transferredBarcode.isNotEmpty) {
        updateValues['codigo_barras'] = null;
      }
      await txn.update(
        'presentaciones_producto',
        updateValues,
        where: 'id = ?',
        whereArgs: [presentationId],
      );

      // 4. Promover la siguiente variante a principal si aplica
      if (promoteToDefaultPresentationId != null &&
          promoteToDefaultPresentationId > 0) {
        await txn.update(
          'presentaciones_producto',
          {'es_default': 1},
          where: 'id = ?',
          whereArgs: [promoteToDefaultPresentationId],
        );
      }
    });
  }
}
