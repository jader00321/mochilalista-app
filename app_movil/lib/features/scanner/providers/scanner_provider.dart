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
part 'scanner_provider_queue_and_ai.dart';
part 'scanner_provider_matching.dart';
part 'scanner_provider_leftover_and_stock.dart';
part 'scanner_provider_staging.dart';

class ScannerState {
  bool isLoading = false;
  String statusMessage = "";
  AIInvoiceResponse? aiRawData;
  StagingResponse? stagingData;
  File? currentImage;
  bool hasSavedProgress = false;
}

abstract class _ScannerProviderBase with ChangeNotifier {
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
      if (group.modoStock == 'COMPARTIDO') {
        // En modo compartido evaluamos el pozo contra las presentaciones según el Asesor de Stock
        int pool = group.stockCompartido;
        if (pool <= 0) {
          pool = group.variantes.fold<int>(0, (sum, v) => sum + v.stockIngresanteBase);
        }
        final sharedVariants = group.variantes.where((v) => v.isConfirmed).toList();
        if (sharedVariants.isNotEmpty && pool > 0) {
          // Caso C: En TODAS las variantes compartidas pool < factor (déficit total)
          bool allZeroFormable = sharedVariants.every((v) => pool < v.effectiveFactorVenta);
          if (allZeroFormable) {
            count++;
          }
        }
      } else {
        // En modo INDEPENDIENTE o MIXTO (variantes que no usan stock compartido)
        for (var v in group.variantes) {
          if (!v.isConfirmed) continue;
          if (group.modoStock == 'MIXTO' && v.usaStockCompartido) continue;

          int stockBD = v.matchPresentacion.datos?.stockActual ?? 0;
          int totalUnitsBase = v.calculateTotalUnitsBase(stockActualBD: stockBD);
          int factor = v.effectiveFactorVenta;

          if (factor > 1 && totalUnitsBase > 0) {
            int completas = totalUnitsBase ~/ factor;
            int sobrante = totalUnitsBase % factor;

            if (completas == 0) {
              // DÉFICIT REAL: no alcanza para formar siquiera 1 paquete
              count++;
            } else if (sobrante > 0) {
              // SOBRANTE: unidades sueltas que no forman paquetes completos
              count++;
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

  String generateUniqueVariantName(StagingProductGroup group, {required bool isShared});
  bool revertLeftoverToMother(String childVariantUuid);
  void syncGroupSharedPurchaseFromMasterVariant(String groupUuid);
}

class ScannerProvider extends _ScannerProviderBase
    with
        _ScannerProviderQueueAndAiMixin,
        _ScannerProviderMatchingMixin,
        _ScannerProviderLeftoverAndStockMixin,
        _ScannerProviderStagingMixin {}
