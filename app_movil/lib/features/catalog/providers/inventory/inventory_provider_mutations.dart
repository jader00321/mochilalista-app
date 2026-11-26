part of '../inventory_provider.dart';

mixin _InventoryProviderMutationsMixin on _InventoryProviderBase {
  Future<bool> deleteProduct(int id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final bool ok = await _productService.deleteProduct(id);
      if (ok) {
        _inventoryItems.removeWhere((w) => w.product.id == id);
      }
      return ok;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createFullProduct({
    required String nombre,
    int? marcaId,
    String? deferredBrandName,
    int? categoriaId,
    String? deferredCategoryName,
    int? proveedorId,
    String? deferredProviderName,
    required String estado,
    String? descripcion,
    String? imagenUrl,
    String? codigoBarras,
    required List<ProductPresentation> presentaciones,
    String modoStock = 'INDEPENDIENTE',
    int stockCompartido = 0,
    double costoBase = 0.0,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final bool ok = await _productService.createFullProduct(
        nombre: nombre,
        marcaId: marcaId,
        deferredBrandName: deferredBrandName,
        categoriaId: categoriaId,
        deferredCategoryName: deferredCategoryName,
        proveedorId: proveedorId,
        deferredProviderName: deferredProviderName,
        estado: estado,
        descripcion: descripcion,
        imagenUrl: imagenUrl,
        codigoBarras: codigoBarras,
        presentaciones: presentaciones,
        modoStock: modoStock,
        stockCompartido: stockCompartido,
        costoBase: costoBase,
      );
      if (ok) {
        _errorMessage = '';
        _masterDataCache.clearCache();
        await loadMasterData(showAll: true);
        await loadInventory(reset: true);
      } else {
        _errorMessage =
            _productService.lastError ?? "Error al registrar el producto";
      }
      return ok;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> editFullProduct({
    required int productId,
    required String nombre,
    int? marcaId,
    String? deferredBrandName,
    int? categoriaId,
    String? deferredCategoryName,
    int? proveedorId,
    String? deferredProviderName,
    required String estado,
    String? descripcion,
    String? imagenUrl,
    String? codigoBarras,
    required List<ProductPresentation> presentaciones,
    required List<int> idsToDelete,
    String? modoStock,
    int? stockCompartido,
    double? costoBase,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final bool ok = await _productService.editFullProduct(
        productId: productId,
        nombre: nombre,
        marcaId: marcaId,
        deferredBrandName: deferredBrandName,
        categoriaId: categoriaId,
        deferredCategoryName: deferredCategoryName,
        proveedorId: proveedorId,
        deferredProviderName: deferredProviderName,
        estado: estado,
        descripcion: descripcion,
        imagenUrl: imagenUrl,
        codigoBarras: codigoBarras,
        presentaciones: presentaciones,
        idsToDelete: idsToDelete,
        modoStock: modoStock,
        stockCompartido: stockCompartido,
        costoBase: costoBase,
      );
      if (ok) {
        _errorMessage = '';
        _masterDataCache.clearCache();
        await loadMasterData(showAll: true);
        await loadInventory(reset: true);
      } else {
        _errorMessage =
            _productService.lastError ?? "Error al actualizar el producto";
      }
      return ok;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retira una variante cortada en SQLite de forma atómica y actualiza catálogos a 0ms
  Future<bool> cutVariantFromProduct({
    required int presentationId,
    required int originProductId,
    int? promoteToDefaultPresentationId,
    String? transferredBarcode,
    int transferredStock = 0,
    int transferredBaseUnits = 0,
    bool isSharedVariant = false,
    bool shouldDeductSharedPool = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final ok = await _productService.cutVariantFromProduct(
        presentationId: presentationId,
        originProductId: originProductId,
        promoteToDefaultPresentationId: promoteToDefaultPresentationId,
        transferredBarcode: transferredBarcode,
        transferredStock: transferredStock,
        transferredBaseUnits: transferredBaseUnits,
        isSharedVariant: isSharedVariant,
        shouldDeductSharedPool: shouldDeductSharedPool,
      );
      if (ok) {
        _errorMessage = '';
        _masterDataCache.clearCache();
        await loadMasterData(showAll: true);
        await loadInventory(reset: true);
      } else {
        _errorMessage =
            _productService.lastError ?? "Error al trasladar la variante";
      }
      return ok;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePresentation(
    int presentationId, {
    String? umpCompra,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    int? cupoMaximoVariante,
    bool clearCupo = false,
    String? estado,
    String? imagenUrl,
  }) async {
    final Map<String, dynamic> body = {};
    if (umpCompra != null) body['ump_compra'] = umpCompra;
    if (precioUmpProveedor != null) {
      body['precio_ump_proveedor'] = precioUmpProveedor;
    }
    if (cantidadUmpComprada != null) {
      body['cantidad_ump_comprada'] = cantidadUmpComprada;
    }
    if (totalPagoLote != null) body['total_pago_lote'] = totalPagoLote;
    if (unidadesPorLote != null) body['unidades_por_lote'] = unidadesPorLote;

    if (unidadVenta != null) body['unidad_venta'] = unidadVenta;
    if (unidadesPorVenta != null) body['unidades_por_venta'] = unidadesPorVenta;

    if (costoUnitarioCalculado != null) {
      body['costo_unitario_calculado'] = costoUnitarioCalculado;
    }
    if (factorGananciaVenta != null) {
      body['factor_ganancia_venta'] = factorGananciaVenta;
    }
    if (precioVentaFinal != null) body['precio_venta_final'] = precioVentaFinal;

    if (oferta != null) {
      if (oferta == -1) {
        body['precio_oferta'] = null;
        body['tipo_descuento'] = null;
        body['valor_descuento'] = null;
      } else {
        body['precio_oferta'] = oferta;
        if (oferta > 0) {
          body['tipo_descuento'] = tipoDesc;
          body['valor_descuento'] = valorDesc;
        }
      }
    }
    if (stock != null) body['stock_actual'] = stock;
    if (clearCupo) {
      body['cupo_maximo_variante'] = null;
    } else if (cupoMaximoVariante != null) {
      body['cupo_maximo_variante'] = cupoMaximoVariante;
    }
    if (estado != null) body['estado'] = estado;

    if (imagenUrl != null) {
      final oldIndex = _inventoryItems.indexWhere(
        (wrapper) => wrapper.presentation.id == presentationId,
      );
      final String? oldPath = oldIndex != -1
          ? _inventoryItems[oldIndex].presentation.imagenUrl
          : null;
      body['imagen_url'] = await ImageService.processAndSaveImage(
        imagenUrl,
        oldImagePath: oldPath,
      );
    }

    final bool ok = await _productService.updatePresentation(
      presentationId,
      body,
    );
    if (ok) {
      final index = _inventoryItems.indexWhere(
        (wrapper) => wrapper.presentation.id == presentationId,
      );
      if (index != -1) {
        final oldPres = _inventoryItems[index].presentation;
        final updatedPres = ProductPresentation(
          id: oldPres.id,
          nombreEspecifico: oldPres.nombreEspecifico,
          codigoBarras: oldPres.codigoBarras,
          descripcion: oldPres.descripcion,
          proveedorId: oldPres.proveedorId,
          esDefault: oldPres.esDefault,
          imagenUrl: body.containsKey('imagen_url')
              ? body['imagen_url']
              : oldPres.imagenUrl,
          umpCompra: umpCompra ?? oldPres.umpCompra,
          precioUmpProveedor: precioUmpProveedor ?? oldPres.precioUmpProveedor,
          cantidadUmpComprada:
              cantidadUmpComprada ?? oldPres.cantidadUmpComprada,
          totalPagoLote: totalPagoLote ?? oldPres.totalPagoLote,
          unidadesPorLote: unidadesPorLote ?? oldPres.unidadesPorLote,
          unidadVenta: unidadVenta ?? oldPres.unidadVenta,
          unidadesPorVenta: unidadesPorVenta ?? oldPres.unidadesPorVenta,
          costoUnitarioCalculado:
              costoUnitarioCalculado ?? oldPres.costoUnitarioCalculado,
          factorGananciaVenta:
              factorGananciaVenta ?? oldPres.factorGananciaVenta,
          precioVentaFinal: precioVentaFinal ?? oldPres.precioVentaFinal,
          stockActual: stock ?? oldPres.stockActual,
          cupoMaximoVariante: clearCupo
              ? null
              : (cupoMaximoVariante ?? oldPres.cupoMaximoVariante),
          precioOferta: oferta == -1 ? null : (oferta ?? oldPres.precioOferta),
          tipoDescuento: oferta == -1
              ? null
              : (tipoDesc ?? oldPres.tipoDescuento),
          valorDescuento: oferta == -1
              ? null
              : (valorDesc ?? oldPres.valorDescuento),
          estado: estado ?? oldPres.estado,
          activo: oldPres.activo,
          usaStockCompartido: oldPres.usaStockCompartido,
        );

        _inventoryItems[index] = InventoryWrapper(
          product: _inventoryItems[index].product,
          presentation: updatedPres,
        );
        final productRef = _inventoryItems[index].product;
        final presIndex = productRef.presentaciones.indexWhere(
          (p) => p.id == presentationId,
        );
        if (presIndex != -1) {
          productRef.presentaciones[presIndex] = updatedPres;
        }

        if (oldPres.usaStockCompartido && stock != null) {
          _syncSharedPoolSiblingsInMemory(productRef, stock);
        }
        notifyListeners();
      }
    } else {
      _lastActionError = "Error al actualizar presentación";
    }
    return ok;
  }

  void _syncSharedPoolSiblingsInMemory(Product productRef, int stock) {
    final updatedProduct = productRef.copyWith(stockCompartido: stock);

    for (int i = 0; i < _inventoryItems.length; i++) {
      final w = _inventoryItems[i];
      if (w.product.id == productRef.id) {
        if (w.presentation.usaStockCompartido) {
          _inventoryItems[i] = InventoryWrapper(
            product: updatedProduct,
            presentation: _clonePresentationWithSharedStock(
              w.presentation,
              stock,
            ),
          );
        } else {
          _inventoryItems[i] = InventoryWrapper(
            product: updatedProduct,
            presentation: w.presentation,
          );
        }
      }
    }

    for (int pIdx = 0; pIdx < updatedProduct.presentaciones.length; pIdx++) {
      final p = updatedProduct.presentaciones[pIdx];
      if (p.usaStockCompartido) {
        updatedProduct.presentaciones[pIdx] = _clonePresentationWithSharedStock(
          p,
          stock,
        );
      }
    }
  }

  ProductPresentation _clonePresentationWithSharedStock(
    ProductPresentation p,
    int stock,
  ) {
    return ProductPresentation(
      id: p.id,
      nombreEspecifico: p.nombreEspecifico,
      codigoBarras: p.codigoBarras,
      descripcion: p.descripcion,
      proveedorId: p.proveedorId,
      esDefault: p.esDefault,
      imagenUrl: p.imagenUrl,
      umpCompra: p.umpCompra,
      precioUmpProveedor: p.precioUmpProveedor,
      cantidadUmpComprada: p.cantidadUmpComprada,
      totalPagoLote: p.totalPagoLote,
      unidadesPorLote: p.unidadesPorLote,
      unidadVenta: p.unidadVenta,
      unidadesPorVenta: p.unidadesPorVenta,
      costoUnitarioCalculado: p.costoUnitarioCalculado,
      factorGananciaVenta: p.factorGananciaVenta,
      precioVentaFinal: p.precioVentaFinal,
      stockActual: stock,
      cupoMaximoVariante: p.cupoMaximoVariante,
      precioOferta: p.precioOferta,
      tipoDescuento: p.tipoDescuento,
      valorDescuento: p.valorDescuento,
      estado: p.estado,
      activo: p.activo,
      usaStockCompartido: true,
    );
  }

  /// Actualiza únicamente el cupo máximo de una variante con stock compartido
  Future<bool> updateVariantQuota(int presentationId, int? newQuota) async {
    return await updatePresentation(
      presentationId,
      cupoMaximoVariante: newQuota,
      clearCupo: newQuota == null,
    );
  }
}
