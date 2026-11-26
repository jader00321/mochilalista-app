part of '../notifications_screen.dart';

mixin _NotificationsCardActionMenuMixin on _NotificationsStateBase {
  @override
  void _showCardActionMenu(
    NotificationModel notif,
    NotificationProvider prov,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final effectiveBottom =
            InteractiveSheetWrapper.getEffectiveBottomPadding(
              ctx,
              minPadding: kMinDefensiveBottomClearance,
            );

        // Determinación de Icono y Color de Cabecera
        IconData catIcon = Icons.notifications_outlined;
        Color catColor = Colors.blue;
        if (notif.categoria == 'inventario' ||
            notif.objetoRelacionadoTipo == 'producto') {
          catIcon = Icons.inventory_2_outlined;
          catColor = Colors.amber;
        } else if (notif.categoria == 'cobranza' ||
            notif.objetoRelacionadoTipo == 'cuota') {
          catIcon = Icons.monetization_on_outlined;
          catColor = Colors.red;
        } else if (notif.categoria == 'cotizacion' ||
            notif.objetoRelacionadoTipo == 'cotizacion') {
          catIcon = Icons.receipt_long_rounded;
          catColor = Colors.indigo;
        }

        // Píldora de Estado
        String statusLabel = "PENDIENTE";
        Color statusBg = Colors.blue.withValues(alpha: 0.15);
        Color statusText = Colors.blue;
        if (notif.isArchived) {
          statusLabel = "ARCHIVADA";
          statusBg = Colors.amber.withValues(alpha: 0.2);
          statusText = Colors.orange[800]!;
        } else if (notif.isResolved) {
          statusLabel = "RESUELTA";
          statusBg = Colors.green.withValues(alpha: 0.2);
          statusText = Colors.green[700]!;
        }

        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, effectiveBottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera Premium
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(catIcon, color: catColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: statusText,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Opciones",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notif.cleanTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 8),

                // ZONA A: ACCIONES RÁPIDAS CONTEXTUALES
                if (notif.objetoRelacionadoTipo == 'producto') ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      "Análisis y Abastecimiento de Stock",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Ver métricas, sumar stock rápido o ajustar umbral",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showStockAnalysisModal(notif, context);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ],

                if (notif.objetoRelacionadoTipo == 'cuota') ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: isDark ? Colors.green[300] : Colors.green[700],
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      "Enviar Recordatorio por WhatsApp",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Mensaje listo con detalle de cuota y mora",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onActionRecordarCuota(notif);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.point_of_sale_rounded,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      "Cobrar Cuota Ahora",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Registrar pago total o abono a esta cuota",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onActionCobrarCuota(notif);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ],

                if (notif.objetoRelacionadoTipo == 'cotizacion') ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: isDark ? Colors.indigo[300] : Colors.indigo[700],
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      "Ver Cotización",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      "Revisar productos y emitir venta",
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _onActionVerCotizacion(notif);
                    },
                  ),
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ],

                // ZONA B: POSPONER RECORDATORIO (SNOOZE)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.snooze_rounded,
                            size: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "POSPONER RECORDATORIO",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Silencia temporalmente este aviso de la lista activa",
                        style: TextStyle(fontSize: 11.5, color: subtitleColor),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildSnoozeChip(
                            label: "1 día",
                            duration: const Duration(days: 1),
                            notifId: notif.id,
                            prov: prov,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildSnoozeChip(
                            label: "3 días",
                            duration: const Duration(days: 3),
                            notifId: notif.id,
                            prov: prov,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildSnoozeChip(
                            label: "1 semana",
                            duration: const Duration(days: 7),
                            notifId: notif.id,
                            prov: prov,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                const SizedBox(height: 4),

                // ZONA C: GESTIÓN DE BANDEJAS
                // 1. Archivar notificación
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: isDark ? Colors.amber[300] : Colors.orange[800],
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    "Archivar notificación",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Retirar de lista activa con opción de restaurar luego",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleArchive(notif, prov);
                  },
                ),

                // 2. Mover a No Deseadas (Silenciar ítem)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_off_outlined,
                      color: isDark ? Colors.red[300] : Colors.red[700],
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    "Mover a No Deseadas (Silenciar ítem)",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    "Bloquear futuras alertas de este ${notif.objetoRelacionadoTipo ?? 'ítem'}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleSilence(notif, prov);
                  },
                ),

                // 3. Alternar Resuelta / Pendiente
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notif.isResolved
                          ? Icons.restart_alt_rounded
                          : Icons.check_circle_outline_rounded,
                      color: isDark ? Colors.green[300] : Colors.green[800],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notif.isResolved
                        ? "Marcar como pendiente"
                        : "Marcar como resuelta",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    notif.isResolved
                        ? "Devolver al flujo de tareas pendientes"
                        : "Finalizar y archivar en resueltas",
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleToggleResolve(notif, prov);
                  },
                ),

                // 4. Eliminar definitivamente
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red[600],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    "Eliminar definitivamente",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.red[600],
                    ),
                  ),
                  subtitle: const Text(
                    "Borrado permanente en base de datos",
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmSingleDelete(notif, prov);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSnoozeChip({
    required String label,
    required Duration duration,
    required int notifId,
    required NotificationProvider prov,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          await prov.snoozeNotification(notifId, duration);
          if (mounted) {
            NotificationToastFeedback.showSuccess(
              context,
              "Notificación pospuesta por $label",
              icon: Icons.snooze_rounded,
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A38) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSingleDelete(
    NotificationModel notif,
    NotificationProvider prov,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Notificación"),
        content: Text(
          "¿Deseas eliminar permanentemente '${notif.cleanTitle}'? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteNotification(notif.id);
              Navigator.pop(ctx);
              NotificationToastFeedback.showSuccess(
                context,
                "Notificación eliminada permanentemente",
                icon: Icons.delete_outline_rounded,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }
}
