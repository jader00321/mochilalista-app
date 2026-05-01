import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_constants.dart';
import '../models/scanner_models.dart';
import '../database/local_db.dart';

class ScannerProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;
  
  bool _isLoading = false;
  String _statusMessage = "";

  AIInvoiceResponse? _aiRawData;
  StagingResponse? _stagingData;
  File? _currentImage;
  bool _hasSavedProgress = false; 

  final dbHelper = LocalDatabase.instance;

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
            !v.matchPresentacion.estado.contains("MATCH_MANUAL"))) count++;
      }
    }
    return count;
  }

  int get countLinked {
    if (_stagingData == null) return 0;
    int count = 0;
    for (var group in _stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed && v.matchPresentacion.estado.contains("MATCH")) count++;
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

  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    _negocioId = negocioId;
    _usuarioId = usuarioId;
    // Ya no usamos aiToken, usaremos ApiConstants.googleApiKey
  }

  void saveProgress() {
    if (_stagingData != null) {
      _hasSavedProgress = true;
      notifyListeners();
    }
  }

  void notifyUIUpdate() => notifyListeners();

  Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    if (_negocioId == null || barcode.trim().isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT p.*, pr.id AS pres_id, pr.nombre_especifico, pr.descripcion AS pres_desc, pr.imagen_url AS pres_img,
        pr.codigo_barras AS pres_cb, pr.proveedor_id AS pres_prov, pr.ump_compra, pr.precio_ump_proveedor,
        pr.cantidad_ump_comprada, pr.total_pago_lote, pr.unidades_por_lote, pr.factura_carga_id,
        pr.unidad_venta, pr.unidades_por_venta, pr.costo_unitario_calculado, pr.factor_ganancia_venta,
        pr.precio_venta_final, pr.stock_actual, pr.stock_alerta, pr.es_default, pr.precio_oferta,
        pr.tipo_descuento, pr.valor_descuento, pr.estado AS pres_estado, pr.activo AS pres_activo
        FROM presentaciones_producto pr
        INNER JOIN productos p ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        LIMIT 1
      ''', [_negocioId, barcode.trim(), barcode.trim()]);

      if (rows.isNotEmpty) {
        final row = rows.first;
        Map<String, dynamic> productMap = Map<String, dynamic>.from(row);
        Map<String, dynamic> presentationMap = {
          'id': row['pres_id'], 'nombre_especifico': row['nombre_especifico'], 'descripcion': row['pres_desc'],
          'imagen_url': row['pres_img'], 'codigo_barras': row['pres_cb'], 'proveedor_id': row['pres_prov'],
          'ump_compra': row['ump_compra'], 'precio_ump_proveedor': row['precio_ump_proveedor'],
          'cantidad_ump_comprada': row['cantidad_ump_comprada'], 'total_pago_lote': row['total_pago_lote'],
          'unidades_por_lote': row['unidades_por_lote'], 'factura_carga_id': row['factura_carga_id'],
          'unidad_venta': row['unidad_venta'], 'unidades_por_venta': row['unidades_por_venta'],
          'costo_unitario_calculado': row['costo_unitario_calculado'], 'factor_ganancia_venta': row['factor_ganancia_venta'],
          'precio_venta_final': row['precio_venta_final'], 'stock_actual': row['stock_actual'],
          'stock_alerta': row['stock_alerta'], 'es_default': row['es_default'], 'precio_oferta': row['precio_oferta'],
          'tipo_descuento': row['tipo_descuento'], 'valor_descuento': row['valor_descuento'],
          'estado': row['pres_estado'], 'activo': row['pres_activo'],
        };
        return {'found': true, 'product': productMap, 'presentation': presentationMap};
      } else {
        return {'found': false};
      }
    } catch (e) {
      _statusMessage = "Error buscando código: $e";
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> searchProviders(String query) async {
    if (_negocioId == null) return [];
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'proveedores', 
        where: 'negocio_id = ? AND nombre_empresa LIKE ? AND activo = 1', 
        whereArgs: [_negocioId, '%$query%'], 
        limit: 10
      );
      return rows.map((e) => {"id": e["id"], "nombre_empresa": e["nombre_empresa"], "ruc": e["ruc"]}).toList();
    } catch (e) { return []; }
  }

  // ===========================================================================
  // 🔥 ANÁLISIS IA DIRECTO DESDE EL CELULAR (Sin Backend Python)
  // ===========================================================================
  Future<bool> uploadAndAnalyzeImage(File imageFile) async {
    _isLoading = true;
    _statusMessage = "Analizando con Inteligencia Artificial...";
    _currentImage = imageFile;
    notifyListeners();

    try {
      final apiKey = ApiConstants.googleApiKey;
      if (apiKey.isEmpty) throw Exception("API Key de Google Gemini no configurada en el archivo .env");

      final model = GenerativeModel(
        model: ApiConstants.geminiModelFlash,
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes); // Gemini lo asimila como DataPart

      // 🔥 ESTE ES TU PROMPT ORIGINAL DE PYTHON TRADUCIDO AL CELULAR
      final prompt = TextPart('''
        Actúa como un experto contable y analista de inventarios de papelería en Perú.
        Tu misión es digitalizar esta factura física/electrónica con PRECISIÓN ABSOLUTA.
        
        COMPLEJIDAD DEL NEGOCIO Y FLEXIBILIDAD:
        Los proveedores venden productos en Lotes (Millares, Cientos, Docenas, Cajas).
        A menudo, el cliente compra FRACCIONES de ese lote (Ej: "0.25 MLL" significa 1/4 de millar).
        Debes deducir la matemática de la factura incluso si faltan datos implícitos.

        REGLAS ESTRICTAS DE EXTRACCIÓN DE ÍTEMS:
        1. 'ump_compra': La unidad de empaque del proveedor. (Ej: "DOC", "MLL", "CTO", "UND", "PAQ", "CJA"). Si no se especifica, usa "UND".
        2. 'unidades_por_lote': Deduce cuántas unidades individuales vienen en ese 'ump_compra'. (MLL=1000, CTO=100, DOC=12, GRZ=144, UND=1. Si dice 'Caja x 50', es 50).
        3. 'cantidad_ump_comprada': El número exacto en la columna "Cantidad". (Ej: si dice 0.25 MLL, pon 0.25. Si dice 3 DOC, pon 3.0).
        4. 'total_pago_lote': El importe TOTAL pagado por esa línea específica (Subtotal o Importe de Venta).
        5. 'precio_ump_proveedor': El precio unitario del lote. Si no está claro en la foto, INFIÉRELO DIVIDIENDO: (total_pago_lote / cantidad_ump_comprada).

        REGLAS DE DESCRIPCIÓN:
        - 'producto_padre_estimado': El nombre general limpio (Ej: "Cuaderno Stanford", "Lápiz Chequeador").
        - 'variante_detectada': Características específicas, colores, tamaños (Ej: "A4 Cuadriculado", "Color Rojo").
        - 'marca_detectada': Solo si se menciona explícitamente (Faber Castell, Artesco, etc).

        Extrae el monto total de toda la factura en 'monto_total_factura'.
        Extrae los datos respetando estrictamente el esquema JSON solicitado:
        {
          "proveedor_detectado": "string",
          "ruc_detectado": "string",
          "fecha_detectada": "YYYY-MM-DD",
          "monto_total_factura": float,
          "items": [
            {
              "descripcion_detectada": "string",
              "producto_padre_estimado": "string",
              "variante_detectada": "string",
              "marca_detectada": "string",
              "codigo_detectado": "string",
              "ump_compra": "string",
              "unidades_por_lote": int,
              "cantidad_ump_comprada": float,
              "precio_ump_proveedor": float,
              "total_pago_lote": float,
              "unidad_venta": "string"
            }
          ]
        }
      ''');

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text != null && response.text!.isNotEmpty) {
        // Limpiamos la respuesta en caso de que Gemini añada markdown ```json
        String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = json.decode(cleanJson);
        
        _aiRawData = AIInvoiceResponse.fromJson(decoded);
        return true;
      } else {
        throw Exception("La IA no devolvió datos legibles.");
      }
    } catch (e) {
      _statusMessage = "Error de conexión con la IA: $e";
      debugPrint(_statusMessage);
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
    if (_aiRawData == null || _negocioId == null) return false;
    _isLoading = true;
    _statusMessage = "Buscando coincidencias locales...";
    notifyListeners();

    try {
      final db = await dbHelper.database;
      
      final provQuery = await db.query('proveedores', where: 'negocio_id = ? AND nombre_empresa LIKE ?', whereArgs: [_negocioId, '%${_aiRawData!.proveedorDetectado}%'], limit: 1);
      MatchResult provMatch = provQuery.isNotEmpty 
          ? MatchResult(estado: "MATCH_SUGERIDO", confianza: 80, datos: MatchData(id: provQuery.first['id'] as int, nombre: provQuery.first['nombre_empresa'] as String))
          : MatchResult(estado: "NUEVO", confianza: 0);

      List<StagingProductGroup> grupos = [];
      
      for (var item in _aiRawData!.items) {
        final prodQuery = await db.query('productos', where: 'negocio_id = ? AND nombre LIKE ?', whereArgs: [_negocioId, '%${item.productoPadreEstimado ?? item.descripcion}%'], limit: 1);
        
        MatchResult prodMatch;
        MatchResult presMatch;
        
        if (prodQuery.isNotEmpty) {
          int prodId = prodQuery.first['id'] as int;
          prodMatch = MatchResult(estado: "MATCH_SUGERIDO", confianza: 85, datos: MatchData(id: prodId, nombre: prodQuery.first['nombre'] as String));
          
          final presQuery = await db.query('presentaciones_producto', where: 'producto_id = ?', whereArgs: [prodId]);
          if (presQuery.isNotEmpty) {
            presMatch = MatchResult(
              estado: "MATCH_SUGERIDO", confianza: 80, 
              datos: MatchData(
                id: presQuery.first['id'] as int, 
                nombre: presQuery.first['nombre_especifico'] as String? ?? "General",
                stockActual: presQuery.first['stock_actual'] as int? ?? 0,
                precioVentaFinal: (presQuery.first['precio_venta_final'] as num?)?.toDouble() ?? 0.0,
                costoUnitarioCalculado: (presQuery.first['costo_unitario_calculado'] as num?)?.toDouble() ?? 0.0,
                unidadVenta: presQuery.first['unidad_venta'] as String? ?? "Unidad",
                umpCompra: presQuery.first['ump_compra'] as String? ?? "UND",
                availablePresentations: presQuery.cast<Map<String, dynamic>>()
              )
            );
          } else {
            presMatch = MatchResult(estado: "NUEVO_EN_PADRE", confianza: 0);
          }
        } else {
          prodMatch = MatchResult(estado: "NUEVO", confianza: 0);
          presMatch = MatchResult(estado: "NUEVO", confianza: 0);
        }

        grupos.add(StagingProductGroup(
          nombrePadre: item.productoPadreEstimado ?? item.descripcion,
          nombreOriginalFactura: item.descripcion,
          marcaTexto: item.marcaDetectada ?? "",
          matchProducto: prodMatch,
          matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
          variantes: [
            StagingVariant(
              nombreEspecifico: item.varianteDetectada ?? item.descripcion,
              codigoBarra: item.codigo,
              umpCompra: item.umpCompra,
              cantidadUmpComprada: item.cantidadUmpComprada,
              precioUmpProveedor: item.precioUmpProveedor,
              totalPagoLote: item.totalPagoLote,
              unidadesPorLote: item.unidadesPorLote,
              unidadVenta: item.unidadVenta,
              unidadesPorVenta: 1,
              costoUnitarioSugerido: item.unidadesPorLote > 0 ? (item.precioUmpProveedor / item.unidadesPorLote) : 0,
              factorGananciaVentaSugerido: 1.35,
              precioVentaSugerido: (item.unidadesPorLote > 0 ? (item.precioUmpProveedor / item.unidadesPorLote) : 0) * 1.35,
              matchPresentacion: presMatch
            )
          ]
        ));
      }

      _stagingData = StagingResponse(
        proveedorMatch: provMatch,
        proveedorTexto: _aiRawData!.proveedorDetectado,
        rucProveedor: _aiRawData!.rucDetectado,
        fechaFactura: _aiRawData!.fechaDetectada,
        montoTotalFactura: _aiRawData!.montoTotalFactura,
        productosAgrupados: grupos
      );
      
      _stagingData!.invoiceId = _aiRawData!.invoiceId; 
      return true;

    } catch (e) {
      _statusMessage = "Error en matching local: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      nombrePadre: "Nuevo Producto", marcaTexto: "",
      matchProducto: MatchResult(estado: "NUEVO", confianza: 0),
      matchMarca: MatchResult(estado: "NUEVO", confianza: 0),
      variantes: [
        StagingVariant(
          nombreEspecifico: "Variante A", umpCompra: "UND", cantidadUmpComprada: 1.0, precioUmpProveedor: 0.0, totalPagoLote: 0.0, unidadesPorLote: 1, unidadVenta: "Unidad",
          unidadesPorVenta: 1, costoUnitarioSugerido: 0.0, factorGananciaVentaSugerido: 1.35, precioVentaSugerido: 0.0, matchPresentacion: MatchResult(estado: "NUEVO", confianza: 0),
        )
      ]
    );
    _stagingData!.productosAgrupados.add(newGroup);
    notifyListeners();
  }

  StagingProductGroup? _findGroup(String uuid) {
    try { return _stagingData?.productosAgrupados.firstWhere((g) => g.uuidTemporal == uuid); } catch (_) { return null; }
  }

  StagingVariant? _findVariant(String uuid) {
    if (_stagingData == null) return null;
    for (var g in _stagingData!.productosAgrupados) {
      try { return g.variantes.firstWhere((v) => v.uuidTemporal == uuid); } catch (_) {}
    }
    return null;
  }

  void manualLinkProductGroup(String groupUuid, Map<String, dynamic> product, List<Map<String, dynamic>> siblings) {
    var group = _findGroup(groupUuid);
    if (group == null) return;

    group.matchProducto = MatchResult(
      estado: "MATCH_MANUAL", confianza: 100,
      datos: MatchData(id: product['id'], nombre: product['nombre'], stockActual: product['stock_total_unidades'] ?? 0, marcaNombre: product['marca_nombre'], categoriaNombre: product['categoria_nombre'])
    );
    group.nombrePadre = product['nombre'];
    group.marcaTexto = product['marca_nombre'] ?? "Genérica";

    for (var v in group.variantes) {
      String invoiceName = v.nombreEspecifico.toLowerCase().trim();
      var bestMatch = siblings.firstWhere((s) {
            String sName = (s['nombre_especifico'] ?? "").toLowerCase().trim();
            return sName == invoiceName || (invoiceName.isNotEmpty && sName.contains(invoiceName));
        }, orElse: () => <String, dynamic>{}
      );

      if (bestMatch.isNotEmpty) {
        v.matchPresentacion = MatchResult(
          estado: "MATCH_MANUAL", confianza: 100,
          datos: MatchData(
            id: bestMatch['id'], nombre: bestMatch['nombre_completo'] ?? bestMatch['nombre_presentacion'],
            stockActual: bestMatch['stock_actual'] ?? 0, precioVentaFinal: (bestMatch['precio_venta'] ?? 0).toDouble(), 
            costoUnitarioCalculado: (bestMatch['precio_costo'] ?? 0).toDouble(), unidadesPorLote: 1, 
            unidadesPorVenta: bestMatch['factor_conversion'] ?? 1, umpCompra: bestMatch['unidad'] ?? 'Unidad', 
            unidadVenta: bestMatch['unidad'] ?? 'Unidad', availablePresentations: siblings
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
    for (var v in group.variantes) v.matchPresentacion = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
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
        stockActual: selectedSibling['stock_actual'] ?? 0, precioVentaFinal: (selectedSibling['precio_venta'] ?? 0).toDouble(),
        costoUnitarioCalculado: (selectedSibling['precio_costo'] ?? 0).toDouble(), unidadesPorVenta: selectedSibling['factor_conversion'] ?? 1,
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
        if (group.variantes.isEmpty) _stagingData!.productosAgrupados.removeAt(g);
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
        nombreEspecifico: "Nueva presentación", umpCompra: "UND", cantidadUmpComprada: 1.0, precioUmpProveedor: 0.0, totalPagoLote: 0.0, unidadesPorLote: 1, unidadVenta: "Unidad",
        unidadesPorVenta: 1, costoUnitarioSugerido: 0.0, factorGananciaVentaSugerido: 1.35, precioVentaSugerido: 0.0,
        matchPresentacion: MatchResult(estado: group.matchProducto.estado.contains("MATCH") ? "NUEVO_EN_PADRE" : "NUEVO", confianza: 0, datos: siblings != null ? MatchData(id: -1, nombre: "", availablePresentations: siblings) : null),
      )
    );
    notifyListeners();
  }

  Future<bool> executeBatchSave() async {
    if (_stagingData == null || _negocioId == null || _usuarioId == null) return false;
    _isLoading = true;
    _statusMessage = "Guardando inventario local...";
    notifyListeners();

    try {
      final db = await dbHelper.database;
      
      // 🔥 TRANSACCIÓN SEGURA AÑADIDA
      await db.transaction((txn) async {
        int? idProveedor = _stagingData!.proveedorMatch.datos?.id;
        if (!_stagingData!.proveedorMatch.estado.contains("MATCH")) {
          idProveedor = await txn.insert('proveedores', {
            'negocio_id': _negocioId, 'nombre_empresa': _stagingData!.proveedorTexto, 
            'ruc': _stagingData!.rucProveedor, 'activo': 1, 'fecha_creacion': DateTime.now().toIso8601String()
          });
        }

        int idFactura = await txn.insert('facturas_carga', {
          'negocio_id': _negocioId, 'proveedor_id': idProveedor, 'estado': 'completado',
          'fecha_carga': DateTime.now().toIso8601String(), 'fecha_emision': _stagingData!.fechaFactura,
          'monto_total_factura': _stagingData!.montoTotalFactura, 'imagen_url': 'local_ia_scan' 
        });

        for (var group in _stagingData!.productosAgrupados) {
          var variantesActivas = group.variantes.where((v) => v.isConfirmed).toList();
          if (variantesActivas.isEmpty) continue;

          int? idProducto = group.matchProducto.datos?.id;
          
          if (!group.matchProducto.estado.contains("MATCH")) {
            idProducto = await txn.insert('productos', {
              'negocio_id': _negocioId, 'nombre': group.nombrePadre, 'categoria_id': group.categoriaSugeridaId,
              'estado': 'publico', 'fecha_actualizacion': DateTime.now().toIso8601String()
            });
          }

          for (var v in variantesActivas) {
            int cantidadSumar = ((v.cantidadUmpComprada * v.unidadesPorLote) / v.unidadesPorVenta).toInt();
            
            if (v.matchPresentacion.estado.contains("MATCH") && v.matchPresentacion.estado != "NUEVO_EN_PADRE") {
              int idPres = v.matchPresentacion.datos!.id;
              
              final oldP = await txn.query('presentaciones_producto', where: 'id = ?', whereArgs: [idPres]);
              int stockActual = (oldP.first['stock_actual'] as int?) ?? 0;

              Map<String, dynamic> updateData = {'stock_actual': stockActual + cantidadSumar};
              if (v.updateCosto) updateData['costo_unitario_calculado'] = v.costoUnitarioSugerido;
              if (v.updatePrecio) updateData['precio_venta_final'] = v.precioVentaSugerido;
              if (v.updateNombre) updateData['nombre_especifico'] = v.nombreEspecifico;
              
              await txn.update('presentaciones_producto', updateData, where: 'id = ?', whereArgs: [idPres]);
            } else {
              await txn.insert('presentaciones_producto', {
                'producto_id': idProducto, 'proveedor_id': idProveedor, 'factura_carga_id': idFactura,
                'nombre_especifico': v.nombreEspecifico, 'codigo_barras': v.codigoBarra,
                'ump_compra': v.umpCompra, 'precio_ump_proveedor': v.precioUmpProveedor,
                'cantidad_ump_comprada': v.cantidadUmpComprada, 'total_pago_lote': v.totalPagoLote,
                'unidades_por_lote': v.unidadesPorLote, 'unidad_venta': v.unidadVenta,
                'unidades_por_venta': v.unidadesPorVenta, 'factor_ganancia_venta': v.factorGananciaVentaSugerido,
                'costo_unitario_calculado': v.costoUnitarioSugerido, 'precio_venta_final': v.precioVentaSugerido,
                'stock_actual': cantidadSumar, 'estado': 'publico', 'activo': 1, 'es_default': 0
              });
            }
          }
        }
      }); 

      return true;
    } catch (e) {
      _statusMessage = "Error crítico al guardar localmente: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}