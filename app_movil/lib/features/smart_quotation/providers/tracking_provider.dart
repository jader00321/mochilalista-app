import 'package:flutter/material.dart';
import '../services/client_service.dart';
import '../models/crm_models.dart';
import '../models/smart_quotation_model.dart'; // 🔥 Importado para tipar las cotizaciones

class TrackingProvider with ChangeNotifier {
  String? _authToken;
  final ClientService _service = ClientService();

  Function()? onAuthRevoked;

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

  // 🔥 FASE 5: Ahora está fuertemente tipado para evitar errores de renderizado
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

  // 🔥 NUEVO: Trae un perfil fresco desde el backend sin depender de la lista local
  Future<ClientModel?> getClientById(int clientId) async {
    if (_authToken == null) return null;
    try {
      return await _service.getClientById(clientId, _authToken!);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<void> loadClients() async {
    if (_authToken == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      _allClients = await _service.getTrackingClients(_authToken!);
    } catch (e) {
      _handleException(e);
    } finally {
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
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final newClient = await _service.createClient(data, _authToken!);
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
    if (_authToken == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final updatedClient = await _service.updateClient(clientId, data, _authToken!);
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
    if (_authToken == null) return;
    _isLoadingLedger = true;
    notifyListeners();
    try {
      _currentClientLedger = await _service.getClientLedger(clientId, _authToken!);
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingLedger = false; notifyListeners(); 
    }
  }

  Future<void> loadClientDebts(int clientId) async {
    if (_authToken == null) return;
    _isLoadingDebts = true;
    notifyListeners();
    try {
      _currentClientDebts = await _service.getClientDebts(clientId, _authToken!);
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingDebts = false; notifyListeners(); 
    }
  }

  Future<void> loadClientQuotations(int clientId) async {
    if (_authToken == null) return;
    _isLoadingQuotations = true;
    notifyListeners();
    try {
      final rawList = await _service.getPendingQuotations(clientId, _authToken!);
      _currentClientQuotations = rawList.map((e) => SmartQuotationModel.fromJson(e)).toList();
    } catch (e) {
       _handleException(e);
    } finally { 
      _isLoadingQuotations = false; notifyListeners(); 
    }
  }

  Future<bool> registerPayment(int clientId, double amount, String method, {int? ventaId, int? cuotaId, bool guardarVuelto = false}) async {
    if (_authToken == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _service.registerPayment(clientId, amount, method, _authToken!, ventaId: ventaId, cuotaId: cuotaId, guardarVuelto: guardarVuelto);
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