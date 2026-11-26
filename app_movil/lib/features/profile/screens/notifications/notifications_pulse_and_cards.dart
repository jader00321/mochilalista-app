part of '../notifications_screen.dart';

mixin _NotificationsPulseAndCardsMixin on _NotificationsStateBase {
  // =========================================================================
  // DASHBOARD DE PULSO EJECUTIVO (EN PENDIENTES)
  // =========================================================================

  Widget _buildPulseDashboard(
    List<NotificationModel> allPendientes,
    bool isDark,
  ) {
    final overdueCuotas = allPendientes
        .where(
          (n) =>
              n.objetoRelacionadoTipo == 'cuota' &&
              n.nivelPrioridad == 'critica',
        )
        .toList();
    final upcomingCuotas = allPendientes
        .where(
          (n) =>
              n.objetoRelacionadoTipo == 'cuota' &&
              n.nivelPrioridad == 'preventiva',
        )
        .toList();
    final double totalMoraExigible = overdueCuotas.fold(
      0.0,
      (sum, n) => sum + (n.saldoTotal ?? (n.montoBase ?? 0.0)),
    );
    final int cuotasCount = overdueCuotas.length;
    final int upcomingCount = upcomingCuotas.length;

    final inventoryAlerts = allPendientes
        .where((n) => n.objetoRelacionadoTipo == 'producto')
        .toList();
    final int stockCount = inventoryAlerts.length;
    final int agotadosCount = inventoryAlerts
        .where((n) => n.nivelPrioridad == 'critica')
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // KPI 1: Cobranzas y Mora
          Expanded(
            child: InkWell(
              onTap: () => setState(
                () => _categoryFilter = _categoryFilter == 'Cobranzas'
                    ? 'Todas'
                    : 'Cobranzas',
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.red[900]!.withValues(alpha: 0.25)
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _categoryFilter == 'Cobranzas'
                        ? Colors.red[400]!
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: isDark ? Colors.red[300] : Colors.red[700],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Mora Exigible",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.red[200] : Colors.red[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "S/ ${totalMoraExigible.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.red[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$cuotasCount cuotas vencidas${upcomingCount > 0 ? ' • $upcomingCount por vencer' : ''}",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // KPI 2: Inventario
          Expanded(
            child: InkWell(
              onTap: () => setState(
                () => _categoryFilter = _categoryFilter == 'Inventario'
                    ? 'Todas'
                    : 'Inventario',
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.amber[900]!.withValues(alpha: 0.25)
                      : Colors.amber[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _categoryFilter == 'Inventario'
                        ? Colors.amber[400]!
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: isDark
                              ? Colors.amber[300]
                              : Colors.orange[800],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "Inventario",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.amber[200]
                                  : Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$stockCount alertas",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.orange[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$agotadosCount agotados",
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD PRINCIPAL
  // =========================================================================


  @override
  void _confirmDelete(NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Notificaciones"),
        content: Text(
          "¿Estás seguro de eliminar permanentemente ${_selectedIds.length} notificaciones? Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteMultiple(_selectedIds.toList());
              setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              });
              Navigator.pop(ctx);
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

  @override
  Widget _buildTabContent(
    List<NotificationModel> notifs,
    NotificationProvider prov,
    bool isDark, {
    required int tabIndex,
  }) {
    if (prov.isLoading && notifs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifs.isEmpty) {
      return NotificationEmptyState(isDark: isDark);
    }

    final bool smartGroupingActive = prov.preferences.activarSmartGrouping;
    final bool pulseDashboardActive = prov.preferences.mostrarPulseDashboard;

    // En Pendientes: Agrupación inteligente por cliente si tiene >= 2 cuotas en mora
    Map<int, List<NotificationModel>> multiCuotasByClient = {};
    Set<int> multiCuotaNotificationIds = {};

    if (tabIndex == 0 && smartGroupingActive) {
      for (var n in notifs) {
        if (n.objetoRelacionadoTipo == 'cuota' &&
            n.clientId != null &&
            n.nivelPrioridad == 'critica') {
          multiCuotasByClient.putIfAbsent(n.clientId!, () => []).add(n);
        }
      }
      multiCuotasByClient.removeWhere((_, list) => list.length < 2);
      for (var list in multiCuotasByClient.values) {
        for (var n in list) {
          multiCuotaNotificationIds.add(n.id);
        }
      }
    }

    // Filtrar los items regulares (excluyendo los que están en tarjetas agrupadas en Pendientes)
    final regularNotifs = notifs
        .where((n) => !multiCuotaNotificationIds.contains(n.id))
        .toList();
    final groupedList = _buildGroupedList(regularNotifs);

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      children: [
        // 1. Dashboard de Pulso en Pendientes (si está activo)
        if (tabIndex == 0 && pulseDashboardActive)
          _buildPulseDashboard(notifs, isDark),

        // 2. Tarjetas Maestras de Clientes Agrupados (Smart Grouping)
        if (tabIndex == 0 &&
            smartGroupingActive &&
            multiCuotasByClient.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
            child: Text(
              "COBRANZAS CONSOLIDADAS (${multiCuotasByClient.length})",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.red[300] : Colors.red[800],
              ),
            ),
          ),
          ...multiCuotasByClient.entries.map((entry) {
            final clientCuotas = entry.value;
            final clientName = clientCuotas.first.clientName ?? 'Cliente';
            final clientPhone = clientCuotas.first.clientPhone;
            return _buildGroupedClientMasterCard(
              clientId: entry.key,
              clientName: clientName,
              clientPhone: clientPhone,
              cuotas: clientCuotas,
              isDark: isDark,
              prov: prov,
            );
          }),
        ],

        // 3. Tarjetas Regulares Agrupadas por Fecha con Navegación Segura
        ...groupedList.map((item) {
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text(
                item.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            );
          }

          final notif = item as NotificationModel;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildNotificationCardItem(
              notif,
              prov,
              isDark,
              tabIndex: tabIndex,
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget _buildNotificationCardItem(
    NotificationModel notif,
    NotificationProvider prov,
    bool isDark, {
    required int tabIndex,
  }) {
    return NotificationItemCard(
      notif: notif,
      isDark: isDark,
      isSelected: _selectedIds.contains(notif.id),
      isSelectionMode: _isSelectionMode,
      tabIndex: tabIndex,
      enableSwipeActions:
          prov.preferences.comportamientoSwipe == 'card_actions',
      onArchive: () => _handleArchive(notif, prov),
      onSilence: () => _handleSilence(notif, prov),
      onToggleResolve: () => _handleToggleResolve(notif, prov),
      onShowActions: () => _showCardActionMenu(notif, prov, isDark),
      onLongPress: () {
        if (tabIndex == 2) {
          setState(() {
            _isSelectionMode = true;
            _selectedIds.add(notif.id);
          });
        } else {
          _showCardActionMenu(notif, prov, isDark);
        }
      },
      onTap: () {
        if (_isSelectionMode && tabIndex == 2) {
          setState(() {
            if (_selectedIds.contains(notif.id)) {
              _selectedIds.remove(notif.id);
            } else {
              _selectedIds.add(notif.id);
            }
            if (_selectedIds.isEmpty) _isSelectionMode = false;
          });
        } else {
          _handleDeepLink(notif, context);
        }
      },
      onActionRecordar: notif.objetoRelacionadoTipo == 'cuota'
          ? () => _onActionRecordarCuota(notif)
          : null,
      onActionCobrar: notif.objetoRelacionadoTipo == 'cuota'
          ? () => _onActionCobrarCuota(notif)
          : null,
      onActionMora: notif.objetoRelacionadoTipo == 'cuota'
          ? () => _onActionMoraCuota(notif)
          : null,
      onActionAbastecer: notif.objetoRelacionadoTipo == 'producto'
          ? () => _onActionAbastecer(notif)
          : null,
      onActionKardex: notif.objetoRelacionadoTipo == 'producto'
          ? () => _onActionKardex(notif)
          : null,
      onActionVerCotizacion: notif.objetoRelacionadoTipo == 'cotizacion'
          ? () => _onActionVerCotizacion(notif)
          : null,
      onActionVerPremio: notif.objetoRelacionadoTipo == 'recompensa'
          ? () => _onActionVerPremio(notif)
          : null,
    );
  }

  @override
  void _handleArchive(NotificationModel notif, NotificationProvider prov) {
    prov.archiveNotification(notif.id);
    NotificationToastFeedback.showArchived(
      context,
      title: notif.cleanTitle,
      onUndo: () {
        prov.unarchiveNotification(notif.id);
      },
    );
  }

  @override
  void _handleSilence(NotificationModel notif, NotificationProvider prov) {
    prov.silenceNotification(notif.id);
    NotificationToastFeedback.showSilenced(
      context,
      title: notif.cleanTitle,
      onUndo: () {
        prov.unsilenceNotification(notif.id);
      },
    );
  }

  @override
  void _handleToggleResolve(
    NotificationModel notif,
    NotificationProvider prov,
  ) {
    if (notif.isResolved) {
      prov.markAsUnresolved(notif.id);
      NotificationToastFeedback.showSuccess(
        context,
        "Marcada como pendiente",
        icon: Icons.restart_alt_rounded,
      );
    } else {
      prov.markAsResolved(notif.id);
      NotificationToastFeedback.showResolved(
        context,
        title: notif.cleanTitle,
        onUndo: () {
          prov.markAsUnresolved(notif.id);
        },
      );
    }
  }

}
