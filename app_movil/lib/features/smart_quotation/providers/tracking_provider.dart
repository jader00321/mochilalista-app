import 'package:flutter/material.dart';
import '../services/client_service.dart';
import '../models/crm_models.dart';
import '../models/smart_quotation_model.dart'; 

class TrackingProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;
  
  final ClientService _service = ClientService();

  // --- ESTADO GENERAL ---
  List<ClientModel> _allClients = [];
  bool _isLoading = false;
  String _errorMessage = "";

  // --- ESTADO DE FILTROS Y ORDENAMIENTO ---
  String _searchQuery = "";
  bool _filterHasDebt = false;
  bool _filterPendingDelivery = false;
  String _filterConfidenceLevel = "todos"; 
  String _currentSort = "name_asc";
  bool _filterIsAppClient = false; 

  // --- ESTADO DEL DETALLE DEL CLIENTE ---
  List<LedgerItem> _currentClientLedger = [];
  bool _isLoadingLedger = false;

  List<SaleModel> _currentClientDebts = [];
  bool _isLoadingDebts = false;

  List<SmartQuotationModel> _currentClientQuotations = [];
  bool _isLoadingQuotations = false;

  // --- GETTERS ---
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get filterHasDebt => _filterHasDebt;
  bool get filterPendingDelivery => _filterPendingDelivery;
  String get filterConfidenceLevel => _filterConfidenceLevel;
  String get currentSort => _currentSort;
  bool get filterIsAppClient => _filterIsAppClient; 
  List<LedgerItem> get currentClientLedger => _currentClientLedger;
  bool get isLoadingLedger => _isLoadingLedger;
  List<SaleModel> get currentClientDebts => _currentClientDebts;
  bool get isLoadingDebts => _isLoadingDebts;
  List<SmartQuotationModel> get currentClientQuotations => _currentClientQuotations;
  bool get isLoadingQuotations => _isLoadingQuotations;

  // 🔥 RECIBE EL CONTEXTO MULTI-PERFIL
  void updateContext(int? negocioId, int? usuarioId) {
    _negocioId = negocioId;
    _usuarioId = usuarioId;
  }

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  Future<ClientModel?> getClientById(int clientId) async {
    if (_negocioId == null) return null;
    try {
      return await _service.getClientById(clientId);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<void> loadClients() async {
    if (_negocioId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _allClients = await _service.getTrackingClients(_negocioId!);
    } catch (e) {
      _handleException(e);
    } finally {
      // 🔥 Aseguramos apagar el loader siempre
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadClientsByPriority() async {
    await loadClients();
  }

  List<ClientModel> get filteredClients {
    List<ClientModel> list = _allClients.where((c) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = c.fullName.toLowerCase().contains(query);
        final matchPhone = c.phone.contains(query);
        final matchDni = c.docNumber?.contains(query) ?? false;
        if (!matchName && !matchPhone && !matchDni) return false;
      }
      if (_filterHasDebt && c.totalDebt <= 0) return false;
      if (_filterPendingDelivery && c.pendingDeliveryCount <= 0) return false;
      if (_filterConfidenceLevel != "todos" && c.nivelConfianza.toLowerCase() != _filterConfidenceLevel) return false;
      if (_filterIsAppClient && c.usuarioVinculadoId == null) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      if (_currentSort == 'name_asc') {
        return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      } else if (_currentSort == 'newest') {
        DateTime dateA = DateTime.tryParse(a.registeredDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.tryParse(b.registeredDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA); 
      } else if (_currentSort == 'oldest') {
        DateTime dateA = DateTime.tryParse(a.registeredDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.tryParse(b.registeredDate) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB); 
      }
      return 0;
    });

    return list;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleDebtFilter() {
    _filterHasDebt = !_filterHasDebt;
    notifyListeners();
  }

  void toggleDeliveryFilter() {
    _filterPendingDelivery = !_filterPendingDelivery;
    notifyListeners();
  }

  void setConfidenceFilter(String level) {
    _filterConfidenceLevel = level;
    notifyListeners();
  }

  void setSort(String sortType) {
    _currentSort = sortType;
    notifyListeners();
  }
  
  void toggleAppClientFilter() {
    _filterIsAppClient = !_filterIsAppClient;
    notifyListeners();
  }

  Future<ClientModel?> createClient(Map<String, dynamic> data) async {
    if (_negocioId == null || _usuarioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final newClient = await _service.createClient(data, _negocioId!, _usuarioId!);
      await loadClients(); 
      return newClient;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClientModel?> updateClientProfile(int clientId, Map<String, dynamic> data) async {
    if (_negocioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedClient = await _service.updateClient(clientId, data);
      await loadClients(); 
      return updatedClient;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadClientLedger(int clientId) async {
    if (_negocioId == null) return;
    _isLoadingLedger = true;
    notifyListeners();
    try {
      _currentClientLedger = await _service.getClientLedger(clientId);
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingLedger = false; 
      notifyListeners(); 
    }
  }

  Future<void> loadClientDebts(int clientId) async {
    if (_negocioId == null) return;
    _isLoadingDebts = true;
    notifyListeners();
    try {
      _currentClientDebts = await _service.getClientDebts(clientId);
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingDebts = false; 
      notifyListeners(); 
    }
  }

  Future<void> loadClientQuotations(int clientId) async {
    if (_negocioId == null) return;
    _isLoadingQuotations = true;
    notifyListeners();
    try {
      _currentClientQuotations = await _service.getPendingQuotations(clientId);
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingQuotations = false; 
      notifyListeners(); 
    }
  }

  Future<bool> registerPayment(int clientId, double amount, String method, {int? ventaId, int? cuotaId, bool guardarVuelto = false}) async {
    if (_negocioId == null || _usuarioId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _service.registerPayment(clientId, amount, method, _negocioId!, _usuarioId!, ventaId: ventaId, cuotaId: cuotaId, guardarVuelto: guardarVuelto);
      await loadClients();
      await loadClientLedger(clientId); 
      await loadClientDebts(clientId);  
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}