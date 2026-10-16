import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart'; 
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart'; 
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/ai_extraction_service.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/database/local_db.dart';

class SmartQuotationState {
  File? currentImage;
  ExtractedMetadata? metadata;
  List<ExtractedItem> items = [];

  List<MatchedProduct>? draftManualItems;
  Map<int, int>? draftManualQuantities;
  Map<int, double>? draftManualPrices;
  Map<int, String>? draftManualNames;
  
  ClientModel? draftClient;
  
  String? draftClientName;
  String? draftClientPhone;
  String? draftClientDni;
  String? draftClientAddress;
  String? draftClientEmail;
  String? draftClientNotes;
  
  String? draftQuoteTitle;  
  String? draftQuoteNotes;  
  String? draftSchool;
  String? draftGrade;
  
  int? draftQuotationId; 
}

class SmartQuotationProvider with ChangeNotifier {
  String? _aiToken; 
  int? _negocioId;

  final AIExtractionService _service = AIExtractionService();
  final ClientService _clientService = ClientService(); 
  final dbHelper = LocalDatabase.instance;
  
  bool _isLoading = false;
  String _errorMessage = '';

  final Map<int, SmartQuotationState> _states = {};

  SmartQuotationState get _currentState {
    final key = _negocioId ?? 0;
    return _states.putIfAbsent(key, () => SmartQuotationState());
  }

  bool get hasManualDraft => _currentState.draftManualItems != null && _currentState.draftManualItems!.isNotEmpty;

  void saveManualDraft({
    required List<MatchedProduct> items, required Map<int, int> quantities, required Map<int, double> prices,
    required Map<int, String> names, ClientModel? client, String? cName, String? cPhone, String? cDni, 
    String? cAddr, String? cEmail, String? cNotes, String? qTitle, String? qNotes, 
    String? school, String? grade, int? quotationId,
  }) {
    _currentState.draftManualItems = List.from(items);
    _currentState.draftManualQuantities = Map.from(quantities);
    _currentState.draftManualPrices = Map.from(prices);
    _currentState.draftManualNames = Map.from(names);
    
    _currentState.draftClient = client;
    _currentState.draftClientName = cName; _currentState.draftClientPhone = cPhone; _currentState.draftClientDni = cDni;
    _currentState.draftClientAddress = cAddr; _currentState.draftClientEmail = cEmail; _currentState.draftClientNotes = cNotes;
    
    _currentState.draftQuoteTitle = qTitle; _currentState.draftQuoteNotes = qNotes; _currentState.draftSchool = school;
    _currentState.draftGrade = grade; _currentState.draftQuotationId = quotationId;
    notifyListeners();
  }

  void clearManualDraft() {
    _currentState.draftManualItems = null; _currentState.draftManualQuantities = null; _currentState.draftManualPrices = null; _currentState.draftManualNames = null;
    _currentState.draftClient = null; _currentState.draftClientName = null; _currentState.draftClientPhone = null; _currentState.draftClientDni = null;
    _currentState.draftClientAddress = null; _currentState.draftClientEmail = null; _currentState.draftClientNotes = null;
    _currentState.draftQuoteTitle = null; _currentState.draftQuoteNotes = null; _currentState.draftSchool = null; _currentState.draftGrade = null; _currentState.draftQuotationId = null;
    notifyListeners();
  }

  /// 🔄 Sincroniza inmediatamente precio y stock de un ítem en el borrador en memoria (0ms)
  void syncItemPriceAndStock(int presentationId, {double? newPrice, int? newStock}) {
    if (_currentState.draftManualItems != null) {
      final index = _currentState.draftManualItems!.indexWhere((p) => p.presentationId == presentationId);
      if (index != -1) {
        final current = _currentState.draftManualItems![index];
        final updated = MatchedProduct(
          productId: current.productId,
          presentationId: current.presentationId,
          fullName: current.fullName,
          productName: current.productName,
          specificName: current.specificName,
          brand: current.brand,
          price: newPrice ?? current.price,
          offerPrice: current.offerPrice,
          stock: newStock ?? current.stock,
          imageUrl: current.imageUrl,
          unit: current.unit,
          conversionFactor: current.conversionFactor,
          bundleId: current.bundleId,
        );
        _currentState.draftManualItems![index] = updated;

        if (newPrice != null && _currentState.draftManualPrices != null) {
          _currentState.draftManualPrices![presentationId] = newPrice;
        }
        notifyListeners();
      }
    }
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  File? get currentImage => _currentState.currentImage;
  ExtractedMetadata? get metadata => _currentState.metadata;
  List<ExtractedItem> get items => _currentState.items;

  // Setters expuestos para compatibilidad con código que escriba variables de cotización directa
  set draftManualItems(List<MatchedProduct>? val) { _currentState.draftManualItems = val; notifyListeners(); }
  List<MatchedProduct>? get draftManualItems => _currentState.draftManualItems;

  set draftManualQuantities(Map<int, int>? val) { _currentState.draftManualQuantities = val; notifyListeners(); }
  Map<int, int>? get draftManualQuantities => _currentState.draftManualQuantities;

  set draftManualPrices(Map<int, double>? val) { _currentState.draftManualPrices = val; notifyListeners(); }
  Map<int, double>? get draftManualPrices => _currentState.draftManualPrices;

  set draftManualNames(Map<int, String>? val) { _currentState.draftManualNames = val; notifyListeners(); }
  Map<int, String>? get draftManualNames => _currentState.draftManualNames;

  set draftClient(ClientModel? val) { _currentState.draftClient = val; notifyListeners(); }
  ClientModel? get draftClient => _currentState.draftClient;

  set draftClientName(String? val) { _currentState.draftClientName = val; notifyListeners(); }
  String? get draftClientName => _currentState.draftClientName;

  set draftClientPhone(String? val) { _currentState.draftClientPhone = val; notifyListeners(); }
  String? get draftClientPhone => _currentState.draftClientPhone;

  set draftClientDni(String? val) { _currentState.draftClientDni = val; notifyListeners(); }
  String? get draftClientDni => _currentState.draftClientDni;

  set draftClientAddress(String? val) { _currentState.draftClientAddress = val; notifyListeners(); }
  String? get draftClientAddress => _currentState.draftClientAddress;

  set draftClientEmail(String? val) { _currentState.draftClientEmail = val; notifyListeners(); }
  String? get draftClientEmail => _currentState.draftClientEmail;

  set draftClientNotes(String? val) { _currentState.draftClientNotes = val; notifyListeners(); }
  String? get draftClientNotes => _currentState.draftClientNotes;

  set draftQuoteTitle(String? val) { _currentState.draftQuoteTitle = val; notifyListeners(); }
  String? get draftQuoteTitle => _currentState.draftQuoteTitle;

  set draftQuoteNotes(String? val) { _currentState.draftQuoteNotes = val; notifyListeners(); }
  String? get draftQuoteNotes => _currentState.draftQuoteNotes;

  set draftSchool(String? val) { _currentState.draftSchool = val; notifyListeners(); }
  String? get draftSchool => _currentState.draftSchool;

  set draftGrade(String? val) { _currentState.draftGrade = val; notifyListeners(); }
  String? get draftGrade => _currentState.draftGrade;

  set draftQuotationId(int? val) { _currentState.draftQuotationId = val; notifyListeners(); }
  int? get draftQuotationId => _currentState.draftQuotationId;


  String get fullExtractedText {
      if (_currentState.items.isEmpty) return "";
      return _currentState.items.map((i) => i.originalText).join("\n");
  }

  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    if (_negocioId != negocioId) {
       _negocioId = negocioId;
       Future.microtask(() {
         notifyListeners(); // Notifica el cambio de estado/perfil
       });
    }
    _aiToken = aiToken;
  }

  void clearState() {
    _currentState.items = []; _currentState.metadata = null; _currentState.currentImage = null; _errorMessage = '';
    notifyListeners();
  }

  Future<bool> analyzeImage(BuildContext context, File image) async {
    final activeState = _currentState;
    Provider.of<MatchingProvider>(context, listen: false).clearState();
    _isLoading = true;
    _errorMessage = '';
    activeState.currentImage = image;
    notifyListeners();

    try {
      final response = await _service.analyzeImage(
        image, 
        _aiToken ?? "",
        onRetrying: (msg) {
          _errorMessage = msg;
          notifyListeners();
        }
      );
      activeState.metadata = response.metadata;
      activeState.items = response.items;
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateItem(int id, {String? fullName, String? brand, int? quantity, String? unit, String? notes}) {
    final index = _currentState.items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _currentState.items[index];
      if (fullName != null) item.fullName = fullName;
      if (brand != null) item.brand = brand;
      if (quantity != null) item.quantity = quantity;
      if (unit != null) item.unit = unit;
      if (notes != null) item.notes = notes;
      notifyListeners();
    }
  }

  void deleteItem(int id) {
    _currentState.items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addItem() {
    int newId = _currentState.items.isNotEmpty ? _currentState.items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1 : 1;
    _currentState.items.add(ExtractedItem(id: newId, originalText: "Agregado manual", fullName: "", quantity: 1, unit: "unidad"));
    notifyListeners();
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _currentState.metadata ??= ExtractedMetadata();
    if (institution != null) _currentState.metadata!.institutionName = institution;
    if (student != null) _currentState.metadata!.studentName = student;
    if (grade != null) _currentState.metadata!.gradeLevel = grade;
    notifyListeners();
  }

  Future<SmartQuotationModel?> getQuotationById(int id) async {
    try {
      final db = await dbHelper.database;
      final qRows = await db.query('smart_quotations', where: 'id = ?', whereArgs: [id], limit: 1);
      if (qRows.isEmpty) return null;
      
      final iRows = await db.query('smart_quotation_items', where: 'quotation_id = ?', whereArgs: [id]);
      
      Map<String, dynamic> qMap = Map<String, dynamic>.from(qRows.first);
      qMap['items'] = iRows;
      return SmartQuotationModel.fromJson(qMap);
    } catch (e) {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
      return null;
    }
  }

  Future<String> generateDynamicQuoteName(ClientModel? selectedClient, String tempName, {bool isClientRole = false, String? clientUserName, required String type}) async {
      final timeStr = DateFormat('dd-HHmm').format(DateTime.now()); 
      final String typeLabel = type == 'ai_scan' ? "IA" : "Manual";

      if (isClientRole) {
          final String name = (clientUserName != null && clientUserName.isNotEmpty) ? clientUserName : "Cliente";
          return "$name - Pedido $typeLabel #$timeStr"; 
      }

      if (selectedClient == null && tempName.isEmpty) return "Cotización $typeLabel #$timeStr";

      if (selectedClient != null) {
         try {
            final list = await _clientService.getPendingQuotations(selectedClient.id);
            int count = list.length + 1;
            if (count > 1) {
                return "${selectedClient.fullName} #$timeStr ($count) - $typeLabel";
            } else {
                return "${selectedClient.fullName} #$timeStr - $typeLabel";
            }
         } catch(e) {
            return "${selectedClient.fullName} - Cotización $typeLabel #$timeStr";
         }
      }

      return "$tempName #$timeStr";
  }
}