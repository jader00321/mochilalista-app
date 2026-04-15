import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../config/api_constants.dart';
import '../services/sales_service.dart';
import '../services/quotation_service.dart';
import '../services/client_service.dart';
import '../models/smart_quotation_model.dart';
import '../models/crm_models.dart';

class SaleProvider with ChangeNotifier {
  String? _authToken;
  
  Function()? onAuthRevoked;

  final SalesService _salesService = SalesService();
  final QuotationService _quotationService = QuotationService();
  final ClientService _clientService = ClientService();

  bool _isLoading = false;
  String _errorMessage = "";
  List<SaleModel> _salesHistory = [];

  bool _isLoadingMore = false;
  int _currentSkip = 0;
  final int _limit = 20;
  bool _hasMoreData = true;
  SalesStatsModel? _currentStats;

  String? _currentStartDate;
  String? _currentEndDate;
  String _activeQuickFilter = "este_mes"; 
  String _currentSortBy = "fecha_venta";
  String _currentOrder = "desc";
  String _searchQuery = "";
  String _currentTab = "todas"; 

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<SaleModel> get salesHistory => _salesHistory;

  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  SalesStatsModel? get currentStats => _currentStats;
  String get activeQuickFilter => _activeQuickFilter;
  String get currentTab => _currentTab;
  String get currentSortBy => _currentSortBy;
  String get currentOrder => _currentOrder;
  String get searchQuery => _searchQuery; 

  double get todaySalesTotal {
    if (_salesHistory.isEmpty) return 0.0;
    final today = DateTime.now();
    double sum = 0.0;
    for (var sale in _salesHistory) {
      try {
        final saleDate = DateTime.parse(sale.saleDate);
        if (saleDate.year == today.year && saleDate.month == today.month && saleDate.day == today.day) {
          sum += sale.totalAmount;
        }
      } catch (e) { continue; }
    }
    return sum;
  }

  void updateToken(String? token) {
    _authToken = token;
  }

  void _handleException(dynamic e) {
    if (e.toString().contains("AUTH_REVOKED")) {
      _errorMessage = "Tu acceso a este negocio ha sido revocado.";
      if (onAuthRevoked != null) onAuthRevoked!();
    } else {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
    }
  }

  Future<bool> updateFullClient(int clientId, Map<String, dynamic> clientData) async {
    if (_authToken == null) return false;
    try {
      await _clientService.updateClient(clientId, clientData, _authToken!);
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateClientNote(int clientId, String newNote) async {
    if (_authToken == null) return false;
    try {
      await _clientService.updateClient(clientId, {'notas': newNote}, _authToken!);
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateQuotationNote(int quotationId, String newNote) async {
    if (_authToken == null) return false;
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/smart-quotations/$quotationId');
      final response = await http.patch(
        url,
        headers: {'Authorization': 'Bearer $_authToken', 'Content-Type': 'application/json'},
        body: json.encode({"notas": newNote}),
      );
      if (response.statusCode == 401 || response.statusCode == 403) throw Exception("AUTH_REVOKED");
      return response.statusCode == 200;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<SmartQuotationModel?> prepareForSale(SmartQuotationModel current, int? newClientId) async {
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      bool mustClone = current.isTemplate || (current.clientId != null && current.clientId != newClientId); 
      if (mustClone) {
        return await _quotationService.cloneQuotation(current.id, _authToken!, targetClientId: newClientId);
      } else {
        return current;
      }
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🔥 MODIFICADO: Retorna un String? (null = Éxito, String = Mensaje de Error Exacto)
  Future<String?> processCheckout({
    required int quotationId,
    required int? clientId, 
    String? clientName,     
    String? saleNote,       
    required String paymentMethod,
    required String paymentStatus,
    required String deliveryStatus,
    String? deliveryDate, 
    required double total,
    required double paid,
    double discount = 0.0,
    List<InstallmentModel>? installments,
    String origenVenta = "smart_quotation",
    List<Map<String, dynamic>>? detalleVenta,
  }) async {
    if (_authToken == null) return "Error: Sesión no válida.";
    _isLoading = true;
    notifyListeners();

    final saleData = {
      "cotizacion_id": origenVenta == "pos_rapido" ? null : quotationId, 
      "cliente_id": clientId,
      "client_name_override": clientName, 
      "notas": saleNote, 
      "origen_venta": origenVenta,
      "metodo_pago": paymentMethod,
      "estado_pago": paymentStatus,
      "estado_entrega": deliveryStatus,
      "fecha_entrega": deliveryDate, 
      "monto_total": total,
      "monto_pagado": paid,
      "descuento_aplicado": discount,
      "cuotas": installments?.map((e) => e.toJson()).toList() ?? [],
      "detalle_venta": detalleVenta ?? []
    };

    try {
      await _salesService.createSale(saleData, _authToken!);
      await loadFilteredHistory(reset: true); 
      return null; // Null significa SIN ERRORES (Éxito)
    } catch (e) {
      _handleException(e);
      return _errorMessage; // Devolvemos el error extraído para la UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClientModel?> getClientById(int id) async {
    if (_authToken == null) return null;
    try {
        return await _clientService.getClientById(id, _authToken!);
    } catch (e) {
        _handleException(e);
        return null;
    }
  }

  Future<List<ClientModel>> searchClients(String query) async {
    if (_authToken == null || query.isEmpty) return [];
    try {
        return await _clientService.searchClients(query, _authToken!);
    } catch (e) {
        _handleException(e);
        return [];
    }
  }

  Future<ClientModel?> registerClient(Map<String, dynamic> data) async {
    if (_authToken == null) return null;
    try {
      return await _clientService.createClient(data, _authToken!);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async {
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final detail = await _salesService.getSaleDetail(_authToken!, saleId);
      
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
           detail['cliente_notas'] = clientData.notes;
        }
      }
      
      return detail;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSalesHistory() async {
    await loadFilteredHistory(reset: true);
  }

  Future<void> loadFilteredHistory({bool reset = false}) async {
    if (_authToken == null) return;
    
    if (reset) {
      _isLoading = true;
      _currentSkip = 0;
      _salesHistory = [];
      _hasMoreData = true;
      notifyListeners();
      _loadDynamicStats();
    } else {
      if (_isLoadingMore || !_hasMoreData) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      final newSales = await _salesService.getHistory(
        _authToken!,
        skip: _currentSkip,
        limit: _limit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: origen,
        sortBy: _currentSortBy,
        order: _currentOrder,
      );

      if (newSales.length < _limit) _hasMoreData = false;

      if (reset) {
        _salesHistory = newSales;
      } else {
        _salesHistory.addAll(newSales);
      }
      
      _currentSkip += newSales.length;

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadDynamicStats() async {
    if (_authToken == null) return;
    try {
      bool isArchivedTab = _currentTab == "archivadas";
      String? origen = (_currentTab == "todas" || _currentTab == "archivadas") ? null : _currentTab;

      _currentStats = await _salesService.getStats(
        _authToken!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: origen,
      );
      notifyListeners(); 
    } catch (e) {
      _handleException(e);
    }
  }

  Future<bool> updateDeliveryStatus(int saleId, String newStatus) async {
    if (_authToken == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _salesService.updateDeliveryStatus(_authToken!, saleId, newStatus);
      return true; 
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setQuickFilter(String filterType, {DateTime? customStart, DateTime? customEnd}) {
    _activeQuickFilter = filterType;
    final now = DateTime.now();
    String? startStr;
    String? endStr;

    switch (filterType) {
      case 'hoy':
        startStr = DateTime(now.year, now.month, now.day).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'semana':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startStr = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'este_mes':
        startStr = DateTime(now.year, now.month, 1).toIso8601String();
        endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
        break;
      case 'personalizado':
        if (customStart != null && customEnd != null) {
          startStr = customStart.toIso8601String();
          endStr = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59).toIso8601String();
        }
        break;
      case 'todas':
      default:
        startStr = null;
        endStr = null;
        break;
    }

    _currentStartDate = startStr;
    _currentEndDate = endStr;
    loadFilteredHistory(reset: true);
  }

  void setSort(String sortBy, String order) {
    if (_currentSortBy == sortBy && _currentOrder == order) return;
    _currentSortBy = sortBy;
    _currentOrder = order;
    loadFilteredHistory(reset: true);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    loadFilteredHistory(reset: true);
  }

  void setTab(String tabKey) {
    if (_currentTab == tabKey) return;
    _currentTab = tabKey;
    loadFilteredHistory(reset: true);
  }

  Future<void> toggleArchiveSale(int saleId) async {
    if (_authToken == null) return;
    try {
      await _salesService.toggleArchive(_authToken!, saleId);
      _salesHistory.removeWhere((element) => element.id == saleId);
      notifyListeners();
      _loadDynamicStats();
    } catch (e) {
      _handleException(e);
      notifyListeners();
    }
  }

  String generateCsvData() {
    if (_salesHistory.isEmpty) return "";
    String csv = "ID Venta,Fecha,Metodo Pago,Estado Pago,Estado Entrega,Total(S/),Pagado(S/),Descuento(S/)\n";
    for (var sale in _salesHistory) {
      final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.saleDate));
      csv += "${sale.id},$dateFormatted,${sale.paymentMethod},${sale.paymentStatus},${sale.deliveryStatus},${sale.totalAmount},${sale.paidAmount},${sale.discount}\n";
    }
    return csv;
  }

  Future<Map<String, dynamic>?> getSaleDetailSilently(int saleId) async {
    if (_authToken == null) return null;
    try {
      final detail = await _salesService.getSaleDetail(_authToken!, saleId);
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
           detail['cliente_notas'] = clientData.notes;
        }
      }
      return detail;
    } catch (e) {
      return null;
    }
  }
}