part of '../notifications_screen.dart';

mixin _NotificationsActionsAndDeeplinksMixin on _NotificationsStateBase {
  // =========================================================================
  // ACCIONES DIRECTAS EN TARJETA (IN-CARD ACTIONS)
  // =========================================================================

  @override
  void _onActionRecordarCuota(NotificationModel notif) async {
    final cuotaId = notif.objetoRelacionadoId;
    if (cuotaId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final salesService = SalesService();
    Map<String, dynamic>? cuotaData = await salesService.getCuotaConCliente(
      cuotaId,
    );
    if (!mounted) return;
    Navigator.pop(context); // cerrar cargador

    cuotaData ??= {
      'id': cuotaId,
      'numero_cuota': notif.cuotaNumero ?? 1,
      'monto': notif.saldoTotal ?? notif.montoBase ?? 0.0,
      'monto_original': notif.montoBase ?? 0.0,
      'mora_monto': notif.moraAcumulada,
      'monto_pagado': 0.0,
      'fecha_vencimiento':
          notif.fechaVencimiento ?? DateTime.now().toIso8601String(),
      'cliente_nombre': notif.clientName,
      'cliente_telefono': notif.clientPhone,
    };

    await WhatsAppPreviewModal.showCuotaReminder(
      context: context,
      cuota: cuotaData,
      clientName: cuotaData['cliente_nombre'] ?? notif.clientName,
      clientPhone: cuotaData['cliente_telefono'] ?? notif.clientPhone,
      isDark: Theme.of(context).brightness == Brightness.dark,
      operationTitle: notif.folioOperacion,
    );
    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void _onActionCobrarCuota(NotificationModel notif) async {
    final clientId = notif.clientId;
    if (clientId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final clientService = ClientService();
    final clientData = await clientService.getClientById(clientId);
    if (!mounted) return;
    Navigator.pop(context);

    if (clientData == null) {
      NotificationToastFeedback.showError(
        context,
        "No se pudo cargar el cliente",
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentEntryModal(
        client: clientData,
        initialTargetType: 'cuota',
        initialTargetId: notif.objetoRelacionadoId,
        initialAmount: notif.saldoTotal,
      ),
    );
    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void _onActionMoraCuota(NotificationModel notif) async {
    final cuotaId = notif.objetoRelacionadoId;
    if (cuotaId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final salesService = SalesService();
    final cuotaData = await salesService.getCuotaConCliente(cuotaId);
    if (!mounted) return;
    Navigator.pop(context);

    if (cuotaData == null) {
      NotificationToastFeedback.showError(
        context,
        "No se pudo cargar la cuota",
      );
      return;
    }

    await CuotaMorosidadModal.show(
      context: context,
      cuota: cuotaData,
      isDark: Theme.of(context).brightness == Brightness.dark,
      onSaved: () {
        if (mounted) {
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).fetchNotifications();
        }
      },
    );
    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void _onActionAbastecer(NotificationModel notif) async {
    final pId = notif.objetoRelacionadoId;
    if (pId == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final product = await invProv.getFullProductWithFallback(pId);
    if (!mounted) return;
    Navigator.pop(context);

    if (product == null) {
      NotificationToastFeedback.showError(context, "Producto no encontrado");
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(productToEdit: product),
      ),
    );
    if (!mounted) return;
    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
    await notifProv.resolveProductStockNotification(pId);
    await notifProv.fetchNotifications();
  }

  @override
  void _onActionKardex(NotificationModel notif) {
    _showStockAnalysisModal(notif, context);
  }

  @override
  void _onActionVerCotizacion(NotificationModel notif) async {
    if (notif.objetoRelacionadoId != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuotationDetailScreen(quotationId: notif.objetoRelacionadoId!),
        ),
      );
      if (mounted) {
        Provider.of<NotificationProvider>(
          context,
          listen: false,
        ).fetchNotifications();
      }
    }
  }

  @override
  void _onActionVerPremio(NotificationModel notif) async {
    final rewardId = notif.objetoRelacionadoId;
    if (rewardId == null) return;

    final db = await LocalDatabase.instance.database;
    final rRows = await db.query(
      'recompensas_cliente',
      where: 'id = ?',
      whereArgs: [rewardId],
    );
    if (rRows.isEmpty || !mounted) return;
    final rData = rRows.first;

    final rewardModel = ClientRewardModel(
      id: rData['id'] as int,
      negocioId: rData['negocio_id'] as int,
      clienteId: rData['cliente_id'] as int,
      metaId: rData['meta_id'] as int,
      puntosConsumidos: (rData['puntos_consumidos'] as num).toInt(),
      estado: rData['estado'] as String,
      tipoBeneficio: rData['tipo_beneficio'] as String,
      valorBeneficio: (rData['valor_beneficio'] as num).toDouble(),
      tituloRecompensa: rData['titulo_recompensa'] as String,
      descripcionRecompensa: rData['descripcion_recompensa'] as String?,
      fechaDesbloqueo: rData['fecha_desbloqueo'] as String,
    );

    final clientService = ClientService();
    final client = await clientService.getClientById(
      rData['cliente_id'] as int,
    );
    if (client == null || !mounted) return;

    await RewardReviewModal.show(
      context: context,
      reward: rewardModel,
      client: client,
      onActionCompleted: () {
        if (mounted) {
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).fetchNotifications();
        }
      },
    );

    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void _onActionRecordarConsolidado(
    int clientId,
    String clientName,
    String? clientPhone,
    List<NotificationModel> cuotas,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final salesService = SalesService();
    List<Map<String, dynamic>> cuotasData = [];
    double totalDebt = 0.0;

    for (var n in cuotas) {
      final cId = n.objetoRelacionadoId;
      Map<String, dynamic>? cData;
      if (cId != null) {
        cData = await salesService.getCuotaConCliente(cId);
      }
      cData ??= {
        'id': cId ?? 0,
        'numero_cuota': n.cuotaNumero ?? 1,
        'monto': n.saldoTotal ?? n.montoBase ?? 0.0,
        'monto_original': n.montoBase ?? 0.0,
        'mora_monto': n.moraAcumulada,
        'monto_pagado': 0.0,
        'fecha_vencimiento':
            n.fechaVencimiento ?? DateTime.now().toIso8601String(),
        'cliente_nombre': clientName,
        'cliente_telefono': clientPhone,
      };

      cuotasData.add(cData);
      final double due =
          (num.tryParse(cData['monto'].toString()) ?? 0.0).toDouble() -
          (num.tryParse((cData['monto_pagado'] ?? 0.0).toString()) ?? 0.0)
              .toDouble();
      totalDebt += (due > 0 ? due : 0.0);
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (cuotasData.isEmpty) {
      NotificationToastFeedback.showInfo(
        context,
        "No se encontraron cuotas para este cliente",
      );
      return;
    }

    await WhatsAppPreviewModal.showOverdueSummary(
      context: context,
      overdueCuotas: cuotasData,
      totalDebt: totalDebt,
      clientName: clientName,
      clientPhone: clientPhone,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void _handleDeepLink(NotificationModel notif, BuildContext context) async {
    final prov = Provider.of<NotificationProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (!notif.isRead) prov.markAsRead(notif.id);

    final tipo = notif.objetoRelacionadoTipo;
    final id = notif.objetoRelacionadoId;

    if (tipo == null || id == null) {
      _showNotificationDetails(notif);
      return;
    }

    final isClient = authProv.isCommunityClient;

    try {
      switch (tipo.toLowerCase()) {
        case 'venta':
        case 'venta_admin':
        case 'venta_cliente':
        case 'cotizacion':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuotationDetailScreen(quotationId: id),
            ),
          );
          break;

        case 'factura_carga':
          if (isClient) {
            _showNotificationDetails(notif);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: id),
              ),
            );
          }
          break;

        case 'producto':
          if (isClient) {
            _showNotificationDetails(notif);
          } else {
            _showStockAnalysisModal(notif, context);
          }
          break;

        case 'cuota':
          _showCuotaVencidaModal(notif, context);
          break;

        case 'recompensa':
          _onActionVerPremio(notif);
          break;

        default:
          _showNotificationDetails(notif);
      }
    } catch (e) {
      _showNotificationDetails(notif);
    }

    if (mounted) {
      prov.fetchNotifications();
    }
  }

}
