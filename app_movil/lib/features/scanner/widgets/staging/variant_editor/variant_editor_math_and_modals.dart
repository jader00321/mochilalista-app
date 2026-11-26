part of '../variant_editor_row.dart';

mixin _VariantEditorMathAndModalsMixin on _VariantEditorRowStateBase {
  // 🔥 MATEMÁTICA EN TIEMPO REAL
  @override
  void _onPurchaseDataChanged({bool fromTotal = false, bool fromCosto = false, bool fromStock = false, bool fromMargen = false, bool fromVenta = false, bool fromEmpaque = false, bool fromUnidEmpaque = false}) {
    if (fromEmpaque) {
      UnitMatch? match = UnitCatalogService.resolveUnit(_umpCompraCtrl.text);
      if (match != null && !match.isConfigurable) {
        _unidadesLoteCtrl.text = match.factor.toString();
      }
    } else if (fromUnidEmpaque) {
      int factor = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
      String? resolvedName = UnitCatalogService.resolveFromFactor(factor);
      if (resolvedName != null) {
        _umpCompraCtrl.text = resolvedName;
      } else if (factor > 1) {
        UnitMatch? currentMatch = UnitCatalogService.resolveUnit(_umpCompraCtrl.text);
        if (currentMatch != null && !currentMatch.isConfigurable) {
          _umpCompraCtrl.text = "Caja";
        }
      }
    }

    double cantComprada = double.tryParse(_cantCompraCtrl.text) ?? 1.0;
    int unidPorLote = int.tryParse(_unidadesLoteCtrl.text) ?? 1;
    double totalPago = double.tryParse(_totalPagoCtrl.text) ?? 0.0;
    double costoUnitario = double.tryParse(_costoUnitarioCtrl.text) ?? 0.0;
    
    int unidPorVenta = int.tryParse(_unidadesVentaCtrl.text) ?? 1;
    
    // Si viene del stock base (se ajustó porque llegaron menos o más unidades)
    if (fromStock) {
       int stockBase = int.tryParse(_stockBaseCtrl.text) ?? (cantComprada * unidPorLote).toInt();
       widget.variant.stockIngresanteOverride = stockBase;
       
       // El costo unitario se recalcula en base al pago total (que se mantiene) y el nuevo stock real
       if (stockBase > 0) {
         if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
           costoUnitario = totalPago / stockBase;
           _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
         }
         if (unidPorLote > 0) {
           cantComprada = stockBase / unidPorLote;
           _cantCompraCtrl.text = cantComprada.toStringAsFixed(2);
         }
       }
    } else {
       // Cálculo normal si no vino del stock
       if (fromCosto) {
         // Se editó el costo unitario manualmente, recalcular pago total
         totalPago = costoUnitario * (cantComprada * unidPorLote);
         _totalPagoCtrl.text = totalPago.toStringAsFixed(2);
       } else if (fromTotal) {
         // Se editó el total manualmente, recalcular costo unitario
         if (cantComprada > 0 && unidPorLote > 0) {
           if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
             costoUnitario = totalPago / (cantComprada * unidPorLote);
           }
         }
         _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
       } else if (!fromVenta && !fromMargen) {
         // Se editó cantidad o unidades por lote, recalcular costo unitario (no el total)
         if (cantComprada > 0 && unidPorLote > 0) {
           if (widget.variant.sourceVariantUuid == null || totalPago > 0) {
             costoUnitario = totalPago / (cantComprada * unidPorLote);
           }
         }
         _costoUnitarioCtrl.text = costoUnitario.toStringAsFixed(2);
       }
       
       // Actualizar stock base sugerido (borrar override)
       widget.variant.stockIngresanteOverride = null;
       int totalUnidadesBase = (cantComprada * unidPorLote).toInt();
       _stockBaseCtrl.text = totalUnidadesBase.toString();
    }

    double costoPresentacionReal = ScannerCostEngine.calculatePresentationCost(
      unitCost: costoUnitario,
      unidadesPorVenta: unidPorVenta,
    );

    double pVenta = 0.0;
    double margen = ScannerCostEngine.suggestDynamicMargin(fallbackMargin: 1.35);
    
    if (fromVenta) {
      pVenta = double.tryParse(_precioVentaCtrl.text) ?? 0.0;
      margen = ScannerCostEngine.calculateMargin(
        salePrice: pVenta,
        presentationCost: costoPresentacionReal,
      );
      _margenCtrl.text = margen.toStringAsFixed(2);
    } else if (fromMargen && !fromVenta && !fromCosto && !fromStock && !fromTotal && !fromEmpaque && !fromUnidEmpaque) {
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costoPresentacionReal,
        marginFactor: margen,
      );
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    } else {
      // Recalcular precio de venta si cambió el costo
      margen = double.tryParse(_margenCtrl.text) ?? margen;
      pVenta = ScannerCostEngine.suggestSalePrice(
        presentationCost: costoPresentacionReal,
        marginFactor: margen,
      );
      _precioVentaCtrl.text = pVenta.toStringAsFixed(2);
    }
    
    double pUmpProv = ScannerCostEngine.calculateProviderUmpPrice(
      totalPago: totalPago,
      cantidadUmp: cantComprada,
    );

    setState(() {
      widget.variant.nombreEspecifico = _nombreCtrl.text;
      widget.variant.codigoBarra = _codigoBarraCtrl.text.isEmpty ? null : _codigoBarraCtrl.text;
      widget.variant.unidadVenta = _unidadVentaCtrl.text;
      widget.variant.unidadesPorVenta = unidPorVenta;
      widget.variant.updateUnidadVenta = true;
      
      widget.variant.umpCompra = _umpCompraCtrl.text;
      widget.variant.cantidadUmpComprada = cantComprada;
      widget.variant.totalPagoLote = totalPago;
      widget.variant.precioUmpProveedor = pUmpProv;
      widget.variant.unidadesPorLote = unidPorLote;
      
      widget.variant.costoUnitarioSugerido = costoPresentacionReal;
      widget.variant.factorGananciaVentaSugerido = margen;
      widget.variant.precioVentaSugerido = pVenta;
      widget.variant.resetStockAuthorizationFlags();
      if (widget.group.modoStock == 'COMPARTIDO' || widget.variant.usaStockCompartido) {
        widget.provider.syncGroupSharedPurchaseFromMasterVariant(widget.group.uuidTemporal);
      }
    });
  }

  @override
  void _openComparativeModal(Map<String, dynamic> dbData) async {
    final result = await ComparativeUpdateModal.show<String>(
      context,
      variant: widget.variant,
      group: widget.group,
      dbData: dbData,
      isDark: widget.isDark,
      provider: widget.provider,
      onConfirm: () {
        _initControllers();
        widget.provider.notifyUIUpdate();
      },
    );
    if (result != null) {
      widget.provider.scrollToAndHighlightVariant(result);
    }
  }
}
