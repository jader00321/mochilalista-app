import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/services/image_service.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/features/scanner/services/scanner_ai_service.dart';
import 'package:app_movil/features/scanner/services/scanner_matching_engine.dart';
import 'package:app_movil/features/scanner/services/scanner_batch_saver.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';
import 'package:app_movil/core/services/unit_catalog_service.dart';
import 'package:app_movil/features/scanner/services/scanner_cost_engine.dart';
import 'package:app_movil/features/scanner/models/barcode_resolution_result.dart';
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
class ScannerState {
  bool isLoading = false;
  String statusMessage = "";
  AIInvoiceResponse? aiRawData;
  StagingResponse? stagingData;
  File? currentImage;
  bool hasSavedProgress = false;
}

class ScannerProvider with ChangeNotifier {
  int? _negocioId;
  int? _usuarioId;

  final Map<int, ScannerState> _states = {};

  ScannerState get _currentState {
    final key = _negocioId ?? 0;
    return _states.putIfAbsent(key, () => ScannerState());
  }

  // Servicios especializados
  final _aiService = ScannerAIService();
  final _matchingEngine = ScannerMatchingEngine();
  final _batchSaver = ScannerBatchSaver();
  final _dbHelper = LocalDatabase.instance;

  String? _highlightedGroupUuid;
  String? get highlightedGroupUuid => _highlightedGroupUuid;

  void highlightGroup(String? uuid) {
    _highlightedGroupUuid = uuid;
    notifyListeners();
    if (uuid != null) {
      Timer(const Duration(milliseconds: 2500), () {
        if (_highlightedGroupUuid == uuid) {
          _highlightedGroupUuid = null;
          notifyListeners();
        }
      });
    }
  }

  String? _highlightedVariantUuid;
  String? get highlightedVariantUuid => _highlightedVariantUuid;

  void highlightVariant(String? uuid) {
    _highlightedVariantUuid = uuid;
    notifyListeners();
    if (uuid != null) {
      Timer(const Duration(milliseconds: 2500), () {
        if (_highlightedVariantUuid == uuid) {
          _highlightedVariantUuid = null;
          notifyListeners();
        }
      });
    }
  }

  final Map<String, GlobalKey> _variantKeys = {};
  void registerVariantKey(String uuid, GlobalKey key) {
    _variantKeys[uuid] = key;
  }
  void unregisterVariantKey(String uuid) {
    _variantKeys.remove(uuid);
  }
  GlobalKey? getVariantKey(String uuid) => _variantKeys[uuid];

  void scrollToAndHighlightVariant(String variantUuid) {
    highlightVariant(variantUuid);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _variantKeys[variantUuid];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.25,
        );
      }
    });
  }

  // ==========================================
  // GETTERS
  // ==========================================
  bool get isLoading => _currentState.isLoading;
  String get statusMessage => _currentState.statusMessage;
  AIInvoiceResponse? get aiRawData => _currentState.aiRawData;
  StagingResponse? get stagingData => _currentState.stagingData;
  File? get currentImage => _currentState.currentImage;
  bool get hasSavedProgress => _currentState.hasSavedProgress;

  @visibleForTesting
  void setStagingDataForTesting(StagingResponse staging) {
    _currentState.stagingData = staging;
    notifyListeners();
  }

  int get countNew {
    if (_currentState.stagingData == null) return 0;
    int count = 0;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed && !v.matchPresentacion.estado.contains("MATCH")) {
          count++;
        }
      }
    }
    return count;
  }

  int get countLinked {
    if (_currentState.stagingData == null) return 0;
    int count = 0;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.isConfirmed && v.matchPresentacion.estado.contains("MATCH")) {
          count++;
        }
      }
    }
    return count;
  }

  int get totalActiveVariants {
    if (_currentState.stagingData == null) return 0;
    int count = 0;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      count += group.variantes.where((v) => v.isConfirmed).length;
    }
    return count;
  }

  bool get hasUnresolvedStock => unresolvedStockErrorsCount > 0;

  int get unresolvedStockErrorsCount {
    if (_currentState.stagingData == null) return 0;
    int count = 0;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (!v.isConfirmed) continue;

        int stockBD = v.matchPresentacion.datos?.stockActual ?? 0;
        int totalUnitsBase = v.calculateTotalUnitsBase(stockActualBD: stockBD);
        int factor = v.effectiveFactorVenta;

        if (factor > 1 && totalUnitsBase > 0) {
          int completas = totalUnitsBase ~/ factor;
          int sobrante = totalUnitsBase % factor;

          if (completas == 0) {
            // DÉFICIT REAL: no alcanza para 1 paquete
            if (!v.allowDeficitApproved) {
              count++;
            }
          } else if (sobrante > 0) {
            // SOBRANTE: unidades sueltas que exceden los paquetes completos
            if (!v.allowLeftoverInReserve) {
              int assignedLeftovers = 0;
              for (var other in group.variantes) {
                if (other != v &&
                    other.cantidadUmpComprada == 0 &&
                    other.stockIngresanteOverride != null) {
                  assignedLeftovers += other.stockIngresanteOverride!;
                }
              }
              if (assignedLeftovers < sobrante) {
                count++;
              }
            }
          }
        }
      }
    }
    return count;
  }

  // ==========================================
  // CONTEXTO Y ESTADO
  // ==========================================
  void updateContext(int? negocioId, int? usuarioId, String? aiToken) {
    if (_negocioId != negocioId) {
       _negocioId = negocioId;
       Future.microtask(() {
         notifyListeners(); // Notifica a la UI que cambió el perfil activo
       });
    }
    _usuarioId = usuarioId;
  }

  void clearData() {
    _currentState.aiRawData = null;
    _currentState.stagingData = null;
    _currentState.currentImage = null;
    _currentState.statusMessage = "";
    _currentState.hasSavedProgress = false;
    notifyListeners();
  }

  void saveProgress() {
    if (_currentState.stagingData != null) {
      _currentState.hasSavedProgress = true;
      notifyListeners();
    }
  }

  void notifyUIUpdate() {
    notifyListeners();
  }

  // ==========================================
  // OPERACIONES DE ESCANEO DETERMINISTA (4 SITUACIONES)
  // ==========================================

  /// 🎯 Resuelve de forma determinista un código de barras en SQLite
  /// cubriendo las 4 situaciones reales de inventario para Caja Rápida o Crear Producto.
  Future<BarcodeResolutionResult> resolveBarcodeForQuickSale(String barcode, int negocioId) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) {
      return BarcodeResolutionResult.notFound(barcode, message: "Código vacío");
    }

    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        '''
        ${ProductQueries.fullInventoryQuery}
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        ORDER BY 
          (CASE WHEN pr.codigo_barras = ? THEN 1 ELSE 0 END) DESC,
          pr.es_default DESC,
          pr.orden ASC,
          pr.id ASC
        ''',
        [negocioId, cleanCode, cleanCode, cleanCode],
      );

      if (rows.isEmpty) {
        return BarcodeResolutionResult.notFound(cleanCode);
      }

      // Filtrado estricto: ¿existen variantes que tienen directamente pr.codigo_barras == barcode?
      final matchingVariantRows = rows.where((r) {
        final cb = r['pres_cb']?.toString().trim();
        return cb != null && cb == cleanCode;
      }).toList();

      if (matchingVariantRows.isNotEmpty) {
        // Situación 1 vs Situación 3:
        // Agrupar por producto por si acaso hubiera más de uno
        final targetProductId = matchingVariantRows.first['id'];
        final productSubsetRows = matchingVariantRows
            .where((r) => r['id'] == targetProductId)
            .toList();

        // Ordenar explícitamente: es_default == 1 primero, luego orden ASC, luego pres_id ASC
        productSubsetRows.sort((a, b) {
          final aDefault = a['es_default'] == 1 || a['es_default'] == true ? 0 : 1;
          final bDefault = b['es_default'] == 1 || b['es_default'] == true ? 0 : 1;
          if (aDefault != bDefault) return aDefault.compareTo(bDefault);
          final aOrder = (a['orden'] as num?)?.toInt() ?? 0;
          final bOrder = (b['orden'] as num?)?.toInt() ?? 0;
          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          final aId = (a['pres_id'] as num?)?.toInt() ?? 0;
          final bId = (b['pres_id'] as num?)?.toInt() ?? 0;
          return aId.compareTo(bId);
        });

        final selectedWrapper = ProductQueries.parseInventoryRow(productSubsetRows.first);

        if (productSubsetRows.length == 1) {
          // SITUACIÓN 1 — Una variante específica tiene registrado ese código
          return BarcodeResolutionResult.exactVariant(selectedWrapper, cleanCode);
        } else {
          // SITUACIÓN 3 — Múltiples variantes comparten el código
          return BarcodeResolutionResult.variantSubset(selectedWrapper, cleanCode);
        }
      }

      // Si ninguna variante tiene el código directamente, pero las filas existen porque p.codigo_barras == barcode:
      // SITUACIÓN 2 — Código global o registrado únicamente en el Producto Padre
      final targetProductId = rows.first['id'];
      final parentProductRows = rows.where((r) => r['id'] == targetProductId).toList();
      parentProductRows.sort((a, b) {
        final aDefault = a['es_default'] == 1 || a['es_default'] == true ? 0 : 1;
        final bDefault = b['es_default'] == 1 || b['es_default'] == true ? 0 : 1;
        if (aDefault != bDefault) return aDefault.compareTo(bDefault);
        final aOrder = (a['orden'] as num?)?.toInt() ?? 0;
        final bOrder = (b['orden'] as num?)?.toInt() ?? 0;
        if (aOrder != bOrder) return aOrder.compareTo(bOrder);
        final aId = (a['pres_id'] as num?)?.toInt() ?? 0;
        final bId = (b['pres_id'] as num?)?.toInt() ?? 0;
        return aId.compareTo(bId);
      });

      final selectedWrapper = ProductQueries.parseInventoryRow(parentProductRows.first);
      return BarcodeResolutionResult.parentOrGlobal(selectedWrapper, cleanCode);
    } catch (e, stack) {
      AppLogger.error('ScannerProvider.resolveBarcodeForQuickSale', e, stack);
      return BarcodeResolutionResult.notFound(cleanCode, message: "Error resolviendo código: $e");
    }
  }

  /// Busca un producto por código de barras en la BD local.
  Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    if (_negocioId == null || barcode.trim().isEmpty) return null;

    _currentState.isLoading = true;
    notifyListeners();

    try {
      final resolution = await resolveBarcodeForQuickSale(barcode, _negocioId!);
      if (resolution.isFound && resolution.item != null) {
        return {
          'found': true,
          'product': resolution.item!.product.toJson(),
          'presentation': resolution.item!.presentation.toJson(),
          'wrapper': resolution.item,
          'resolution': resolution,
        };
      } else {
        return {'found': false};
      }
    } catch (e, stack) {
      AppLogger.error('ScannerProvider.scanBarcode', e, stack);
      _currentState.statusMessage = "Error buscando código: $e";
      return null;
    } finally {
      _currentState.isLoading = false;
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
          .map(
            (e) => {
              "id": e["id"],
              "nombre_empresa": e["nombre_empresa"],
              "ruc": e["ruc"],
            },
          )
          .toList();
    } catch (e, stack) {
      AppLogger.error('ScannerProvider.searchProviders', e, stack);
      return [];
    }
  }

  /// Envía la imagen al servicio de IA para análisis.
  /// Delega a [ScannerAIService].
  Future<bool> uploadAndAnalyzeImage(File imageFile) async {
    final activeState = _currentState;
    activeState.isLoading = true;
    activeState.statusMessage = "Analizando con Inteligencia Artificial...";
    activeState.currentImage = imageFile;
    notifyListeners();

    try {
      activeState.aiRawData = await _aiService.analyzeInvoiceImage(
        imageFile,
        onRetrying: (msg) {
          activeState.statusMessage = msg;
          notifyListeners();
        },
      );
      return activeState.aiRawData != null;
    } catch (e) {
      final cleanMsg = e.toString().replaceAll("Exception:", "").trim();
      activeState.statusMessage = cleanMsg;
    } finally {
      activeState.isLoading = false;
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
    if (_currentState.aiRawData != null) {
      _currentState.aiRawData!.items = newItems;
      _currentState.aiRawData!.proveedorDetectado = newProvider;
      _currentState.aiRawData!.rucDetectado = newRuc;
      _currentState.aiRawData!.fechaDetectada = newDate;
      _currentState.aiRawData!.montoTotalFactura = newMontoTotal;
      notifyListeners();
    }
  }

  /// Ejecuta el matching contra la BD local.
  /// Delega a [ScannerMatchingEngine].
  Future<bool> runMatchingProcess() async {
    final activeState = _currentState;
    final activeNegocioId = _negocioId;
    if (activeState.aiRawData == null || activeNegocioId == null) return false;
    activeState.isLoading = true;
    activeState.statusMessage = "Buscando coincidencias locales...";
    notifyListeners();

    try {
      activeState.stagingData = await _matchingEngine.runMatching(
        aiData: activeState.aiRawData!,
        negocioId: activeNegocioId,
      );
      return activeState.stagingData != null;
    } catch (e) {
      activeState.statusMessage = "Error en matching local: $e";
      return false;
    } finally {
      activeState.isLoading = false;
      notifyListeners();
    }
  }

  /// Ejecuta el guardado masivo en la BD.
  /// Delega a [ScannerBatchSaver].
  Future<bool> executeBatchSave() async {
    final activeState = _currentState;
    final activeNegocioId = _negocioId;
    if (activeState.stagingData == null || activeNegocioId == null || _usuarioId == null) {
      return false;
    }
    activeState.isLoading = true;
    activeState.statusMessage = "Guardando inventario local...";
    notifyListeners();

    try {
      String? savedImagePath;
      if (activeState.currentImage != null) {
        savedImagePath = await ImageService.processAndSaveImage(
          activeState.currentImage!.path,
        );
      }

      String? aiRawJson;
      int itemCount = 0;
      if (activeState.aiRawData != null) {
        aiRawJson = jsonEncode(activeState.aiRawData!.toJson());
        itemCount = activeState.aiRawData!.items.length;
      }

      return await _batchSaver.executeBatchSave(
        stagingData: activeState.stagingData!,
        negocioId: activeNegocioId,
        usuarioId: _usuarioId!,
        aiRawJson: aiRawJson,
        imagePath: savedImagePath,
        itemCount: itemCount,
        onProgress: (String message) {
          activeState.statusMessage = message;
          notifyListeners();
        },
      );
    } catch (e) {
      activeState.statusMessage = "Error crítico al guardar localmente: $e";
      return false;
    } finally {
      activeState.isLoading = false;
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
    if (_currentState.stagingData == null) return;
    _currentState.stagingData!.proveedorTexto = nombre;
    if (ruc != null) _currentState.stagingData!.rucProveedor = ruc;
    if (fecha != null) _currentState.stagingData!.fechaFactura = fecha;

    if (idExistente != null) {
      _currentState.stagingData!.proveedorMatch = MatchResult(
        estado: "MATCH_MANUAL",
        confianza: 100,
        datos: MatchData(id: idExistente, nombre: nombre),
      );
    } else {
      _currentState.stagingData!.proveedorMatch = MatchResult(
        estado: "NUEVO",
        confianza: 0,
        datos: null,
      );
    }
    notifyListeners();
  }

  void addNewProductGroup() {
    if (_currentState.stagingData == null) return;
    final newGroup = StagingProductGroup(
      nombrePadre: "",
      marcaOriginalFactura: "",
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
    _currentState.stagingData!.productosAgrupados.add(newGroup);
    notifyListeners();
  }

  // --- Helpers de búsqueda interna ---
  StagingProductGroup? _findGroup(String uuid) {
    try {
      return _currentState.stagingData?.productosAgrupados.firstWhere(
        (g) => g.uuidTemporal == uuid,
      );
    } catch (_) {
      return null;
    }
  }

  StagingVariant? _findVariant(String uuid) {
    if (_currentState.stagingData == null) return null;
    for (var g in _currentState.stagingData!.productosAgrupados) {
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
    List<Map<String, dynamic>> siblings, {
    int? selectedPresentationId,
  }) {
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
        availablePresentations: siblings,
      ),
    );
    group.nombrePadre = product['nombre'];
    group.marcaTexto = product['marca_nombre'] ?? "Genérica";

    bool isFirstVariant = true;

    for (var v in group.variantes) {
      String invoiceName = v.nombreEspecifico.toLowerCase().trim();

      Map<String, dynamic>? bestMatch;
      double highestScore = -1;

      if (isFirstVariant && selectedPresentationId != null) {
        bestMatch = siblings.firstWhere(
          (s) => s['id'] == selectedPresentationId,
          orElse: () => <String, dynamic>{},
        );
        if (bestMatch.isEmpty) bestMatch = null;
        if (bestMatch != null) highestScore = 100.0; // Alto score para bypass
      } else {
        int factorToMatch = UnitCatalogService.resolveUnit(v.unidadVenta)?.factor ?? 1;

        for (var s in siblings) {
          String sName = (s['nombre_especifico'] ?? "").toLowerCase().trim();
          int sFactor = s['factor_conversion'] as int? ?? 1;

          double score = SpanishLemmatizer.calculateSimilarity(
            invoiceName,
            sName,
          );
          
          // Boost based on factor matching
          if (factorToMatch == sFactor && factorToMatch > 1) {
            score += 2.0; // Perfect match por factor (asegura superar cualquier similitud de texto que maximo es 1.0)
          } else if (factorToMatch == sFactor && factorToMatch == 1) {
            score += 0.5; // Ligero boost para unidades sueltas
          }

          if (score > highestScore) {
            highestScore = score;
            bestMatch = s;
          }
        }
      }

      if (bestMatch != null && highestScore > 0.5) {
        v.matchPresentacion = MatchResult(
          estado: "MATCH_MANUAL",
          confianza: 100,
          datos: MatchData(
            id: bestMatch['id'],
            nombre: bestMatch['nombre_especifico'] ?? "General",
            stockActual: bestMatch['stock_actual'] ?? 0,
            precioVentaFinal: (bestMatch['precio_venta'] ?? 0).toDouble(),
            costoUnitarioCalculado: (bestMatch['precio_costo'] ?? 0).toDouble(),
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
      isFirstVariant = false;
    }
    notifyListeners();
  }

  String _cleanAndCapitalizeName(
    String original,
    String brand,
    List<StagingVariant> variants,
  ) {
    String cleaned = original.toLowerCase();

    if (brand.isNotEmpty && brand.toLowerCase() != "genérica") {
      cleaned = cleaned.replaceAll(brand.toLowerCase(), "");
    }

    for (var v in variants) {
      String vName = v.nombreEspecifico.toLowerCase();
      if (vName.isNotEmpty && vName != "general") {
        cleaned = cleaned.replaceAll(vName, "");
      }
    }

    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (cleaned.isEmpty) return original; // fallback
    List<String> words = cleaned.split(" ");
    return words
        .map((w) {
          if (w.isEmpty) return "";
          return w[0].toUpperCase() + w.substring(1);
        })
        .join(" ");
  }

  void unlinkProductGroup(String groupUuid) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    if (group.nombreOriginalFactura != null) {
      group.marcaTexto = group.marcaOriginalFactura ?? "";
      group.nombrePadre = _cleanAndCapitalizeName(
        group.nombreOriginalFactura!,
        group.marcaTexto,
        group.variantes,
      );
    }
    group.matchProducto = MatchResult(
      estado: "NUEVO",
      confianza: 0,
      datos: null,
    );
    group.matchMarca = MatchResult(estado: "NUEVO", confianza: 0, datos: null);
    group.categoriaSugeridaId = null;
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
    StagingVariant? variant;
    StagingProductGroup? parentGroup;

    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      int idx = group.variantes.indexWhere(
        (v) => v.uuidTemporal == variantUuid,
      );
      if (idx != -1) {
        variant = group.variantes[idx];
        parentGroup = group;
        break;
      }
    }

    if (variant == null || parentGroup == null) return;

    var availablePresentations =
        parentGroup.matchProducto.datos?.availablePresentations;
    if (availablePresentations == null || availablePresentations.isEmpty) {
      return;
    }

    var selectedSibling = availablePresentations.firstWhere(
      (p) => p['id'] == newPresentationId,
      orElse: () => <String, dynamic>{},
    );
    if (selectedSibling.isEmpty) return;

    variant.matchPresentacion = MatchResult(
      estado: "MATCH_MANUAL",
      confianza: 100,
      datos: MatchData(
        id: selectedSibling['id'],
        nombre: selectedSibling['nombre_especifico'] ?? "General",
        stockActual: selectedSibling['stock_actual'] ?? 0,
        precioVentaFinal: (selectedSibling['precio_venta'] ?? 0).toDouble(),
        costoUnitarioCalculado: (selectedSibling['precio_costo'] ?? 0)
            .toDouble(),
        unidadesPorVenta: selectedSibling['factor_conversion'] ?? 1,
        unidadVenta: selectedSibling['unidad'] ?? 'Unidad',
        umpCompra:
            selectedSibling['ump_compra'] ??
            selectedSibling['unidad'] ??
            'Unidad',
        availablePresentations: availablePresentations,
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

  String? createLeftoverVariant(String sourceVariantUuid, int leftoverAmount) {
    if (_currentState.stagingData == null) return null;
    StagingVariant? sourceVariant;
    StagingProductGroup? parentGroup;

    for (var group in _currentState.stagingData!.productosAgrupados) {
      int idx = group.variantes.indexWhere((v) => v.uuidTemporal == sourceVariantUuid);
      if (idx != -1) {
        sourceVariant = group.variantes[idx];
        parentGroup = group;
        break;
      }
    }

    if (sourceVariant == null || parentGroup == null) return null;

    int factor = sourceVariant.effectiveFactorVenta;
    int currentIngresoBase = sourceVariant.stockIngresanteOverride ??
        (sourceVariant.cantidadUmpComprada * sourceVariant.unidadesPorLote).toInt();

    // Precisión Técnica: El nuevo ingreso base de la madre disminuye exactamente en leftoverAmount
    int nuevoIngresoPrincipal = max(0, currentIngresoBase - leftoverAmount);
    sourceVariant.stockIngresanteOverride = nuevoIngresoPrincipal;
    sourceVariant.allowLeftoverInReserve = false;
    sourceVariant.allowDeficitApproved = false;

    // Calcular costo unitario base del lote actual
    double costoBase = 0.0;
    if (currentIngresoBase > 0) {
      costoBase = sourceVariant.totalPagoLote / currentIngresoBase;
    } else if (sourceVariant.costoUnitarioSugerido > 0) {
      costoBase = sourceVariant.costoUnitarioSugerido / max(1, factor);
    }

    double totalPagoSobrante = leftoverAmount * costoBase;
    if (totalPagoSobrante > sourceVariant.totalPagoLote) {
      totalPagoSobrante = sourceVariant.totalPagoLote;
    }

    // Descontar proporcionalmente el pago del lote de la madre para mantener la ecuación total
    sourceVariant.totalPagoLote = max(0.0, sourceVariant.totalPagoLote - totalPagoSobrante);
    if (sourceVariant.unidadesPorLote > 0) {
      sourceVariant.cantidadUmpComprada = nuevoIngresoPrincipal / sourceVariant.unidadesPorLote;
    }
    if (nuevoIngresoPrincipal > 0) {
      double newMotherUnitCost = sourceVariant.totalPagoLote / nuevoIngresoPrincipal;
      sourceVariant.costoUnitarioSugerido = newMotherUnitCost * factor;
      sourceVariant.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
        presentationCost: sourceVariant.costoUnitarioSugerido,
        marginFactor: sourceVariant.factorGananciaVentaSugerido,
      );
    }

    double margen = sourceVariant.factorGananciaVentaSugerido > 0
        ? sourceVariant.factorGananciaVentaSugerido
        : 1.35;
    double pVentaSugerido = ScannerCostEngine.suggestSalePrice(
      presentationCost: costoBase,
      marginFactor: margen,
    );

    // Verificar si en el parentGroup ya existe una variante con factor 1 (Unidad)
    StagingVariant? existingUnitVariant = parentGroup.variantes
        .where((v) => v != sourceVariant && v.effectiveFactorVenta == 1)
        .firstOrNull;

    String resultingUuid;

    if (existingUnitVariant != null) {
      // Sumar al ingreso de la variante unitaria existente
      int prevOverride = existingUnitVariant.stockIngresanteOverride ??
          (existingUnitVariant.cantidadUmpComprada * existingUnitVariant.unidadesPorLote).toInt();
      existingUnitVariant.stockIngresanteOverride = prevOverride + leftoverAmount;
      existingUnitVariant.allocatedBaseUnits = (existingUnitVariant.allocatedBaseUnits ?? 0) + leftoverAmount;
      existingUnitVariant.allocatedPurchaseCost = (existingUnitVariant.allocatedPurchaseCost ?? 0.0) + totalPagoSobrante;
      existingUnitVariant.cantidadUmpComprada = existingUnitVariant.cantidadUmpComprada + leftoverAmount.toDouble();
      existingUnitVariant.totalPagoLote = existingUnitVariant.totalPagoLote + totalPagoSobrante;
      existingUnitVariant.precioUmpProveedor = costoBase;
      existingUnitVariant.costoUnitarioSugerido = costoBase;
      existingUnitVariant.factorGananciaVentaSugerido = margen;
      existingUnitVariant.precioVentaSugerido = pVentaSugerido;
      existingUnitVariant.sourceVariantUuid = sourceVariantUuid;
      existingUnitVariant.updateUnidadVenta = true;
      resultingUuid = existingUnitVariant.uuidTemporal;
    } else {
      // Crear nueva variante 'Unidad (x1)'
      String nombreHeredado = sourceVariant.nombreEspecifico.trim();
      String newName = (nombreHeredado.isNotEmpty && nombreHeredado != "General")
          ? "$nombreHeredado - Unidad"
          : "Unidad (x1)";

      StagingVariant leftoverVariant = StagingVariant(
        nombreEspecifico: newName,
        umpCompra: "Unidad",
        cantidadUmpComprada: leftoverAmount.toDouble(),
        precioUmpProveedor: costoBase,
        totalPagoLote: totalPagoSobrante,
        unidadesPorLote: 1,
        unidadVenta: "Unidad",
        unidadesPorVenta: 1,
        costoUnitarioSugerido: costoBase,
        factorGananciaVentaSugerido: margen,
        precioVentaSugerido: pVentaSugerido,
        matchPresentacion: MatchResult(
          estado: "NUEVO_EN_PADRE",
          confianza: 0,
          datos: MatchData(
            id: -1,
            nombre: newName,
            availablePresentations: sourceVariant.matchPresentacion.datos?.availablePresentations,
            unidadVenta: "Unidad",
            unidadesPorVenta: 1,
          ),
        ),
      );
      leftoverVariant.stockIngresanteOverride = leftoverAmount;
      leftoverVariant.sourceVariantUuid = sourceVariantUuid;
      leftoverVariant.allocatedBaseUnits = leftoverAmount;
      leftoverVariant.allocatedPurchaseCost = totalPagoSobrante;
      leftoverVariant.updateUnidadVenta = true;
      leftoverVariant.updateCosto = true;
      leftoverVariant.updatePrecio = true;

      int parentIndex = parentGroup.variantes.indexOf(sourceVariant);
      parentGroup.variantes.insert(parentIndex + 1, leftoverVariant);
      resultingUuid = leftoverVariant.uuidTemporal;
    }

    notifyListeners();
    return resultingUuid;
  }

  /// Revierte los fondos y unidades transferidas desde una variante hija hacia su variante madre
  bool revertLeftoverToMother(String childVariantUuid) {
    if (_currentState.stagingData == null) return false;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      int cIdx = group.variantes.indexWhere((v) => v.uuidTemporal == childVariantUuid);
      if (cIdx != -1) {
        final child = group.variantes[cIdx];
        if (child.sourceVariantUuid != null) {
          final mother = group.variantes
              .where((v) => v.uuidTemporal == child.sourceVariantUuid)
              .firstOrNull;
          if (mother != null) {
            final int unitsToRestore = child.allocatedBaseUnits ?? child.stockIngresanteBase;
            final double costToRestore = child.allocatedPurchaseCost ?? child.totalPagoLote;

            final int motherIngresoActual = mother.stockIngresanteOverride ?? mother.stockIngresanteBase;
            final int motherNewIngreso = motherIngresoActual + unitsToRestore;
            mother.stockIngresanteOverride = motherNewIngreso;
            mother.totalPagoLote = mother.totalPagoLote + costToRestore;
            if (mother.unidadesPorLote > 0) {
              mother.cantidadUmpComprada = motherNewIngreso / mother.unidadesPorLote;
            }
            if (motherNewIngreso > 0) {
              double unitCost = mother.totalPagoLote / motherNewIngreso;
              mother.costoUnitarioSugerido = unitCost * mother.effectiveFactorVenta;
              mother.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
                presentationCost: mother.costoUnitarioSugerido,
                marginFactor: mother.factorGananciaVentaSugerido,
              );
            }
            // Reset flags so leftover alert re-evaluates immediately!
            mother.allowLeftoverInReserve = false;
            mother.allowDeficitApproved = false;

            return true;
          }
        }
      }
    }
    return false;
  }

  /// Activa la estrategia de Stock Compartido (Pool único) para el grupo
  void activateSharedStockForGroup(String groupUuid, [String? variantUuid]) {
    var group = _findGroup(groupUuid);
    if (group == null) return;

    // 1. Cambiar el grupo a modo COMPARTIDO
    group.modoStock = 'COMPARTIDO';

    // 2. Marcar todas las variantes del grupo con usaStockCompartido = true
    for (var v in group.variantes) {
      v.usaStockCompartido = true;
    }

    // 3. Calcular unidades totales del pool en unidades base sin descontar nada
    int totalPoolUnits = 0;
    double totalPoolCost = 0.0;
    for (var v in group.variantes) {
      int baseUnits = v.stockIngresanteOverride ?? (v.cantidadUmpComprada * v.unidadesPorLote).toInt();
      totalPoolUnits += baseUnits;
      totalPoolCost += v.totalPagoLote;
    }
    if (group.matchProducto.estado.contains("MATCH")) {
      totalPoolUnits += group.matchProducto.datos?.stockActual ?? 0;
    }
    group.stockCompartido = totalPoolUnits;
    if (totalPoolUnits > 0) {
      group.costoBase = totalPoolCost / totalPoolUnits;
    }

    // 4. Regla 2: Verificar si el producto ya tiene variante con Factor = 1 ('Unidad')
    bool hasUnitVariant = group.variantes.any((v) => v.effectiveFactorVenta == 1);
    if (!hasUnitVariant) {
      final available = group.matchProducto.datos?.availablePresentations ?? [];
      var dbUnit = available
          .where((p) => (p['factor_conversion'] == 1 || p['factor_conversion'] == null))
          .firstOrNull;

      double baseCost = group.costoBase > 0 ? group.costoBase :
        (group.variantes.isNotEmpty && group.variantes.first.effectiveFactorVenta > 0
          ? group.variantes.first.costoUnitarioSugerido / group.variantes.first.effectiveFactorVenta
          : 0.0);
      double margen = group.variantes.isNotEmpty ? group.variantes.first.factorGananciaVentaSugerido : 1.35;
      double pVenta = ScannerCostEngine.suggestSalePrice(presentationCost: baseCost, marginFactor: margen);

      StagingVariant unitVariant = StagingVariant(
        nombreEspecifico: dbUnit != null ? (dbUnit['nombre_especifico'] ?? 'Unidad (x1)') : 'Unidad (x1)',
        umpCompra: 'UND',
        cantidadUmpComprada: 0,
        precioUmpProveedor: baseCost,
        totalPagoLote: 0.0,
        unidadesPorLote: 1,
        unidadVenta: dbUnit != null ? (dbUnit['unidad'] ?? 'Unidad') : 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: baseCost,
        factorGananciaVentaSugerido: margen,
        precioVentaSugerido: dbUnit != null && dbUnit['precio_venta'] != null
            ? (dbUnit['precio_venta'] as num).toDouble()
            : pVenta,
        matchPresentacion: dbUnit != null
            ? MatchResult(
                estado: "MATCH_SUGERIDO",
                confianza: 95,
                datos: MatchData(
                  id: dbUnit['id'] as int,
                  nombre: dbUnit['nombre_especifico'] as String? ?? 'Unidad (x1)',
                  stockActual: dbUnit['stock_actual'] as int? ?? totalPoolUnits,
                  precioVentaFinal: (dbUnit['precio_venta'] as num?)?.toDouble() ?? pVenta,
                  costoUnitarioCalculado: (dbUnit['precio_costo'] as num?)?.toDouble() ?? baseCost,
                  unidadVenta: dbUnit['unidad'] as String? ?? 'Unidad',
                  unidadesPorVenta: 1,
                  availablePresentations: available,
                  usaStockCompartido: true,
                ),
              )
            : MatchResult(
                estado: group.matchProducto.estado.contains("MATCH") ? "NUEVO_EN_PADRE" : "NUEVO",
                confianza: 0,
                datos: MatchData(id: -1, nombre: 'Unidad (x1)', availablePresentations: available, usaStockCompartido: true),
              ),
      )..usaStockCompartido = true;

      group.variantes.add(unitVariant);
    }

    notifyListeners();
  }

  /// Cambia la estrategia de stock del grupo ('COMPARTIDO', 'INDEPENDIENTE', 'MIXTO')
  void setGroupStockStrategy(String groupUuid, String modoStock) {
    var group = _findGroup(groupUuid);
    if (group == null) return;
    group.modoStock = modoStock;
    if (modoStock == 'COMPARTIDO') {
      for (var v in group.variantes) {
        v.usaStockCompartido = true;
      }
    } else if (modoStock == 'INDEPENDIENTE') {
      for (var v in group.variantes) {
        v.usaStockCompartido = false;
      }
    }
    notifyListeners();
  }

  /// Alterna el flag usaStockCompartido para una variante individual (Modo Mixto)
  void toggleVariantSharedStock(String variantUuid) {
    var variant = _findVariant(variantUuid);
    if (variant == null) return;
    variant.usaStockCompartido = !variant.usaStockCompartido;
    notifyListeners();
  }

  /// Autoriza conservar el sobrante en la reserva base de la variante
  void authorizeLeftoverInReserve(String variantUuid) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          v.allowLeftoverInReserve = true;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Autoriza registrar la presentación en 0 disponibles (acumulación)
  void authorizeDeficitRegistration(String variantUuid) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          v.allowDeficitApproved = true;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Adapta la unidad de venta y factor de una variante en 1 toque
  void adaptVariantUnit(String variantUuid, [String unitName = "Unidad", int factor = 1]) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          v.unidadVenta = unitName;
          v.unidadesPorVenta = factor;
          v.updateUnidadVenta = true;
          double costoBase = (v.cantidadUmpComprada > 0 && v.unidadesPorLote > 0)
              ? v.totalPagoLote / (v.cantidadUmpComprada * v.unidadesPorLote)
              : v.costoUnitarioSugerido / v.effectiveFactorVenta;
          v.costoUnitarioSugerido = costoBase * factor;
          v.precioVentaSugerido = v.costoUnitarioSugerido * v.factorGananciaVentaSugerido;
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Completa el ingreso de factura para alcanzar al menos 1 presentación
  void completeBatchToFullPackage(String variantUuid, [int? unitsNeeded]) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (v.uuidTemporal == variantUuid) {
          int stockBD = v.matchPresentacion.datos?.stockActual ?? 0;
          int factor = v.effectiveFactorVenta;
          int totalBase = v.calculateTotalUnitsBase(stockActualBD: stockBD);
          int needed = unitsNeeded ?? (factor > totalBase ? factor - totalBase : 0);
          if (needed > 0) {
            int currentIngreso = v.stockIngresanteBase;
            v.stockIngresanteOverride = currentIngreso + needed;
            notifyListeners();
          }
          return;
        }
      }
    }
  }

  void removeLeftoverVariantForSource(String sourceVariantUuid) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      if (group.variantes.any((v) => v.uuidTemporal == sourceVariantUuid)) {
        var leftovers = group.variantes.where((v) => v.sourceVariantUuid == sourceVariantUuid).toList();
        for (var child in leftovers) {
          revertLeftoverToMother(child.uuidTemporal);
        }
        group.variantes.removeWhere((v) => v.sourceVariantUuid == sourceVariantUuid);
        notifyListeners();
        break;
      }
    }
  }

  void adoptDbUnitForVariant(String variantUuid) {
    if (_currentState.stagingData == null) return;
    var variant = _findVariant(variantUuid);
    if (variant == null) return;

    var dbData = variant.matchPresentacion.datos;
    if (dbData == null) return;

    variant.unidadVenta = dbData.unidadVenta;
    variant.unidadesPorVenta = dbData.unidadesPorVenta;

    int totalUnidadesBase = variant.stockIngresanteOverride ?? (variant.cantidadUmpComprada * variant.unidadesPorLote).toInt();
    double costoBaseIndiv = 0.0;
    if (totalUnidadesBase > 0) {
      costoBaseIndiv = variant.totalPagoLote / totalUnidadesBase;
    }

    variant.costoUnitarioSugerido = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoBaseIndiv,
      unidadesPorVenta: variant.unidadesPorVenta,
    );

    variant.precioVentaSugerido = ScannerCostEngine.suggestSalePrice(
      presentationCost: variant.costoUnitarioSugerido,
      marginFactor: variant.factorGananciaVentaSugerido,
    );
    notifyListeners();
  }

  void removeVariantByUuid(String variantUuid) {
    if (_currentState.stagingData == null) return;
    for (int g = 0; g < _currentState.stagingData!.productosAgrupados.length; g++) {
      var group = _currentState.stagingData!.productosAgrupados[g];
      int vIndex = group.variantes.indexWhere(
        (v) => v.uuidTemporal == variantUuid,
      );
      if (vIndex != -1) {
        final variantToRemove = group.variantes[vIndex];
        if (variantToRemove.sourceVariantUuid != null) {
          revertLeftoverToMother(variantUuid);
        }
        group.variantes.removeAt(vIndex);
        if (group.variantes.isEmpty) {
          _currentState.stagingData!.productosAgrupados.removeAt(g);
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
              ? MatchData(id: -1, nombre: "", availablePresentations: siblings)
              : null,
        ),
      ),
    );
    notifyListeners();
  }


}
