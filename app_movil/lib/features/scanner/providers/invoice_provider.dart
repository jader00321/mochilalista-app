import 'package:flutter/material.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';

class InvoiceProvider with ChangeNotifier {
  int? _negocioId;
  bool _isLoading = false;
  String _errorMessage = "";

  final dbHelper = LocalDatabase.instance;

  List<InvoiceModel> _invoices = [];
  bool _hasMoreData = true;
  int _currentSkip = 0;
  final int _limit = 50;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<InvoiceModel> get invoices => _invoices;
  bool get hasMoreData => _hasMoreData;

  void updateContext(int? negocioId) {
    _negocioId = negocioId;
  }

  Future<void> fetchInvoices({bool reset = false}) async {
    if (_negocioId == null) {
      // Retry once after a small delay for ProxyProvider initialization
      await Future.delayed(const Duration(milliseconds: 500));
      if (_negocioId == null) return;
    }

    if (reset) {
      _isLoading = true;
      _currentSkip = 0;
      _invoices = [];
      _hasMoreData = true;
      _errorMessage = "";
      notifyListeners();
    } else {
      if (_isLoading || !_hasMoreData) return;
      _isLoading = true;
      notifyListeners();
    }

    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> rows = await db.query(
        'facturas_carga',
        where: 'negocio_id = ?',
        whereArgs: [_negocioId],
        limit: _limit,
        offset: _currentSkip,
        orderBy: 'fecha_carga DESC',
      );

      final List<InvoiceModel> newInvoices = rows
          .map((json) => InvoiceModel.fromJson(json))
          .toList();

      if (newInvoices.length < _limit) {
        _hasMoreData = false;
      }

      if (reset) {
        _invoices = newInvoices;
      } else {
        _invoices.addAll(newInvoices);
      }

      _currentSkip += newInvoices.length;
    } catch (e) {
      _errorMessage = "Error cargando facturas: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> getInvoiceDetail(int invoiceId) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> rows = await db.query(
        'facturas_carga',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return InvoiceModel.fromJson(rows.first);
      }
    } catch (e) {
      debugPrint("Error obteniendo detalle de factura: $e");
    }
    return null;
  }

  Future<bool> updateInvoice(
    int invoiceId, {
    String? estado,
    int? proveedorId,
    String? imagenUrl,
  }) async {
    try {
      final db = await dbHelper.database;
      final Map<String, dynamic> body = {};

      if (estado != null) body['estado'] = estado;
      if (proveedorId != null) body['proveedor_id'] = proveedorId;
      if (imagenUrl != null) body['imagen_url'] = imagenUrl;

      int rowsUpdated = await db.update(
        'facturas_carga',
        body,
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (rowsUpdated > 0) {
        final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
        if (index != -1) {
          final updatedRow = await db.query(
            'facturas_carga',
            where: 'id = ?',
            whereArgs: [invoiceId],
          );
          _invoices[index] = InvoiceModel.fromJson(updatedRow.first);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error actualizando factura localmente: $e");
    }
    return false;
  }

  // =========================================================================
  // 🔧 TAREA 1.4: Consultar presentaciones vinculadas a una factura
  // Para facturas manuales que no tienen datos_crudos_ia_json,
  // mostramos los productos que se vincularon manualmente via factura_carga_id
  // =========================================================================
  
  /// Obtiene las presentaciones vinculadas a una factura por factura_carga_id
  /// Incluye información del producto padre para mostrar en la UI
  Future<List<Map<String, dynamic>>> getLinkedPresentations(int invoiceId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT 
          pp.id AS presentacion_id,
          pp.nombre AS presentacion_nombre,
          pp.precio_costo,
          pp.precio_venta,
          pp.cantidad_stock,
          pp.unidad_medida,
          pp.contenido,
          p.nombre AS producto_nombre,
          p.imagen_url AS producto_imagen
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE pp.factura_carga_id = ?
        ORDER BY p.nombre ASC, pp.nombre ASC
      ''', [invoiceId]);
      return rows;
    } catch (e) {
      debugPrint("Error obteniendo presentaciones vinculadas: $e");
      return [];
    }
  }

  /// Obtiene el conteo de presentaciones vinculadas a una factura
  Future<int> getLinkedPresentationsCount(int invoiceId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM presentaciones_producto WHERE factura_carga_id = ?',
        [invoiceId],
      );
      return result.first['total'] as int? ?? 0;
    } catch (e) {
      debugPrint("Error contando presentaciones vinculadas: $e");
      return 0;
    }
  }
}
