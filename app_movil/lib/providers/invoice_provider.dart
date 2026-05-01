import 'package:flutter/material.dart';
import '../database/local_db.dart';
import '../models/invoice_model.dart';

class InvoiceProvider with ChangeNotifier {
  int? _negocioId;
  bool _isLoading = false;
  String _errorMessage = "";
  
  final dbHelper = LocalDatabase.instance;

  List<InvoiceModel> _invoices = [];
  bool _hasMoreData = true;
  int _currentSkip = 0;
  final int _limit = 20;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<InvoiceModel> get invoices => _invoices;
  bool get hasMoreData => _hasMoreData;

  void updateContext(int? negocioId) {
    _negocioId = negocioId;
  }

  Future<void> fetchInvoices({bool reset = false}) async {
    if (_negocioId == null) return;

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
        orderBy: 'fecha_carga DESC'
      );

      final List<InvoiceModel> newInvoices = rows.map((json) => InvoiceModel.fromJson(json)).toList();

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
        limit: 1
      );

      if (rows.isNotEmpty) {
        return InvoiceModel.fromJson(rows.first);
      }
    } catch (e) {
      debugPrint("Error obteniendo detalle de factura: $e");
    }
    return null;
  }

  Future<bool> updateInvoice(int invoiceId, {String? estado, int? proveedorId, String? imagenUrl}) async {
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
        whereArgs: [invoiceId]
      );

      if (rowsUpdated > 0) {
        final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
        if (index != -1) {
          final updatedRow = await db.query('facturas_carga', where: 'id = ?', whereArgs: [invoiceId]);
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
}