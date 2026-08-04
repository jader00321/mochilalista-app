import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/scanner_models.dart';
import '../database/local_db.dart';
import '../database/product_queries.dart';
import '../services/scanner_ai_service.dart';
import '../services/scanner_matching_engine.dart';
import '../services/scanner_batch_saver.dart';

/// Provider coordinador para el flujo de escaneo de facturas.
///
/// Después de la refactorización (Fase 4), este provider solo se encarga de:
/// - Mantener el estado de la UI (loading, mensajes, datos de staging)
/// - Coordinar la ejecución de los 3 servicios especializados
/// - Proveer métodos de manipulación de staging para la UI
///
/// La lógica pesada fue extraída a:
/// - [ScannerAIService]: Comunicación con Gemini AI
/// - [ScannerMatchingEngine]: Matching contra SQLite
/// - [ScannerBatchSaver]: Transacción de guardado masivo
class ScannerProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  bool _isLoading = false;
  String _statusMessage = "";

  AIInvoiceResponse? _aiRawData;
  StagingResponse? _stagingData;
  File? _currentImage;
  bool _hasSavedProgress = false;

  // Servicios especializados
  final _aiService = ScannerAIService();
  final _matchingEngine = ScannerMatchingEngine();
  final _batchSaver = ScannerBatchSaver();
  final _dbHelper = LocalDatabase.instance;

  // ==========================================
  // GETTERS
  // ==========================================
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  AIInvoiceResponse? get aiRawData => _aiRawData;
  StagingResponse? get stagingData => _stagingData;
  File? get currentImage => _currentImage;
  bool get hasSavedProgress => _hasSavedProgress;

  int get countNew {
    if (_stagingData == null) return 0;
    int count = 0;
    for (var group in _stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed &&
            (!v.matchPresentacion.estado.contains("MATCH_EXACTO") &&
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

  // ==========================================
  // CONTEXTO Y ESTADO
  // ==========================================
  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    _negocioId = negocioId;
    _usuarioId = usuarioId;
  }

  void clearData() {
    _aiRawData = null;
    _stagingData = null;
    _currentImage = null;
    _statusMessage = "";
    _hasSavedProgress = false;
    notifyListeners();
  }

  void saveProgress() {
    if (_stagingData != null) {
      _hasSavedProgress = true;
      notifyListeners();
    }
  }

  void notifyUIUpdate() => notifyListeners();

  // ==========================================
  // OPERACIONES DE ESCANEO (Delegadas a servicios)
  // ==========================================

  /// Busca un producto por código de barras en la BD local.
  Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    if (_negocioId == null || barcode.trim().isEmpty) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        ${ProductQueries.fullInventoryQuery}
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        LIMIT 1
      ''', [_negocioId, barcode.trim(), barcode.trim()]);

      if (rows.isNotEmpty) {
        final wrapper = ProductQueries.parseInventoryRow(rows.first);
        return {
          'found': true,
          'product': wrapper.product.toJson(),
          'presentation': wrapper.presentation.toJson(),
        };
      } else {
        return {'found': false};
      }
    } catch (e, stack) {
      AppLogger.error('ScannerProvider.scanBarcode', e, stack);
      _statusMessage = "Error buscando código: $e";
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busca proveedores por nombre para autocompletado.
  Future<List<Map<String, dynamic>>> searchProviders(String query) async {
    if (_negocioId == null) return [];
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'proveedores',
        where: 'negocio_id = ? AND nombre_empresa LIKE ? AND activo = 1',
        whereArgs: [_negocioId, '%$query%'],
        limit: 10,
      );
      return rows
          .map((e) => {
                "id": e["id"],
                "nombre_empresa": e["nombre_empresa"],
                "ruc": e["ruc"],
              })
          .toList();
    } catch (e, stack) {
      AppLogger.error('ScannerProvider.searchProviders', e, stack);
      return [];
    }
  }

  /// Envía la imagen al servicio de IA para análisis.
  /// Delega a [ScannerAIService].
  Future<bool> uploadAndAnalyzeImage(File imageFile) async {
    _isLoading = true;
    _statusMessage = "Analizando con Inteligencia Artificial...";
    _currentImage = imageFile;
    notifyListeners();

    try {
      _aiRawData = await _aiService.analyzeInvoiceImage(imageFile);
      return _aiRawData != null;
    } catch (e) {
      _statusMessage = "Error de conexión con la IA: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Actualiza los datos crudos de la IA (edición manual del usuario).
  void updateRawItems(
    List<AIItemExtracted> newItems,
    String newProvider,
    String newRuc,
    String newDate,
    double? newMontoTotal,
  ) {
    if (_aiRawData != null) {
      _aiRawData!.items = newItems;
      _aiRawData!.proveedorDetectado = newProvider;
      _aiRawData!.rucDetectado = newRuc;
      _aiRawData!.fechaDetectada = newDate;
      _aiRawData!.montoTotalFactura = newMontoTotal;
      notifyListeners();
    }
  }

  /// Ejecuta el matching contra la BD local.
  /// Delega a [ScannerMatchingEngine].
  Future<bool> runMatchingProcess() async {
    if (_aiRawData == null || _negocioId == null) return false;
    _isLoading = true;
    _statusMessage = "Buscando coincidencias locales...";
    notifyListeners();

    try {
      _stagingData = await _matchingEngine.runMatching(
        aiData: _aiRawData!,
        negocioId: _negocioId!,
      );
      return _stagingData != null;
    } catch (e) {
      _statusMessage = "Error en matching local: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ejecuta el guardado masivo en la BD.
  /// Delega a [ScannerBatchSaver].
  Future<bool> executeBatchSave() async {
    if (_stagingData == null || _negocioId == null || _usuarioId == null) {
      return false;
    }
    _isLoading = true;
    _statusMessage = "Guardando inventario local...";
    notifyListeners();

    try {
      return await _batchSaver.executeBatchSave(
        stagingData: _stagingData!,
        negocioId: _negocioId!,
        usuarioId: _usuarioId!,
        onProgress: (String message) {
          _statusMessage = message;
          notifyListeners();
        },
      );
    } catch (e) {
      _statusMessage = "Error crítico al guardar localmente: $e";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // MANIPULACIÓN DE STAGING (UI)
  // ==========================================

  void updateStagingProvider({
    required String nombre,
    int? idExistente,
    String? ruc,
    String? fecha,
  }) {
    if (_stagingData == null) return;
    _stagingData!.proveedorTexto = nombre;
    if (ruc != null) _stagingData!.rucProveedor = ruc;
    if (fecha != null) _stagingData!.fechaFactura = fecha;

    if (idExistente != null) {
      _stagingData!.proveedorMatch = MatchResult(
        estado: "MATCH_MANUAL",
        confianza: 100,
        datos: MatchData(id: idExistente, nombre: nombre),
      );
    } else {
      _stagingData!.proveedorMatch = MatchResult(
        estado: "NUEVO",
        confianza: 0,
        datos: null,
      );
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
        ),
      ],
    );
    _stagingData!.productosAgrupados.add(newGroup);
    notifyListeners();
  }

  // --- Helpers de búsqueda interna ---
  StagingProductGroup? _findGroup(String uuid) {
    try {
      return _stagingData?.productosAgrupados
          .firstWhere((g) => g.uuidTemporal == uuid);
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

  // --- Operaciones de linking manual ---
  void manualLinkProductGroup(
    String groupUuid,
    Map<String, dynamic> product,
    List<Map<String, dynamic>> siblings,
  ) {
    var group = _findGroup(groupUuid);
    if (group == null) return;

    group.matchProducto = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: product['id'],
        nombre: product['nombre'],
        stockActual: product['stock_total_unidades'] ?? 0,
        marcaNombre: product['marca_nombre'],
        categoriaNombre: product['categoria_nombre'],
      ),
    );
    group.nombrePadre = product['nombre'];
    group.marcaTexto = product['marca_nombre'] ?? "Genérica";

    for (var v in group.variantes) {
      String invoiceName = v.nombreEspecifico.toLowerCase().trim();
      var bestMatch = siblings.firstWhere(
        (s) {
          String sName = (s['nombre_especifico'] ?? "").toLowerCase().trim();
          return sName == invoiceName ||
              (invoiceName.isNotEmpty && sName.contains(invoiceName));
        },
        orElse: () => <String, dynamic>{},
      );

      if (bestMatch.isNotEmpty) {
        v.matchPresentacion = MatchResult(
          estado: "MATCH_MANUAL",
          confianza: 100,
          datos: MatchData(
            id: bestMatch['id'],
            nombre: bestMatch['nombre_completo'] ??
                bestMatch['nombre_presentacion'],
            stockActual: bestMatch['stock_actual'] ?? 0,
            precioVentaFinal:
                (bestMatch['precio_venta'] ?? 0).toDouble(),
            costoUnitarioCalculado:
                (bestMatch['precio_costo'] ?? 0).toDouble(),
            unidadesPorLote: 1,
            unidadesPorVenta: bestMatch['factor_conversion'] ?? 1,
            umpCompra: bestMatch['unidad'] ?? 'Unidad',
            unidadVenta: bestMatch['unidad'] ?? 'Unidad',
            availablePresentations: siblings,
          ),
        );
      } else {
        v.matchPresentacion = MatchResult(
          estado: "NUEVO_EN_PADRE",
          confianza: 0,
          datos: MatchData(
            id: -1,
            nombre: "Nueva Variante",
            availablePresentations: siblings,
          ),
        );
      }
    }
    notifyListeners();
  }

  void unlinkProductGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    if (group.nombreOriginalFactura != null) {
      group.nombrePadre = group.nombreOriginalFactura!;
    }
    group.matchProducto = MatchResult(
      estado: "NUEVO",
      confianza: 0,
      datos: null,
    );
    for (var v in group.variantes) {
      v.matchPresentacion = MatchResult(
        estado: "NUEVO",
        confianza: 0,
        datos: null,
      );
    }
    notifyListeners();
  }

  void switchVariantLink(String variantUuid, int newPresentationId) {
    var variant = _findVariant(variantUuid);
    var currentMatchData = variant?.matchPresentacion.datos;
    if (variant == null ||
        currentMatchData == null ||
        currentMatchData.availablePresentations == null) {
      return;
    }

    var selectedSibling = currentMatchData.availablePresentations!.firstWhere(
      (p) => p['id'] == newPresentationId,
      orElse: () => <String, dynamic>{},
    );
    if (selectedSibling.isEmpty) return;

    variant.matchPresentacion = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: selectedSibling['id'],
        nombre: selectedSibling['nombre_completo'] ??
            selectedSibling['nombre_presentacion'],
        stockActual: selectedSibling['stock_actual'] ?? 0,
        precioVentaFinal:
            (selectedSibling['precio_venta'] ?? 0).toDouble(),
        costoUnitarioCalculado:
            (selectedSibling['precio_costo'] ?? 0).toDouble(),
        unidadesPorVenta: selectedSibling['factor_conversion'] ?? 1,
        unidadVenta: selectedSibling['unidad'] ?? 'Unidad',
        availablePresentations: currentMatchData.availablePresentations,
      ),
    );
    notifyListeners();
  }

  void switchVariantToNew(String variantUuid) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;
    var siblingsBackup =
        variant.matchPresentacion.datos?.availablePresentations;
    variant.matchPresentacion = MatchResult(
      estado: "NUEVO_EN_PADRE",
      confianza: 0,
      datos: MatchData(
        id: -1,
        nombre: "Nueva Variante",
        availablePresentations: siblingsBackup,
      ),
    );
    variant.factorGananciaVentaSugerido = 1.35;
    variant.precioVentaSugerido =
        variant.costoUnitarioSugerido * variant.factorGananciaVentaSugerido;
    notifyListeners();
  }

  void removeVariantByUuid(String variantUuid) {
    if (_stagingData == null) return;
    for (int g = 0; g < _stagingData!.productosAgrupados.length; g++) {
      var group = _stagingData!.productosAgrupados[g];
      int vIndex =
          group.variantes.indexWhere((v) => v.uuidTemporal == variantUuid);
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
    if (group.matchProducto.estado.contains("MATCH") &&
        group.variantes.isNotEmpty) {
      siblings =
          group.variantes.first.matchPresentacion.datos?.availablePresentations;
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
          estado: group.matchProducto.estado.contains("MATCH")
              ? "NUEVO_EN_PADRE"
              : "NUEVO",
          confianza: 0,
          datos: siblings != null
              ? MatchData(
                  id: -1,
                  nombre: "",
                  availablePresentations: siblings,
                )
              : null,
        ),
      ),
    );
    notifyListeners();
  }
}