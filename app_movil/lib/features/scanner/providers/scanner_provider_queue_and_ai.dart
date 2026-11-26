part of 'scanner_provider.dart';

mixin _ScannerProviderQueueAndAiMixin on _ScannerProviderBase {
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
}
