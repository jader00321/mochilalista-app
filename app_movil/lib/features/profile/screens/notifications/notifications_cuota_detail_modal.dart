part of '../notifications_screen.dart';

mixin _NotificationsCuotaDetailModalMixin on _NotificationsStateBase {
  @override
  void _showStockAnalysisModal(
    NotificationModel notif,
    BuildContext context,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
    await StockAnalysisModal.show(context, notif: notif, isDark: isDark);
    if (!mounted) return;
    notifProv.fetchNotifications();
  }

  @override
  void _showCuotaVencidaModal(
    NotificationModel notif,
    BuildContext context,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final salesService = SalesService();
    final cuotaData = await salesService.getCuotaConCliente(
      notif.objetoRelacionadoId!,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // cerrar cargador

    if (cuotaData == null) {
      NotificationToastFeedback.showError(
        context,
        "No se pudo cargar la cuota",
      );
      return;
    }

    final clienteNombre =
        cuotaData['cliente_nombre'] ??
        notif.clientName ??
        'Cliente Desconocido';
    final clienteTelefono = cuotaData['cliente_telefono'] ?? notif.clientPhone;
    final clienteId = cuotaData['cliente_id'] ?? notif.clientId;
    final double deuda =
        (cuotaData['monto'] as num).toDouble() -
        ((cuotaData['monto_pagado'] as num?)?.toDouble() ?? 0.0);
    final String estado = cuotaData['estado'] ?? 'pendiente';
    final bool estaPagada = estado.toLowerCase() == 'pagado';

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );
        return SafeArea(
          top: false,
          bottom: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, effectiveBottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF23232F) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: estaPagada
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          estaPagada
                              ? Icons.check_circle
                              : Icons.warning_rounded,
                          color: estaPagada ? Colors.green : Colors.red[600],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estaPagada ? "Cuota Pagada" : "Cuota Vencida",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              clienteNombre,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14141C)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Detalles de la Deuda",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Cuota N°",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                              ),
                            ),
                            Text(
                              "${cuotaData['numero_cuota']}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "F. Vencimiento",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                              ),
                            ),
                            Text(
                              "${cuotaData['fecha_vencimiento']}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Monto Pendiente",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[800],
                              ),
                            ),
                            Text(
                              "S/ ${deuda.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: estaPagada ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (clienteTelefono != null && clienteTelefono.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onActionRecordarCuota(notif);
                        },
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.green,
                        ),
                        label: const Text(
                          "Enviar Recordatorio por WhatsApp",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  if (clienteTelefono != null && clienteTelefono.isNotEmpty)
                    const SizedBox(height: 12),
                  if (clienteId != null)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          final clientData = await ClientService()
                              .getClientById(clienteId);
                          if (!context.mounted) return;
                          Navigator.pop(context); // Cerrar indicador
                          if (clientData != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClientDetailScreen(client: clientData),
                              ),
                            );
                            if (context.mounted) {
                              Provider.of<NotificationProvider>(
                                context,
                                listen: false,
                              ).fetchNotifications();
                            }
                          } else {
                            NotificationToastFeedback.showError(
                              context,
                              "No se pudo cargar el cliente",
                            );
                          }
                        },
                        icon: const Icon(Icons.person_rounded),
                        label: const Text(
                          "Ir al Perfil del Cliente",
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        "Cerrar",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}
