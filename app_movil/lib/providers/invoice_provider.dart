import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_constants.dart';
import '../models/invoice_model.dart';

class InvoiceProvider with ChangeNotifier {
  String? _authToken;
  bool _isLoading = false;
  String _errorMessage = "";
  
  List<InvoiceModel> _invoices = [];
  bool _hasMoreData = true;
  int _currentSkip = 0;
  final int _limit = 20;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<InvoiceModel> get invoices => _invoices;
  bool get hasMoreData => _hasMoreData;

  void updateToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
  };

  Future<void> fetchInvoices({bool reset = false}) async {
    if (_authToken == null) return;

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
      final url = Uri.parse('${ApiConstants.baseUrl}/invoices/?skip=$_currentSkip&limit=$_limit');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<InvoiceModel> newInvoices = data.map((json) => InvoiceModel.fromJson(json)).toList();

        if (newInvoices.length < _limit) {
          _hasMoreData = false;
        }

        if (reset) {
          _invoices = newInvoices;
        } else {
          _invoices.addAll(newInvoices);
        }
        
        _currentSkip += newInvoices.length;
      } else if (response.statusCode == 403) {
         _errorMessage = "Requiere seleccionar un negocio primero.";
      } else {
        _errorMessage = "Error al cargar facturas: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Error de conexión: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<InvoiceModel?> getInvoiceDetail(int invoiceId) async {
    if (_authToken == null) return null;

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/invoices/$invoiceId');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return InvoiceModel.fromJson(data);
      }
    } catch (e) {
      debugPrint("Error obteniendo detalle de factura: $e");
    }
    return null;
  }

  Future<bool> updateInvoice(int invoiceId, {String? estado, int? proveedorId, String? imagenUrl}) async {
    if (_authToken == null) return false;

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/invoices/$invoiceId');
      final Map<String, dynamic> body = {};
      
      if (estado != null) body['estado'] = estado;
      if (proveedorId != null) body['proveedor_id'] = proveedorId;
      if (imagenUrl != null) body['imagen_url'] = imagenUrl;

      final response = await http.patch(
        url, 
        headers: _headers, 
        body: json.encode(body)
      );

      if (response.statusCode == 200) {
        final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
        if (index != -1) {
          final updatedData = json.decode(utf8.decode(response.bodyBytes));
          _invoices[index] = InvoiceModel.fromJson(updatedData);
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error actualizando factura: $e");
    }
    return false;
  }
}