import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/extracted_list_model.dart';
import '../models/matching_model.dart';
import '../models/crm_models.dart'; 
import '../services/matching_service.dart';
import '../services/client_service.dart';

class MatchingProvider with ChangeNotifier {
  final MatchingService _service = MatchingService();
  final ClientService _clientService = ClientService();

  Function()? onAuthRevoked;

  bool _isLoading = false;
  bool _isSaving = false;
  String _errorMessage = '';
  List<MatchPair> _pairs = [];

  List<MatchPair> _originalPairs = [];
  ExtractedMetadata? _originalMetadata;
  bool _hasModifications = false;

  ExtractedMetadata? _metadata;
  ClientModel? _selectedClient; 
  
  File? _localImageFile; 
  String? _fullExtractedText; 

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get errorMessage => _errorMessage;
  List<MatchPair> get pairs => _pairs;
  ExtractedMetadata? get metadata => _metadata;
  ClientModel? get selectedClient => _selectedClient;
  bool get hasModifications => _hasModifications;

  String? _authToken;

  double get totalNetAmount {
    final total = _pairs.fold(0.0, (sum, pair) => sum + pair.subtotal);
    return double.parse(total.toStringAsFixed(2));
  }

  double get totalSavingsAmount {
    final total = _pairs.fold(0.0, (sum, pair) => sum + pair.totalSavings);
    return double.parse(total.toStringAsFixed(2));
  }

  int get matchedCount => _pairs.where((p) => p.selectedProduct != null).length;
  bool get hasStockWarnings => _pairs.any((p) => p.hasStockWarning);

  bool isProductRepeated(int? presentationId) {
    if (presentationId == null) return false;
    int count = _pairs.where((p) => p.selectedProduct?.presentationId == presentationId).length;
    return count > 1;
  }

  void _handleException(dynamic e) {
    if (e.toString().contains("AUTH_REVOKED")) {
      _errorMessage = "Tu acceso a este negocio ha sido revocado.";
      if (onAuthRevoked != null) onAuthRevoked!();
    } else {
      _errorMessage = e.toString().replaceAll("Exception:", "").trim();
    }
  }

  void updateToken(String? token) {
    if (_authToken != token) {
      _authToken = token;
      clearState();
    }
  }

  void clearState() {
    _pairs.clear();
    _originalPairs.clear();
    _metadata = null;
    _originalMetadata = null;
    _selectedClient = null;
    _localImageFile = null;
    _fullExtractedText = null;
    _isLoading = false;
    _isSaving = false;
    _hasModifications = false;
    _errorMessage = '';
    notifyListeners();
  }

  void setEvidence(File? image, String? fullText) {
      _localImageFile = image;
      _fullExtractedText = fullText;
  }

  void resetToInitialState() {
    _pairs = _originalPairs.map((p) => p.clone()).toList();
    _metadata = _originalMetadata?.clone();
    _selectedClient = null; 
    _hasModifications = false;
    notifyListeners();
  }

  Future<void> initializeAndMatch(List<ExtractedItem> sourceItems, ExtractedMetadata? meta, String token, {bool isClientRole = false}) async {
    if (_pairs.isNotEmpty) return;
    _isLoading = true;
    _errorMessage = '';
    _authToken = token;

    _metadata = ExtractedMetadata(
      institutionName: meta?.institutionName ?? "",
      studentName: meta?.studentName ?? "",
      gradeLevel: meta?.gradeLevel ?? "",
    );

    _pairs = sourceItems.map((item) => MatchPair(sourceItem: item)).toList();
    notifyListeners();

    try {
      final results = await _service.runBatchMatching(sourceItems, token, isClientRole); 

      for (var result in results) {
        final index = _pairs.indexWhere((p) => p.sourceItem.id == result.itemId);
        if (index != -1) {
          final pair = _pairs[index];
          
          if (result.suggestedProduct != null) {
            pair.selectedProduct = result.suggestedProduct;
            
            if (result.suggestedQuantity != null) {
                pair.selectedQuantity = result.suggestedQuantity!;
            }

            if (isClientRole) {
                if (pair.selectedProduct!.stock <= 0) {
                    pair.selectedProduct = null;
                    pair.status = MatchStatus.none;
                    continue; 
                } else if (pair.selectedQuantity > pair.selectedProduct!.stock) {
                    pair.selectedQuantity = pair.selectedProduct!.stock;
                }
            }

            if (result.matchTypeString == 'AUTO') {
              pair.status = MatchStatus.auto;
            } else if (result.matchTypeString == 'SUGGESTION') {
              pair.status = MatchStatus.suggestion;
            } else {
              pair.status = MatchStatus.none;
            }
          }
        }
      }
      
      _originalPairs = _pairs.map((p) => p.clone()).toList();
      _originalMetadata = _metadata?.clone();
      _hasModifications = false;

    } catch (e) {
      _handleException(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateMetadata({String? institution, String? student, String? grade}) {
    _metadata ??= ExtractedMetadata();
    if (institution != null) _metadata!.institutionName = institution;
    if (student != null) _metadata!.studentName = student;
    if (grade != null) _metadata!.gradeLevel = grade;
    _hasModifications = true;
    notifyListeners();
  }

  void setClient(ClientModel? client) {
    _selectedClient = client;
    if (client != null) _metadata?.studentName = client.fullName;
    _hasModifications = true;
    notifyListeners();
  }

  void updatePairProduct(int itemId, MatchedProduct product) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedProduct = product;
      _pairs[index].overridePrice = null;
      _pairs[index].status = MatchStatus.manual;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairPrice(int itemId, double? newPrice) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].overridePrice = newPrice;
      _pairs[index].status = MatchStatus.manual;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void updatePairQuantity(int itemId, int newQuantity) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedQuantity = newQuantity;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void unmatchItem(int itemId) {
    final index = _pairs.indexWhere((p) => p.sourceItem.id == itemId);
    if (index != -1) {
      _pairs[index].selectedProduct = null;
      _pairs[index].overridePrice = null;
      _pairs[index].status = MatchStatus.none;
      _hasModifications = true;
      notifyListeners();
    }
  }

  void deletePair(int itemId) {
    _pairs.removeWhere((p) => p.sourceItem.id == itemId);
    _hasModifications = true;
    notifyListeners();
  }

  void addManualRow() {
    int maxId = 0;
    if (_pairs.isNotEmpty) {
      maxId = _pairs.map((p) => p.sourceItem.id).reduce((curr, next) => curr > next ? curr : next);
    }
    final newItem = ExtractedItem(id: maxId + 1, originalText: "Agregado Manual", fullName: "Nuevo Ítem", quantity: 1, unit: "und");
    _pairs.add(MatchPair(sourceItem: newItem, status: MatchStatus.none));
    _hasModifications = true;
    notifyListeners();
  }

  Future<int?> saveQuotation(
    String status, 
    String token,
    {
      String? manualClientName,
      String? manualClientPhone,
      String? manualClientDni,
      String? manualClientAddress,
      String? manualClientEmail,
      String? manualClientNotes,
      bool updateClientData = true,
      String? institutionName, 
      String? gradeLevel,   
      String? type, 
      bool isClientRole = false, 
    }
  ) async {
    _isSaving = true;
    notifyListeners();

    if (_pairs.isEmpty) {
      _errorMessage = "No se puede guardar una lista vacía";
      _isSaving = false;
      notifyListeners();
      return null;
    }

    _metadata ??= ExtractedMetadata();
    if (institutionName != null && institutionName.isNotEmpty) _metadata!.institutionName = institutionName;
    if (gradeLevel != null && gradeLevel.isNotEmpty) _metadata!.gradeLevel = gradeLevel;

    String? uploadedImageUrl;
    if (_localImageFile != null) {
        uploadedImageUrl = await _service.uploadImageToBackend(_localImageFile!, token);
    }

    final Map<int, Map<String, dynamic>> groupedItems = {};

    for (var p in _pairs.where((p) => p.selectedProduct != null)) {
      int pId = p.selectedProduct!.presentationId;
      
      if (groupedItems.containsKey(pId)) {
        groupedItems[pId]!['quantity'] += p.selectedQuantity;
        if (p.sourceItem.originalText.isNotEmpty) {
          groupedItems[pId]!['original_text'] += " | ${p.sourceItem.originalText}";
        }
        
        double currentPrice = groupedItems[pId]!['unit_price_applied'];
        if (p.effectiveUnitPrice < currentPrice) {
           groupedItems[pId]!['unit_price_applied'] = p.effectiveUnitPrice;
           groupedItems[pId]!['is_manual_price'] = p.overridePrice != null;
        }
      } else {
        var itemJson = p.toQuotationItemJson(); 
        if (itemJson != null) {
          itemJson['original_text'] = p.sourceItem.originalText;
          groupedItems[pId] = itemJson;
        }
      }
    }

    final validItems = groupedItems.values.toList();

    if (validItems.isEmpty) {
      _errorMessage = "Selecciona al menos un producto para guardar.";
      _isSaving = false;
      notifyListeners();
      return null;
    }

    // 🔥 PREVENCIÓN DE DUPLICADOS: Si el ID es 0 (Cliente Simulado del Frontend), lo mandamos como null para que el backend asigne el real.
    int? finalClientId = (_selectedClient?.id == 0) ? null : _selectedClient?.id;
    String rawClientName = _selectedClient?.fullName ?? manualClientName?.trim() ?? "";

    // 🔥 BLOQUEO DE CREACIÓN DE CLIENTES SI ES ROL CLIENTE (Evita los nulls y clonaciones)
    if (!isClientRole && updateClientData && rawClientName.isNotEmpty) {
      final clientData = {
        'nombre_completo': rawClientName,
        'telefono': manualClientPhone?.replaceAll(" ", "") ?? "",
        'dni_ruc': manualClientDni?.trim(),
        'direccion': manualClientAddress?.trim(),
        'correo': manualClientEmail?.trim(),
        'notas': manualClientNotes?.trim()
      };
      
      try {
        if (_selectedClient != null && _selectedClient!.id != 0) {
          await _clientService.updateClient(_selectedClient!.id, clientData, token);
        } else {
          final newClient = await _clientService.createClient(clientData, token);
          finalClientId = newClient.id; 
        }
      } catch (e) {
        debugPrint("Error guardando cliente CRM: $e");
      }
    }

    final timeStr = DateFormat('dd-HHmm').format(DateTime.now()); 
    String finalQuoteName = "";
    String typeLabel = type == "ai_scan" ? "IA" : "Manual";

    // 🔥 NOMENCLATURA CORRECTA Y ROBUSTA
    if (isClientRole) {
        final String name = (manualClientName != null && manualClientName.isNotEmpty) ? manualClientName : "Cliente";
        finalQuoteName = "$name - Pedido $typeLabel #$timeStr"; 
    } else {
        if (rawClientName.isEmpty) {
            finalQuoteName = "Cotización $typeLabel #$timeStr";
        } else {
            if (finalClientId != null) {
               try {
                  final list = await _clientService.getPendingQuotations(finalClientId, token);
                  int count = list.length + 1;
                  finalQuoteName = "$rawClientName #$timeStr ($count) - $typeLabel";
               } catch(e) {
                  finalQuoteName = "$rawClientName #$timeStr - $typeLabel";
               }
            } else {
               finalQuoteName = "$rawClientName #$timeStr - $typeLabel";
            }
        }
    }

    double finalAmount = 0.0;
    double finalSavings = 0.0;
    for(var item in validItems) {
      finalAmount += (item['unit_price_applied'] * item['quantity']);
      double originalTotal = item['original_unit_price'] * item['quantity'];
      finalSavings += (originalTotal - (item['unit_price_applied'] * item['quantity']));
    }

    final quotationPayload = {
      "client_id": finalClientId, 
      "client_name": finalQuoteName, 
      "institution_name": _metadata?.institutionName,
      "grade_level": _metadata?.gradeLevel,
      "total_amount": double.parse(finalAmount.toStringAsFixed(2)),
      "total_savings": double.parse(finalSavings.toStringAsFixed(2)),
      "status": status, 
      "type": type ?? "ai_scan", // Mantiene ai_scan o manual original
      "source_image_url": uploadedImageUrl, 
      "items": validItems,
      "original_text_dump": _fullExtractedText 
    };

    try {
      final newId = await _service.saveQuotation(quotationPayload, token);
      _isSaving = false;
      return newId;
    } catch (e) {
      _handleException(e);
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }
}