part of '../quotation_detail_screen.dart';

mixin _QuotationDetailValidationMixin on _QuotationDetailScreenStateBase {
  @override
  void _handleUpdateAnalysis(ValidationResult validation) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartUpdateModal(
        validation: validation,
        onUpdatePrices: () => _executeRefresh(
          prices: true,
          stock: false,
          names: false,
          bundles: false,
        ),
        onFixStock: () => _fixAllStock(validation),
        onFixAll: () async {
          await _fixAllStock(validation);
          if (mounted) {
            await _executeRefresh(
              prices: true,
              stock: false,
              names: true,
              bundles: false,
            );
          }
        },
        onOpenManualEdit: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ManualQuotationScreen(quotationId: widget.quotationId),
            ),
          );
          if (result == true && mounted) {
            _loadData();
          }
        },
        onUpdateNames: () => _executeRefresh(
          prices: false,
          stock: false,
          names: true,
          bundles: false,
        ),
        onSyncBundles: () => _executeRefresh(
          prices: false,
          stock: false,
          names: false,
          bundles: true,
        ),
        onSyncUnits: () => _executeRefresh(
          prices: false,
          stock: false,
          names: true,
          bundles: false,
        ),
        onFixSingleStock: (itemId, newQty) =>
            _handleIndividualFix(itemId: itemId, newQty: newQty),
        onRemoveSingleItem: (itemId) =>
            _handleIndividualFix(itemId: itemId, remove: true),
        onAcceptSinglePrice: (itemId, newPrice, newBase) =>
            _handleIndividualFix(
              itemId: itemId,
              newAppliedPrice: newPrice,
              newOriginalPrice: newBase,
            ),
        onAcceptSingleName: (itemId, newName) =>
            _handleIndividualFix(itemId: itemId, newName: newName),
      ),
    );
  }

  Map<String, dynamic> _toQuotationItemPayload(
    QuotationItem qItem, {
    required int quantity,
    required double appliedPrice,
    required double originalPrice,
    required String? productName,
    required bool isManualPrice,
  }) {
    return {
      "product_id": qItem.productId,
      "presentation_id": qItem.presentationId,
      "bundle_id": qItem.bundleId,
      "quantity": quantity,
      "unit_price_applied": appliedPrice,
      "original_unit_price": originalPrice,
      "product_name": productName,
      "brand_name": qItem.brandName,
      "specific_name": qItem.specificName,
      "sales_unit": qItem.salesUnit,
      "is_manual_price": isManualPrice,
      "image_url": qItem.imageUrl,
      "original_text": qItem.originalText,
    };
  }

  Future<void> _fixAllStock(ValidationResult validation) async {
    if (_fullQuotation == null) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      double newTotalAmount = 0.0;
      double newTotalSavings = 0.0;

      final Map<int, int> sharedAdjustedQuantities = {};
      final Set<int> sharedRemovedItemIds = {};

      for (final conflict in validation.sharedStockConflicts) {
        int remainingBase = conflict.totalSharedPool;
        for (final cItem in conflict.conflictingItems) {
          final factor = cItem.conversionFactor > 0
              ? cItem.conversionFactor
              : 1;
          final maxUnitsFromBase = remainingBase ~/ factor;
          final maxAllowed = cItem.cupoMaximo != null
              ? (maxUnitsFromBase < cItem.cupoMaximo!
                    ? maxUnitsFromBase
                    : cItem.cupoMaximo!)
              : maxUnitsFromBase;
          final allocatedQty = cItem.requestedQty <= maxAllowed
              ? cItem.requestedQty
              : maxAllowed;

          if (allocatedQty > 0) {
            sharedAdjustedQuantities[cItem.itemId] = allocatedQty;
            remainingBase -= allocatedQty * factor;
          } else {
            sharedRemovedItemIds.add(cItem.itemId);
          }
        }
      }

      final stockWarningsMap = {
        for (final w in validation.stockWarnings) w.itemId: w,
      };

      for (final qItem in _fullQuotation!.items) {
        if (sharedRemovedItemIds.contains(qItem.id)) {
          // Se retira de la lista para levantar el conflicto de stock compartido
          continue;
        }

        int qty = qItem.quantity;
        if (sharedAdjustedQuantities.containsKey(qItem.id)) {
          qty = sharedAdjustedQuantities[qItem.id]!;
        } else {
          final warning = stockWarningsMap[qItem.id];
          if (warning != null) {
            if (warning.available <= 0) {
              // Producto agotado: se retira de la lista para levantar el bloqueo de venta
              continue;
            }
            qty = warning.available;
          }
        }

        newTotalAmount += qItem.unitPriceApplied * qty;
        final double savings =
            (qItem.originalUnitPrice - qItem.unitPriceApplied) * qty;
        if (savings > 0) {
          newTotalSavings += savings;
        }

        itemsPayload.add(
          _toQuotationItemPayload(
            qItem,
            quantity: qty,
            appliedPrice: qItem.unitPriceApplied,
            originalPrice: qItem.originalUnitPrice,
            productName: qItem.productName,
            isManualPrice: qItem.isManualPrice,
          ),
        );
      }

      final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
      await wbProv.saveManualQuotation(
        id: widget.quotationId,
        clientId: _fullQuotation!.clientId,
        clientName: _fullQuotation!.clientName,
        institution: _fullQuotation!.institutionName,
        grade: _fullQuotation!.gradeLevel,
        notas: _fullQuotation!.notas,
        totalAmount: newTotalAmount,
        totalSavings: newTotalSavings > 0 ? newTotalSavings : 0.0,
        items: itemsPayload,
        status: _fullQuotation!.status,
        type: _fullQuotation!.type,
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Productos agotados y stock corregidos exitosamente",
          isError: false,
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al corregir stock: $e",
          isError: true,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleIndividualFix({
    required int itemId,
    bool remove = false,
    int? newQty,
    double? newAppliedPrice,
    double? newOriginalPrice,
    String? newName,
  }) async {
    setState(() => _isLoading = true);

    try {
      final List<Map<String, dynamic>> itemsPayload = [];
      double newTotalAmount = 0.0;
      double newTotalSavings = 0.0;

      for (final qItem in _fullQuotation!.items) {
        if (qItem.id == itemId) {
          if (remove) {
            continue;
          }

          final qty = newQty ?? qItem.quantity;
          final appliedPrice = newAppliedPrice ?? qItem.unitPriceApplied;
          final originalPrice = newOriginalPrice ?? qItem.originalUnitPrice;

          newTotalAmount += appliedPrice * qty;
          final double savings = (originalPrice - appliedPrice) * qty;
          if (savings > 0) {
            newTotalSavings += savings;
          }

          itemsPayload.add(
            _toQuotationItemPayload(
              qItem,
              quantity: qty,
              appliedPrice: appliedPrice,
              originalPrice: originalPrice,
              productName: newName ?? qItem.productName,
              isManualPrice: false,
            ),
          );
        } else {
          newTotalAmount += qItem.unitPriceApplied * qItem.quantity;
          final double savings =
              (qItem.originalUnitPrice - qItem.unitPriceApplied) *
              qItem.quantity;
          if (savings > 0) {
            newTotalSavings += savings;
          }

          itemsPayload.add(
            _toQuotationItemPayload(
              qItem,
              quantity: qItem.quantity,
              appliedPrice: qItem.unitPriceApplied,
              originalPrice: qItem.originalUnitPrice,
              productName: qItem.productName,
              isManualPrice: qItem.isManualPrice,
            ),
          );
        }
      }

      final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
      await wbProv.saveManualQuotation(
        id: widget.quotationId,
        clientId: _fullQuotation!.clientId,
        clientName: _fullQuotation!.clientName,
        institution: _fullQuotation!.institutionName,
        grade: _fullQuotation!.gradeLevel,
        notas: _fullQuotation!.notas,
        totalAmount: newTotalAmount,
        totalSavings: newTotalSavings > 0 ? newTotalSavings : 0.0,
        items: itemsPayload,
        status: _fullQuotation!.status,
        type: _fullQuotation!.type,
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Ítem ajustado correctamente",
          isError: false,
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "Error al actualizar el ítem",
          isError: true,
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _executeRefresh({
    required bool prices,
    required bool stock,
    required bool names,
    required bool bundles,
  }) async {
    final wp = Provider.of<WorkbenchProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final success = await wp.refreshQuotation(
      widget.quotationId,
      fixPrices: prices,
      fixStock: stock,
      fixNames: names,
      fixBundles: bundles,
    );
    if (success && mounted) {
      CustomSnackBar.show(
        context,
        message: "Cotización actualizada correctamente.",
        isError: false,
      );
      _loadData();
    } else if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Error al actualizar la cotización.",
        isError: true,
      );
      setState(() => _isLoading = false);
    }
  }
}
