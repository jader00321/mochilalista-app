// ignore_for_file: deprecated_member_use
part of '../sale_history_detail_screen.dart';

extension _SaleHistoryDetailActionsExt on _SaleHistoryDetailScreenState {
  Map<String, dynamic> _getOrigenStyles(String? origen, bool isDark) {
    if (origen == 'pos_rapido') {
      return {
        'label': "Venta en Caja Rápida",
        'color': isDark ? Colors.pink[300] : Colors.pinkAccent,
        'icon': Icons.point_of_sale,
      };
    } else if (origen == 'prestamo_personal') {
      return {
        'label': "Préstamo Personal",
        'color': isDark ? Colors.amber[300] : Colors.amber[800],
        'icon': Icons.account_balance_wallet,
      };
    } else if (origen == 'ai_scan') {
      return {
        'label': "Lista Escaneada con IA",
        'color': isDark ? Colors.purple[300] : Colors.purple,
        'icon': Icons.auto_awesome,
      };
    } else if (origen == 'client_web') {
      return {
        'label': "Pedido desde Web",
        'color': isDark ? Colors.blue[300] : Colors.blue,
        'icon': Icons.public,
      };
    } else {
      return {
        'label': "Lista Creada Manualmente",
        'color': isDark ? Colors.teal[300] : Colors.teal,
        'icon': Icons.edit_note,
      };
    }
  }

  Future<void> _handleArchive(bool isDark) async {
    final nav = Navigator.of(context);
    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final trackingProv = Provider.of<TrackingProvider>(context, listen: false);
    final dialogBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    String? selectedReason;
    if (_saleData!['is_archived'] != 1) {
      final List<String> motivos = [
        "Error de digitación",
        "Falta de stock",
        "Precio muy alto",
        "Cliente arrepentido",
        "Mala atención",
        "Otro",
      ];
      selectedReason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String? currentVal;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                backgroundColor: dialogBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  "¿Anular Venta?",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Selecciona el motivo de la anulación:",
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                      ...motivos.map(
                        (m) => ListTile(
                          title: Text(
                            m,
                            style: TextStyle(fontSize: 14, color: textColor),
                          ),
                          leading: Radio<String>(
                            value: m,
                            groupValue: currentVal,
                            onChanged: (val) =>
                                setModalState(() => currentVal = val),
                          ),
                          contentPadding: EdgeInsets.zero,
                          onTap: () => setModalState(() => currentVal = m),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: currentVal == null
                        ? null
                        : () => Navigator.pop(ctx, currentVal),
                    child: const Text(
                      "Anular",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
      if (selectedReason == null) {
        return;
      }
    } else {
      final isLoan = _saleData!['origen_venta'] == 'prestamo_personal';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isLoan ? "¿Restaurar Préstamo?" : "¿Restaurar Venta?",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isLoan
                ? "Este préstamo volverá a estar activo."
                : "Esta venta volverá a aparecer en el historial principal y sumará a tus ingresos.",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Restaurar",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) {
        return;
      }
    }

    _updateState(() => _isProcessingAction = true);

    try {
      final int idTarget = widget.saleId ?? _saleData!['id'];
      if (_saleData!['is_archived'] == 1) {
        await saleProv.restoreSale(idTarget);
      } else {
        await saleProv.voidSale(idTarget, selectedReason!);
      }

      try {
        await trackingProv.loadClients();
        final cId = _saleData?['cliente_id'] as int?;
        if (cId != null && cId > 0) {
          await trackingProv.loadClientLedger(cId);
          await trackingProv.loadClientDebts(cId);
        }
      } catch (_) {}
      try {
        if (mounted) {
          Provider.of<InventoryProvider>(
            context,
            listen: false,
          ).refreshAfterSale();
        }
      } catch (_) {}

      if (mounted) {
        final isLoan = _saleData!['origen_venta'] == 'prestamo_personal';
        _showSnack(
          _saleData!['is_archived'] == 1
              ? (isLoan
                    ? "Préstamo restaurado exitosamente."
                    : "Venta restaurada exitosamente.")
              : (isLoan
                    ? "Préstamo anulado exitosamente."
                    : "Venta anulada y stock devuelto."),
        );
        nav.pop();
      }
    } catch (e) {
      if (mounted) {
        _updateState(() => _isProcessingAction = false);
        _showSnack(e.toString().replaceAll("Exception: ", ""), isError: true);
      }
    }
  }

  Future<void> _handleRegisterPayment() async {
    final clientId = _saleData?['cliente_id'];
    if (clientId == null || clientId <= 0) {
      _showSnack(
        "Esta operación no tiene un cliente asociado para registrar abonos.",
        isError: true,
      );
      return;
    }

    final saleProv = Provider.of<SaleProvider>(context, listen: false);
    final client = await saleProv.getClientById(clientId);
    if (client == null) {
      _showSnack("No se encontró el registro del cliente.", isError: true);
      return;
    }

    if (mounted) {
      final double totalAmount = (_saleData?['monto_total'] ?? 0.0).toDouble();
      final double paidAmount = (_saleData?['monto_pagado'] ?? 0.0).toDouble();
      final double diff = totalAmount - paidAmount;
      final double pendingDebt = diff > 0.01 ? diff : 0.0;

      showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PaymentEntryModal(
          client: client,
          initialTargetType: 'venta',
          initialTargetId: _saleData?['id'],
          initialAmount: pendingDebt,
          onPaymentSuccess: () {
            _loadSaleDetail();
            saleProv.silentRefresh();
          },
        ),
      );
    }
  }

  void _handleSellAgainQuickSale(bool isDark) {
    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final promoProv = Provider.of<PromotionProvider>(context, listen: false);

    final items = _saleData!['items'] as List<dynamic>? ?? [];

    if (items.isEmpty) {
      _showSnack("No hay productos vigentes para vender.", isError: true);
      return;
    }

    if (!quickProv.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Caja Ocupada",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "Tienes productos en curso en la Caja Rápida.\n\n¿Deseas limpiar la caja antes de agregar esta venta, o quieres mezclarlos?",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeRestoreCart(
                  items,
                  invProv,
                  promoProv,
                  quickProv,
                  clearFirst: false,
                );
              },
              child: Text(
                "Mezclar",
                style: TextStyle(
                  color: isDark ? Colors.blue[300] : Colors.blue,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _executeRestoreCart(
                  items,
                  invProv,
                  promoProv,
                  quickProv,
                  clearFirst: true,
                );
              },
              child: const Text(
                "Limpiar y Cargar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    } else {
      _executeRestoreCart(
        items,
        invProv,
        promoProv,
        quickProv,
        clearFirst: true,
      );
    }
  }

  Future<void> _executeRestoreCart(
    List<dynamic> items,
    InventoryProvider invProv,
    PromotionProvider promoProv,
    QuickSaleProvider quickProv, {
    required bool clearFirst,
  }) async {
    _updateState(() => _isProcessingAction = true);

    final report = await quickProv.restoreCartFromHistory(
      items,
      invProv,
      promoProv,
      clearPrevious: clearFirst,
    );

    if (!mounted) {
      return;
    }
    _updateState(() => _isProcessingAction = false);

    String msg = "Productos enviados a la Caja Rápida.";
    bool isWarning = false;

    if (report['notFound']!.isNotEmpty || report['outOfStock']!.isNotEmpty) {
      isWarning = true;
      msg = "Algunos productos fallaron:\n";
      if (report['outOfStock']!.isNotEmpty) {
        msg += "- ${report['outOfStock']!.length} producto(s) sin stock.\n";
      }
      if (report['notFound']!.isNotEmpty) {
        msg += "- ${report['notFound']!.length} producto(s) no encontrados.";
      }
    }

    _showSnack(msg, isError: isWarning);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
    );
  }

  Future<void> _handleCloneToGeneric(int cotizacionId) async {
    _updateState(() => _isProcessingAction = true);
    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );
    final int? newQuotationId = await workbenchProv.cloneQuotation(
      cotizacionId,
    );

    if (mounted) {
      _updateState(() => _isProcessingAction = false);
      if (newQuotationId != null) {
        _showSnack("Lista duplicada exitosamente.");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManualQuotationScreen(quotationId: newQuotationId),
          ),
        );
      } else {
        _showSnack("No se pudo duplicar la cotización", isError: true);
      }
    }
  }

  Future<void> _handleConvertToPack(int cotizacionId) async {
    _updateState(() => _isProcessingAction = true);
    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );
    final int? newPackId = await workbenchProv.convertToPack(cotizacionId);

    if (mounted) {
      _updateState(() => _isProcessingAction = false);
      if (newPackId != null) {
        _showSnack("Pack Escolar creado exitosamente");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotationId: newPackId),
          ),
        );
      } else {
        _showSnack("No se pudo crear el pack", isError: true);
      }
    }
  }
}
