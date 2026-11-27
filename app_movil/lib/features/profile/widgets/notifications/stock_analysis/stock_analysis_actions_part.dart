part of '../stock_analysis_modal.dart';

extension _StockAnalysisActionsExt on _StockAnalysisModalState {
  Future<void> _loadLedger() async {
    if (mounted && !_isLoadingLedger) {
      _updateState(() => _isLoadingLedger = true);
    }
    try {
      final db = await LocalDatabase.instance.database;
      final presId = _selectedPres?.id;

      final List<Map<String, dynamic>> rows;
      if (presId != null) {
        rows = await db.rawQuery(
          '''
          SELECT sl.*, pp.nombre_especifico as pres_nombre
          FROM stock_ledger sl
          LEFT JOIN presentaciones_producto pp ON sl.presentation_id = pp.id
          WHERE pp.producto_id = ?
          ORDER BY sl.id DESC LIMIT 30
        ''',
          [_product.id],
        );
      } else {
        rows = [];
      }

      if (mounted) {
        _updateState(() {
          _ledgerMovements = rows;
          _isLoadingLedger = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading ledger in StockAnalysisModal: $e");
      if (mounted) {
        _updateState(() => _isLoadingLedger = false);
      }
    }
  }

  Future<void> _applyQuickRestock(int qtyToAdd) async {
    if (qtyToAdd <= 0 || _isSavingStock) {
      return;
    }
    _updateState(() => _isSavingStock = true);
    HapticFeedback.mediumImpact();

    try {
      final db = await LocalDatabase.instance.database;
      final pres = _selectedPres;
      if (pres == null) {
        return;
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final bool isShared = _isShared;
      final int oldStock = _currentStock;
      final int newStock = oldStock + qtyToAdd;

      await db.transaction((txn) async {
        if (isShared) {
          await txn.rawUpdate(
            '''
            UPDATE productos 
            SET stock_compartido = ?, fecha_actualizacion = ?
            WHERE id = ?
          ''',
            [newStock, nowIso, _product.id],
          );
        } else {
          await txn.rawUpdate(
            '''
            UPDATE presentaciones_producto
            SET stock_actual = ?
            WHERE id = ?
          ''',
            [newStock, pres.id],
          );
        }

        final prodRows = await txn.rawQuery(
          'SELECT negocio_id FROM productos WHERE id = ?',
          [_product.id],
        );
        final int negocioId = prodRows.isNotEmpty
            ? (prodRows.first['negocio_id'] as int? ?? 1)
            : 1;

        await txn.insert('stock_ledger', {
          'presentation_id': pres.id,
          'negocio_id': negocioId,
          'tipo_transaccion': 'INGRESO',
          'cantidad': qtyToAdd,
          'costo_unitario': pres.costoUnitarioCalculado,
          'precio_venta': pres.precioVentaFinal,
          'origen_id': null,
          'fecha_registro': nowIso,
        });
      });

      if (!mounted) {
        return;
      }
      final invProv = Provider.of<InventoryProvider>(context, listen: false);
      try {
        await invProv.loadInventory(reset: true);
      } catch (_) {}
      final updatedProd = await invProv.getFullProductWithFallback(_product.id);
      if (updatedProd != null) {
        _product = updatedProd;
      }

      if (!mounted) {
        return;
      }
      final notifProv = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      if (newStock > _currentThreshold) {
        await notifProv.resolveProductStockNotification(_product.id);
      }
      await notifProv.fetchNotifications();

      if (!mounted) {
        return;
      }
      NotificationToastFeedback.show(
        context: context,
        message: "Se sumaron +$qtyToAdd und. al inventario correctamente",
        icon: Icons.check_circle_rounded,
        accentColor: Colors.green,
      );

      await _loadLedger();
    } catch (e) {
      debugPrint("Error in quick restock: $e");
      if (mounted) {
        NotificationToastFeedback.show(
          context: context,
          message: "No se pudo actualizar el stock: $e",
          icon: Icons.error_outline_rounded,
          accentColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        _updateState(() => _isSavingStock = false);
      }
    }
  }

  Future<void> _updateThreshold(int newThreshold) async {
    if (newThreshold < 1 || newThreshold == _currentThreshold) {
      return;
    }
    HapticFeedback.lightImpact();

    try {
      final db = await LocalDatabase.instance.database;
      final pres = _selectedPres;
      if (pres == null) {
        return;
      }

      await db.update(
        'presentaciones_producto',
        {'stock_alerta': newThreshold},
        where: 'id = ?',
        whereArgs: [pres.id],
      );

      if (mounted) {
        _updateState(() => _currentThreshold = newThreshold);
      }

      if (!mounted) {
        return;
      }
      try {
        final invProv = Provider.of<InventoryProvider>(context, listen: false);
        await invProv.loadInventory(reset: true);
      } catch (_) {}

      if (!mounted) {
        return;
      }
      final notifProv = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      if (_currentStock > newThreshold) {
        await notifProv.resolveProductStockNotification(_product.id);
      }
      await notifProv.fetchNotifications();

      if (!mounted) {
        return;
      }
      NotificationToastFeedback.show(
        context: context,
        message: "Umbral mínimo actualizado a $newThreshold und.",
        icon: Icons.tune_rounded,
        accentColor: Colors.blue,
      );
    } catch (e) {
      debugPrint("Error updating threshold: $e");
    }
  }
}
