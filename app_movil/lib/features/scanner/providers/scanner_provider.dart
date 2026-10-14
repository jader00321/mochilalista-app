import 'dart:io';
import 'dart:convert';
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

  // ==========================================
  // GETTERS
  // ==========================================
  bool get isLoading => _currentState.isLoading;
  String get statusMessage => _currentState.statusMessage;
  AIInvoiceResponse? get aiRawData => _currentState.aiRawData;
  StagingResponse? get stagingData => _currentState.stagingData;
  File? get currentImage => _currentState.currentImage;
  bool get hasSavedProgress => _currentState.hasSavedProgress;

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

  bool get hasUnresolvedStock {
    if (_currentState.stagingData == null) return false;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      for (var v in group.variantes) {
        if (!v.isConfirmed) continue;

        int totalUnidadesBase = v.stockIngresanteOverride ?? (v.cantidadUmpComprada * v.unidadesPorLote).toInt();
        double costoBaseIndiv = 0.0;
        if (v.cantidadUmpComprada > 0 && v.unidadesPorLote > 0) {
          costoBaseIndiv =
              v.totalPagoLote / (v.cantidadUmpComprada * v.unidadesPorLote);
        }

        var validation = UnitCatalogService.validateStockForUnit(
          totalUnitsBase: totalUnidadesBase,
          presentationFactor: v.unidadesPorVenta,
          baseUnitCost: costoBaseIndiv,
          unitName: v.unidadVenta,
        );

        if (validation.status == StockValidationStatus.deficit) {
          return true;
        }

        if (validation.status == StockValidationStatus.hasLeftover) {
          int assignedLeftovers = 0;
          for (var other in group.variantes) {
            if (other != v &&
                other.cantidadUmpComprada == 0 &&
                other.stockIngresanteOverride != null) {
              assignedLeftovers += other.stockIngresanteOverride!;
            }
          }
          if (assignedLeftovers < validation.leftover) {
            return true;
          }
        }
      }
    }
    return false;
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
  // OPERACIONES DE ESCANEO (Delegadas a servicios)
  // ==========================================

  /// Busca un producto por código de barras en la BD local.
  Future<Map<String, dynamic>?> scanBarcode(String barcode) async {
    if (_negocioId == null || barcode.trim().isEmpty) return null;

    _currentState.isLoading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        '''
        ${ProductQueries.fullInventoryQuery}
        AND (pr.codigo_barras = ? OR p.codigo_barras = ?)
        LIMIT 1
      ''',
        [_negocioId, barcode.trim(), barcode.trim()],
      );

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

  void createLeftoverVariant(String sourceVariantUuid, int leftoverAmount) {
    if (_currentState.stagingData == null) return;
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

    if (sourceVariant == null || parentGroup == null) return;

    double costoBase = 0.0;
    if (sourceVariant.cantidadUmpComprada > 0 && sourceVariant.unidadesPorLote > 0) {
      costoBase = sourceVariant.totalPagoLote / (sourceVariant.cantidadUmpComprada * sourceVariant.unidadesPorLote);
    }

    String nombreHeredado = sourceVariant.nombreEspecifico.trim();
    String newName = nombreHeredado.isNotEmpty ? "$nombreHeredado - Suelta" : "Suelta";

    StagingVariant leftoverVariant = StagingVariant(
      nombreEspecifico: newName,
      umpCompra: "Unidad",
      cantidadUmpComprada: 0, // No suma al costo total de la factura
      precioUmpProveedor: 0,
      totalPagoLote: 0,
      unidadesPorLote: 1, // Ya que es unitario
      unidadVenta: "Unidad",
      unidadesPorVenta: 1,
      costoUnitarioSugerido: costoBase,
      factorGananciaVentaSugerido: 1.35,
      precioVentaSugerido: costoBase * 1.35,
      matchPresentacion: MatchResult(
        estado: "NUEVO_EN_PADRE",
        confianza: 0,
        datos: MatchData(
          id: -1,
          nombre: newName,
          availablePresentations: sourceVariant.matchPresentacion.datos?.availablePresentations,
        )
      ),
    );
    leftoverVariant.stockIngresanteOverride = leftoverAmount;
    leftoverVariant.sourceVariantUuid = sourceVariantUuid; // Relacionar el sobrante con su variante padre

    // Restar el sobrante de la variante principal
    int totalUnitsBase = sourceVariant.stockIngresanteOverride ?? (sourceVariant.cantidadUmpComprada * sourceVariant.unidadesPorLote).toInt();
    sourceVariant.stockIngresanteOverride = totalUnitsBase - leftoverAmount;

    int parentIndex = parentGroup.variantes.indexOf(sourceVariant);
    parentGroup.variantes.insert(parentIndex + 1, leftoverVariant);
    notifyListeners();
  }

  void removeLeftoverVariantForSource(String sourceVariantUuid) {
    if (_currentState.stagingData == null) return;
    for (var group in _currentState.stagingData!.productosAgrupados) {
      if (group.variantes.any((v) => v.uuidTemporal == sourceVariantUuid)) {
        
        // 1. Identificar las variantes sobrantes y sumar sus unidades
        var leftovers = group.variantes.where((v) => v.sourceVariantUuid == sourceVariantUuid).toList();
        if (leftovers.isNotEmpty) {
          int unitsToRestore = leftovers.fold(0, (sum, v) => sum + (v.stockIngresanteOverride ?? 0));
          
          // 2. Encontrar la variante madre y devolverle el stock restado
          try {
            var mother = group.variantes.firstWhere((v) => v.uuidTemporal == sourceVariantUuid);
            if (mother.stockIngresanteOverride != null) {
              mother.stockIngresanteOverride = mother.stockIngresanteOverride! + unitsToRestore;
            }
          } catch (e) {
            // Ignorar si la madre no existe
          }
        }
        
        // 3. Eliminar los sobrantes
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
