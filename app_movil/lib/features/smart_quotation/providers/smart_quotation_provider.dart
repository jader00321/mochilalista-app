import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/extracted_list_model.dart'; 
import '../models/smart_quotation_model.dart'; 
import '../models/matching_model.dart';
import '../models/crm_models.dart';
import '../services/ai_extraction_service.dart';
import 'matching_provider.dart';
import '../services/client_service.dart';
import '../../../database/local_db.dart';

class SmartQuotationProvider with ChangeNotifier {
  String? _aiToken; // Token para peticiones IA

  final AIExtractionService _service = AIExtractionService();
  final ClientService _clientService = ClientService(); 
  final dbHelper = LocalDatabase.instance;
  
  // 🔥 SE ELIMINÓ onAuthRevoked YA QUE ESTAMOS OFFLINE Y NUNCA EXPIRARÁ LOCALMENTE

  bool _isLoading = false;
  String _errorMessage = '';

  File? _currentImage;
  ExtractedMetadata? _metadata;
  List<ExtractedItem> _items = [];

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

  bool get hasManualDraft => draftManualItems != null && draftManualItems!.isNotEmpty;

  void _handleException(dynamic e) {
    _errorMessage = e.toString().replaceAll("Exception:", "").trim();
  }

  void saveManualDraft({
    required List<MatchedProduct> items, required Map<int, int> quantities, required Map<int, double> prices,
    required Map<int, String> names, ClientModel? client, String? cName, String? cPhone, String? cDni, 
    String? cAddr, String? cEmail, String? cNotes, String? qTitle, String? qNotes, 
    String? school, String? grade, int? quotationId,
  }) {
    draftManualItems = List.from(items);
    draftManualQuantities = Map.from(quantities);
    draftManualPrices = Map.from(prices);
    draftManualNames = Map.from(names);
    
    draftClient = client;
    draftClientName = cName; draftClientPhone = cPhone; draftClientDni = cDni;
    draftClientAddress = cAddr; draftClientEmail = cEmail; draftClientNotes = cNotes;
    
    draftQuoteTitle = qTitle; draftQuoteNotes = qNotes; draftSchool = school;
    draftGrade = grade; draftQuotationId = quotationId;
  }

  void clearManualDraft() {
    draftManualItems = null; draftManualQuantities = null; draftManualPrices = null; draftManualNames = null;
    draftClient = null; draftClientName = null; draftClientPhone = null; draftClientDni = null;
    draftClientAddress = null; draftClientEmail = null; draftClientNotes = null;
    draftQuoteTitle = null; draftQuoteNotes = null; draftSchool = null; draftGrade = null; draftQuotationId = null;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  File? get currentImage => _currentImage;
  ExtractedMetadata? get metadata => _metadata;
  List<ExtractedItem> get items => _items;

  String get fullExtractedText {
      if (_items.isEmpty) return "";
      return _items.map((i) => i.originalText).join("\n");
  }

  // 🔥 Multi-Perfil Context
  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    _aiToken = aiToken;
  }

  void clearState() {
    _items = []; _metadata = null; _currentImage = null; _errorMessage = '';
    notifyListeners();
  }

  Future<bool> analyzeImage(BuildContext context, File image) async {
    if (_aiToken == null) {
      _errorMessage = "Requiere token para servicio IA.";
      notifyListeners();
      return false;
    }

    Provider.of<MatchingProvider>(context, listen: false).clearState();
    _isLoading = true;
    _errorMessage = '';
    _currentImage = image;
    notifyListeners();

    try {
      final response = await _service.analyzeImage(image, _aiToken!);
      _metadata = response.metadata;
      _items = response.items;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _handleException(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void updateItem(int id, {String? fullName, String? brand, int? quantity, String? unit, String? notes}) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1) {
      final item = _items[index];
      if (fullName != null) item.fullName = fullName;
      if (brand != null) item.brand = brand;
      if (quantity != null) item.quantity = quantity;
      if (unit != null) item.unit = unit;
      if (notes != null) item.notes = notes;
      notifyListeners();
    }
  }

  void deleteItem(int id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addItem() {
    int newId = _items.isNotEmpty ? _items.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1 : 1;
    _items.add(ExtractedItem(id: newId, originalText: "Agregado manual", fullName: "", quantity: 1, unit: "unidad"));
    notifyListeners();
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _metadata ??= ExtractedMetadata();
    if (institution != null) _metadata!.institutionName = institution;
    if (student != null) _metadata!.studentName = student;
    if (grade != null) _metadata!.gradeLevel = grade;
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
      _handleException(e);
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