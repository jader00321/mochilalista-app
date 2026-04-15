import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_constants.dart';
import '../models/scanner_models.dart';

class ScannerProvider with ChangeNotifier {
  String? _authToken;
  bool _isLoading = false;
  String _statusMessage = "";

  AIInvoiceResponse? _aiRawData;
  StagingResponse? _stagingData;
  File? _currentImage;

  bool _hasSavedProgress = false; 

  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  AIInvoiceResponse? get aiRawData => _aiRawData;
  StagingResponse? get stagingData => _stagingData;
  File? get currentImage => _currentImage;
  bool get hasSavedProgress => _hasSavedProgress;

  void clearData() {
    _aiRawData = null;
    _stagingData = null;
    _currentImage = null;
    _statusMessage = "";
    _hasSavedProgress = false;
    notifyListeners();
  }

  int get countNew {
    if (_stagingData == null) return 0;
    int count = 0;
    for (var group in _stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed && (!v.matchPresentacion.estado.contains("MATCH_EXACTO") && 
            !v.matchPresentacion.estado.contains("MATCH_MANUAL"))) {
          count++;
        }
      }
    }
    return count;
  }

  int get countLinked {
    if (_stagingData == null) return 0;
    int count = 0;
    for (var group in _stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed && v.matchPresentacion.estado.contains("MATCH")) {
          count++;
        }
      }
    }
    return count;
  }

  int get totalActiveVariants {
    if (_stagingData == null) return 0;
    int count = 0;
    for (var group in _stagingData!.productosAgrupados) {
      count += group.variantes.where((v) => v.isConfirmed).length;
    }
    return count;
  }

  void updateToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_authToken',
    'Content-Type': 'application/json',
  };

  void saveProgress() {
    if (_stagingData != null) {
      _hasSavedProgress = true;
      notifyListeners();
    }
  }

  void notifyUIUpdate() {
    notifyListeners();
  }

  Future<Map<String, dynamic>?> scanBarcode(String code) async {
    return _genericSearch('${ApiConstants.baseUrl}/scanner/barcode/search?code=$code');
  }

  Future<Map<String, dynamic>?> _genericSearch(String urlStr) async {
    _isLoading = true;
    _statusMessage = "Buscando...";
    notifyListeners();
    try {
      final res = await http.get(Uri.parse(urlStr), headers: _headers);
      if (res.statusCode == 200) return json.decode(utf8.decode(res.bodyBytes));
    } catch (e) {
      debugPrint("Error search: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchProviders(String query) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/providers/?q=$query&limit=10');
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
        return data.map((e) => {"id": e["id"], "nombre_empresa": e["nombre_empresa"], "ruc": e["ruc"]}).toList();
      }
    } catch (e) {}
    return [];
  }

  Future<bool> uploadAndAnalyzeImage(File imageFile) async {
    _isLoading = true;
    _statusMessage = "Analizando imagen con IA...";
    _currentImage = imageFile;
    notifyListeners();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConstants.baseUrl}/scanner/ai/analyze_invoice'));
      request.headers['Authorization'] = 'Bearer $_authToken';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var streamedRes = await request.send();
      var res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        _aiRawData = AIInvoiceResponse.fromJson(decoded);
        return true;
      } else {
        _statusMessage = "Error IA (${res.statusCode}): ${res.body}";
      }
    } catch (e) {
      _statusMessage = "Error de conexión: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  void updateRawItems(List<AIItemExtracted> newItems, String newProvider, String newRuc, String newDate, double? newMontoTotal) {
    if (_aiRawData != null) {
      _aiRawData!.items = newItems;
      _aiRawData!.proveedorDetectado = newProvider;
      _aiRawData!.rucDetectado = newRuc;
      _aiRawData!.fechaDetectada = newDate;
      _aiRawData!.montoTotalFactura = newMontoTotal; 
      notifyListeners();
    }
  }

  Future<bool> runMatchingProcess() async {
    if (_aiRawData == null) return false;
    _isLoading = true;
    _statusMessage = "Buscando coincidencias...";
    notifyListeners();

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/scanner/match/match');
      final body = json.encode(_aiRawData!.toJson());
      final res = await http.post(url, headers: _headers, body: body);

      if (res.statusCode == 200) {
        final decoded = json.decode(utf8.decode(res.bodyBytes));
        _stagingData = StagingResponse.fromJson(decoded);
        
        _stagingData!.invoiceId = _aiRawData!.invoiceId; 
        _stagingData!.rucProveedor = _aiRawData!.rucDetectado;
        _stagingData!.fechaFactura = _aiRawData!.fechaDetectada;
        
        return true;
      } else {
        _statusMessage = "Error Matching: ${res.body}";
      }
    } catch (e) {
      _statusMessage = "Error al conectar: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  void updateStagingProvider({required String nombre, int? idExistente, String? ruc, String? fecha}) {
    if (_stagingData == null) return;
    _stagingData!.proveedorTexto = nombre;
    if (ruc != null) _stagingData!.rucProveedor = ruc;
    if (fecha != null) _stagingData!.fechaFactura = fecha;

    if (idExistente != null) {
      _stagingData!.proveedorMatch = MatchResult(estado: "MATCH_MANUAL", confianza: 100, datos: MatchData(id: idExistente, nombre: nombre));
    } else {
      _stagingData!.proveedorMatch = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
    }
    notifyListeners();
  }

  void addNewProductGroup() {
    if (_stagingData == null) return;

    final newGroup = StagingProductGroup(
      nombrePadre: "Nuevo Producto",
      marcaTexto: "",
      matchProducto: MatchResult(estado: "NUEVO", confianza: 0),
      matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
      variantes: [
        StagingVariant(
          nombreEspecifico: "Variante A",
          umpCompra: "UND",
          cantidadUmpComprada: 1.0,
          precioUmpProveedor: 0.0,
          totalPagoLote: 0.0,
          unidadesPorLote: 1,
          unidadVenta: "Unidad",
          unidadesPorVenta: 1,
          costoUnitarioSugerido: 0.0,
          factorGananciaVentaSugerido: 1.35,
          precioVentaSugerido: 0.0,
          matchPresentacion: MatchResult(estado: "NUEVO", confianza: 0),
        )
      ]
    );

    _stagingData!.productosAgrupados.add(newGroup);
    notifyListeners();
  }

  StagingProductGroup? _findGroup(String uuid) {
    try {
      return _stagingData?.productosAgrupados.firstWhere((g) => g.uuidTemporal == uuid);
    } catch (_) {
      return null;
    }
  }

  StagingVariant? _findVariant(String uuid) {
    if (_stagingData == null) return null;
    for (var g in _stagingData!.productosAgrupados) {
      try {
        return g.variantes.firstWhere((v) => v.uuidTemporal == uuid);
      } catch (_) {}
    }
    return null;
  }

  void manualLinkProductGroup(String groupUuid, Map<String, dynamic> product, List<Map<String, dynamic>> siblings) {
    var group = _findGroup(groupUuid);
    if (group == null) return;

    group.matchProducto = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: product['id'], nombre: product['nombre'], stockActual: product['stock_total_unidades'] ?? 0,
        marcaNombre: product['marca_nombre'], categoriaNombre: product['categoria_nombre']
      )
    );
    group.nombrePadre = product['nombre'];
    group.marcaTexto = product['marca_nombre'] ?? "Genérica";

    for (var v in group.variantes) {
      String invoiceName = v.nombreEspecifico.toLowerCase().trim();
      var bestMatch = siblings.firstWhere(
        (s) {
            String sName = (s['nombre_especifico'] ?? "").toLowerCase().trim();
            return sName == invoiceName || (invoiceName.isNotEmpty && sName.contains(invoiceName));
        },
        orElse: () => <String, dynamic>{}
      );

      if (bestMatch.isNotEmpty) {
        v.matchPresentacion = MatchResult(
          estado: "MATCH_MANUAL", confianza: 100,
          datos: MatchData(
            id: bestMatch['id'], nombre: bestMatch['nombre_completo'] ?? bestMatch['nombre_presentacion'],
            stockActual: bestMatch['stock_actual'] ?? 0, 
            precioVentaFinal: (bestMatch['precio_venta'] ?? 0).toDouble(), 
            costoUnitarioCalculado: (bestMatch['precio_costo'] ?? 0).toDouble(), 
            unidadesPorLote: 1, 
            unidadesPorVenta: bestMatch['factor_conversion'] ?? 1,
            umpCompra: bestMatch['unidad'] ?? 'Unidad', 
            unidadVenta: bestMatch['unidad'] ?? 'Unidad',
            availablePresentations: siblings
          )
        );
      } else {
        v.matchPresentacion = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0, datos: MatchData(id: -1, nombre: "Nueva Variante", availablePresentations: siblings));
      }
    }
    notifyListeners();
  }

  void unlinkProductGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    
    if (group.nombreOriginalFactura != null) group.nombrePadre = group.nombreOriginalFactura!;
    group.matchProducto = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
    
    for (var v in group.variantes) {
      v.matchPresentacion = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
    }
    notifyListeners();
  }

  void switchVariantLink(String variantUuid, int newPresentationId) {
    var variant = _findVariant(variantUuid);
    var currentMatchData = variant?.matchPresentacion.datos;
    if (variant == null || currentMatchData == null || currentMatchData.availablePresentations == null) return;

    var selectedSibling = currentMatchData.availablePresentations!.firstWhere((p) => p['id'] == newPresentationId, orElse: () => <String, dynamic>{});
    if (selectedSibling.isEmpty) return;

    variant.matchPresentacion = MatchResult(
      estado: "MATCH_MANUAL", confianza: 100,
      datos: MatchData(
        id: selectedSibling['id'], nombre: selectedSibling['nombre_completo'] ?? selectedSibling['nombre_presentacion'],
        stockActual: selectedSibling['stock_actual'] ?? 0, 
        precioVentaFinal: (selectedSibling['precio_venta'] ?? 0).toDouble(),
        costoUnitarioCalculado: (selectedSibling['precio_costo'] ?? 0).toDouble(), 
        unidadesPorVenta: selectedSibling['factor_conversion'] ?? 1,
        unidadVenta: selectedSibling['unidad'] ?? 'Unidad', availablePresentations: currentMatchData.availablePresentations
      )
    );
    notifyListeners();
  }

  void switchVariantToNew(String variantUuid) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;

    var siblingsBackup = variant.matchPresentacion.datos?.availablePresentations;
    variant.matchPresentacion = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0, datos: MatchData(id: -1, nombre: "Nueva Variante", availablePresentations: siblingsBackup));
    
    variant.factorGananciaVentaSugerido = 1.35; 
    variant.precioVentaSugerido = variant.costoUnitarioSugerido * variant.factorGananciaVentaSugerido;
    notifyListeners();
  }

  void removeVariantByUuid(String variantUuid) {
    if (_stagingData == null) return;
    for (int g = 0; g < _stagingData!.productosAgrupados.length; g++) {
      var group = _stagingData!.productosAgrupados[g];
      int vIndex = group.variantes.indexWhere((v) => v.uuidTemporal == variantUuid);
      
      if (vIndex != -1) {
        group.variantes.removeAt(vIndex);
        if (group.variantes.isEmpty) {
          _stagingData!.productosAgrupados.removeAt(g);
        }
        notifyListeners();
        return; 
      }
    }
  }

  void toggleVariantUpdate(String variantUuid, String field) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;

    if (field == 'costo') variant.updateCosto = !variant.updateCosto;
    if (field == 'precio') variant.updatePrecio = !variant.updatePrecio;
    if (field == 'nombre') variant.updateNombre = !variant.updateNombre;
    notifyListeners();
  }

  void addNewVariantToGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    
    List<Map<String, dynamic>>? siblings;
    if (group.matchProducto.estado.contains("MATCH") && group.variantes.isNotEmpty) {
      siblings = group.variantes.first.matchPresentacion.datos?.availablePresentations;
    }

    group.variantes.add(
      StagingVariant(
        nombreEspecifico: "Nueva presentación",
        umpCompra: "UND",
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 0.0,
        totalPagoLote: 0.0,
        unidadesPorLote: 1,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 0.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 0.0,
        matchPresentacion: MatchResult(
          estado: group.matchProducto.estado.contains("MATCH") ? "NUEVO_EN_PADRE" : "NUEVO", confianza: 0,
          datos: siblings != null ? MatchData(id: -1, nombre: "", availablePresentations: siblings) : null
        ),
      )
    );
    notifyListeners();
  }

  Future<bool> executeBatchSave() async {
    if (_stagingData == null) return false;
    _isLoading = true;
    _statusMessage = "Guardando inventario...";
    notifyListeners();

    try {
      List<Map<String, dynamic>> itemsPayload = [];

      for (var group in _stagingData!.productosAgrupados) {
        var variantesActivas = group.variantes.where((v) => v.isConfirmed).toList();
        if (variantesActivas.isEmpty) continue;

        bool isParentMatch = group.matchProducto.estado.contains("MATCH");
        
        if (!isParentMatch && group.categoriaSugeridaId == null) {
           _statusMessage = "Falta seleccionar categoría para: ${group.nombrePadre}";
           _isLoading = false;
           notifyListeners();
           return false;
        }

        List<Map<String, dynamic>> variantesJson = [];
        for (var v in variantesActivas) {
          bool isVariantMatch = v.matchPresentacion.estado.contains("MATCH") && v.matchPresentacion.estado != "NUEVO_EN_PADRE";
          
          variantesJson.add({
            "id_presentacion_existente": isVariantMatch ? v.matchPresentacion.datos?.id : null,
            "nombre_especifico": v.nombreEspecifico,
            "codigo_barras": v.codigoBarra,
            
            "ump_compra": v.umpCompra,
            "precio_ump_proveedor": v.precioUmpProveedor,
            "cantidad_ump_comprada": v.cantidadUmpComprada,
            "total_pago_lote": v.totalPagoLote,
            "unidades_por_lote": v.unidadesPorLote,
            
            "unidad_venta": v.unidadVenta,
            "unidades_por_venta": v.unidadesPorVenta,
            "factor_ganancia_venta": v.factorGananciaVentaSugerido,
            
            "cantidad_a_sumar": ((v.cantidadUmpComprada * v.unidadesPorLote) / v.unidadesPorVenta).toInt(),
            
            "actualizar_costo": v.updateCosto,
            "actualizar_precio_venta": v.updatePrecio,
            "actualizar_nombre": v.updateNombre
          });
        }

        Map<String, dynamic> productJson = {
          "accion": isParentMatch ? "vincular_existente" : "crear_nuevo",
          "id_producto_existente": isParentMatch ? group.matchProducto.datos?.id : null,
          "nombre_nuevo": group.nombrePadre,
          "categoria_id": group.categoriaSugeridaId, 
          "marca": {
             "modo": group.matchMarca.estado.contains("MATCH") ? "existente" : "nuevo",
             "id_existente": group.matchMarca.datos?.id,
             "nombre_nuevo": group.marcaTexto
          },
          "variantes": variantesJson
        };
        itemsPayload.add(productJson);
      }

      String modoProv = _stagingData!.proveedorMatch.estado.contains("MATCH") ? "existente" : "nuevo";
      
      Map<String, dynamic> batchRequest = {
        "factura_carga_id": _stagingData!.invoiceId, 
        "fecha_emision": _stagingData!.fechaFactura, 
        "proveedor": {
          "modo": modoProv,
          "id_existente": _stagingData!.proveedorMatch.datos?.id,
          "nombre_nuevo": _stagingData!.proveedorTexto,
          "ruc": _stagingData!.rucProveedor 
        },
        "items": itemsPayload
      };

      final url = Uri.parse('${ApiConstants.baseUrl}/scanner/batch/execute');
      final res = await http.post(url, headers: _headers, body: json.encode(batchRequest));

      if (res.statusCode == 200) {
        return true;
      } else {
        _statusMessage = "Error Guardado (${res.statusCode}): ${res.body}";
      }
    } catch (e) {
      _statusMessage = "Error crítico: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}