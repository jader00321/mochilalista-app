part of '../notifications_screen.dart';

mixin _NotificationsGroupedClientSectionMixin on _NotificationsStateBase {
  String _getGroupHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) return "Hoy";
    if (targetDate == yesterday) return "Ayer";
    return "Anteriores";
  }

  @override
  List<dynamic> _buildGroupedList(List<NotificationModel> notifs) {
    List<dynamic> result = [];
    String currentGroup = "";

    for (var n in notifs) {
      String group = _getGroupHeader(n.createdAt);
      if (group != currentGroup) {
        result.add(group);
        currentGroup = group;
      }
      result.add(n);
    }
    return result;
  }


  // =========================================================================
  // SMART GROUPING POR CLIENTE (TARJETA MAESTRA EXPANDIBLE)
  // =========================================================================

  @override
  Widget _buildGroupedClientMasterCard({
    required int clientId,
    required String clientName,
    required String? clientPhone,
    required List<NotificationModel> cuotas,
    required bool isDark,
    required NotificationProvider prov,
  }) {
    final isExpanded = _expandedClientGroupIds.contains(clientId);
    final int cuotasCount = cuotas.length;
    final double totalDeuda = cuotas.fold(
      0.0,
      (sum, c) => sum + (c.saldoTotal ?? (c.montoBase ?? 0.0)),
    );
    final double totalMora = cuotas.fold(
      0.0,
      (sum, c) => sum + c.moraAcumulada,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1C22) : const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.red[800]!.withValues(alpha: 0.5)
              : Colors.red.shade200,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Tarjeta Maestra
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedClientGroupIds.remove(clientId);
                } else {
                  _expandedClientGroupIds.add(clientId);
                }
              });
            },
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isDark
                        ? Colors.red[900]!.withValues(alpha: 0.6)
                        : Colors.red[100],
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                      style: TextStyle(
                        color: isDark ? Colors.red[200] : Colors.red[800],
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              clientName,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "$cuotasCount cuotas",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Total exigible: S/ ${totalDeuda.toStringAsFixed(2)}${totalMora > 0.001 ? ' (+S/ ${totalMora.toStringAsFixed(2)} mora)' : ''}",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.red[300] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 22,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    tooltip: "Opciones de cobranzas",
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => _showGroupActionMenu(
                      clientId,
                      clientName,
                      cuotas,
                      prov,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 26,
                  ),
                ],
              ),
            ),
          ),

          // Botón Directo Consolidado de WhatsApp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () => _onActionRecordarConsolidado(
                  clientId,
                  clientName,
                  clientPhone,
                  cuotas,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                label: const Text(
                  "Recordatorio Consolidado por WhatsApp",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

          // Desglose de cuotas individuales expandibles
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Container(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      children: cuotas.map((cNotif) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: _buildNotificationCardItem(
                            cNotif,
                            prov,
                            isDark,
                            tabIndex: 0,
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showGroupActionMenu(
    int clientId,
    String clientName,
    List<NotificationModel> cuotas,
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
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Cobranzas de $clientName",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${cuotas.length} cuotas pendientes asociadas",
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
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
              ),
              const Divider(height: 1),

              // 1. Archivar todas las cuotas de este cliente
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
                  "Archivar todas las alertas de este cliente",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  "Oculta el grupo de pendientes con opción de deshacer",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.archiveClientCuotas(clientId);
                  NotificationToastFeedback.showArchived(
                    context,
                    title: "Alertas de $clientName",
                    onUndo: () {
                      prov.unarchiveClientCuotas(clientId);
                    },
                  );
                },
              ),

              // 2. Silenciar cliente (Mover a No Deseadas)
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
                  "Mover a No Deseadas (Silenciar cliente)",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  "Bloquea futuras alertas de cobranza para este cliente",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.silenceClient(clientId);
                  NotificationToastFeedback.showSilenced(
                    context,
                    title: "Alertas de $clientName",
                    onUndo: () {
                      prov.unsilenceClient(clientId);
                    },
                  );
                },
              ),

              // 3. Resolver todas las cuotas del grupo
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.done_all_rounded,
                    color: isDark ? Colors.green[300] : Colors.green[800],
                    size: 20,
                  ),
                ),
                title: const Text(
                  "Marcar todas como resueltas",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: const Text(
                  "Resuelve las cuotas de este cliente en lote",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  final ids = cuotas.map((c) => c.id).toList();
                  for (var cid in ids) {
                    prov.markAsResolved(cid);
                  }
                  NotificationToastFeedback.showResolved(
                    context,
                    title: "Cuotas de $clientName",
                    onUndo: () {
                      for (var cid in ids) {
                        prov.markAsUnresolved(cid);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

}
