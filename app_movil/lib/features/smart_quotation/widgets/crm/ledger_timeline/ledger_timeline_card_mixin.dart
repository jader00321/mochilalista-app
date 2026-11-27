part of '../ledger_timeline_tab.dart';

class _LedgerEventVisual {
  final IconData iconData;
  final Color highlightColor;
  const _LedgerEventVisual({
    required this.iconData,
    required this.highlightColor,
  });
}

mixin _LedgerTimelineCardMixin on _LedgerTimelineTabBase {
  bool _isRedundantNota(LedgerItem item) {
    if (item.nota == null) return true;
    final n = item.nota!.toLowerCase().trim();
    final d = item.detalle.toLowerCase().trim();
    return d.contains(n) || n == d;
  }

  _LedgerEventVisual _resolveEventVisual(LedgerItem item, bool isDark) {
    final bool isCargo = item.tipo == "cargo";
    final bool isEvento = item.tipo == "evento";

    IconData iconData = isCargo
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;
    Color highlightColor = isCargo
        ? (isDark ? Colors.red[400]! : Colors.red)
        : (isDark ? Colors.green[400]! : Colors.green);

    if (item.subtipo == 'prestamo') {
      iconData = Icons.account_balance_rounded;
      highlightColor = isDark ? Colors.orange[400]! : Colors.orange[700]!;
    } else if (item.subtipo == 'devolucion') {
      iconData = Icons.undo_rounded;
      highlightColor = isDark ? Colors.purple[300]! : Colors.purple[700]!;
    } else if (item.subtipo == 'retiro_saldo') {
      iconData = Icons.output_rounded;
      highlightColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
    } else if (item.subtipo == 'venta') {
      iconData = Icons.receipt_long_rounded;
    } else if (isEvento) {
      highlightColor = isDark ? Colors.amber[400]! : Colors.amber[800]!;
      if (item.tipoEvento == 'mora_aplicada') {
        iconData = Icons.trending_up_rounded;
      } else if (item.tipoEvento == 'mora_condonada') {
        iconData = Icons.verified_rounded;
        highlightColor = Colors.green;
      } else if (item.tipoEvento == 'reprogramacion_fecha') {
        iconData = Icons.edit_calendar_rounded;
        highlightColor = Colors.blueAccent;
      } else {
        iconData = Icons.info_outline_rounded;
      }
    }

    return _LedgerEventVisual(
      iconData: iconData,
      highlightColor: highlightColor,
    );
  }

  Widget _buildLedgerTimelineRow({
    required BuildContext context,
    required LedgerItem item,
    required bool isLast,
    required int effectiveClientId,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    final bool isCargo = item.tipo == "cargo";
    final bool isEvento = item.tipo == "evento";
    final visual = _resolveEventVisual(item, isDark);
    final IconData iconData = visual.iconData;
    final Color highlightColor = visual.highlightColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nodo y Línea de Conexión del Timeline
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: highlightColor, width: 2),
                  ),
                  child: Icon(iconData, size: 17, color: highlightColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? Colors.white10 : Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Tarjeta de Información
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEvento
                        ? highlightColor.withValues(alpha: 0.3)
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila Superior: Título, Monto y Menú de Acciones
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.detalle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textColor,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isEvento || item.monto > 0.001)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 115),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                isCargo
                                    ? "- ${AppCurrency.format(item.monto)}"
                                    : "+ ${AppCurrency.format(item.monto)}",
                                style: TextStyle(
                                  color: highlightColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        // Menú de Gestión Rápida (⋮) para Edición y Reversión
                        if (item.canEdit || item.canDelete)
                          _buildActionMenu(
                            context,
                            item,
                            effectiveClientId,
                            isDark,
                          ),
                      ],
                    ),

                    // Badges y Metadatos (Chips de Método de Pago, Histórico, etc.)
                    if (!isEvento) ...[
                      const SizedBox(height: 8),
                      _buildItemMetadataChips(item, isDark),
                    ],

                    // Desglose de Préstamo con Mora Activa
                    if (isCargo &&
                        item.moraMonto != null &&
                        item.moraMonto! > 0.01) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.orange[300]
                                  : Colors.orange[800],
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Base: ${AppCurrency.format(item.montoBase ?? item.monto)} • + Mora: ${AppCurrency.format(item.moraMonto!)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.orange[300]
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Nota o Descripción de Evento
                    if (item.nota != null &&
                        item.nota!.isNotEmpty &&
                        !_isRedundantNota(item)) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.nota!,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.grey[200],
                    ),
                    const SizedBox(height: 10),

                    // Pie de Tarjeta: Fecha del Registro y Saldo Acumulado
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Text(
                          AppDateFormatter.ddMMMyyyyDashHhmma.format(
                            item.fecha,
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (!isEvento)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: item.saldoResultante < 0
                                  ? (isDark
                                        ? Colors.amber.withValues(alpha: 0.2)
                                        : Colors.amber[50])
                                  : (isDark
                                        ? Colors.blueGrey.withValues(alpha: 0.2)
                                        : Colors.blueGrey[50]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.saldoResultante < 0
                                  ? "Saldo a Favor: ${AppCurrency.format(item.saldoResultante.abs())}"
                                  : "Saldo Deuda: ${AppCurrency.format(item.saldoResultante)}",
                              style: TextStyle(
                                color: item.saldoResultante < 0
                                    ? (isDark
                                          ? Colors.amber[300]
                                          : Colors.amber[800])
                                    : (isDark
                                          ? Colors.blueGrey[200]
                                          : Colors.blueGrey[800]),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildItemMetadataChips(LedgerItem item, bool isDark) {
    final List<Widget> chips = [];

    // Chip de Método de Pago
    if (item.metodoPago != null && item.metodoPago!.isNotEmpty) {
      final m = item.metodoPago!.toLowerCase();
      IconData mIcon = Icons.payments_rounded;
      String mLabel = item.metodoPago!;

      if (m.contains('efectivo')) {
        mIcon = Icons.payments_rounded;
        mLabel = 'Efectivo';
      } else if (m.contains('yape')) {
        mIcon = Icons.phone_android_rounded;
        mLabel = 'Yape';
      } else if (m.contains('plin')) {
        mIcon = Icons.phone_android_rounded;
        mLabel = 'Plin';
      } else if (m.contains('transferencia') || m.contains('banco')) {
        mIcon = Icons.account_balance_rounded;
        mLabel = 'Transferencia';
      } else if (m.contains('saldo')) {
        mIcon = Icons.account_balance_wallet_rounded;
        mLabel = 'Saldo a Favor';
      }

      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mIcon,
                size: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                mLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Chip de Histórico (para abonos retroactivos)
    if (item.nota != null && item.nota!.toLowerCase().contains('histórico')) {
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 12, color: Colors.blueAccent),
              SizedBox(width: 4),
              Text(
                "Histórico",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 4, children: chips);
  }

  Widget _buildActionMenu(
    BuildContext context,
    LedgerItem item,
    int clientId,
    bool isDark,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF282836) : Colors.white,
      onSelected: (val) {
        if (val == 'edit') {
          _showEditPagoModal(context, item, clientId);
        } else if (val == 'delete') {
          _showDeleteConfirmModal(context, item, clientId);
        }
      },
      itemBuilder: (ctx) => [
        if (item.canEdit)
          const PopupMenuItem(
            value: 'edit',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.edit_rounded, size: 17, color: Colors.blueAccent),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Corregir / Editar Abono',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (item.canDelete)
          PopupMenuItem(
            value: 'delete',
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    item.tipo == 'cargo'
                        ? (item.subtipo == 'prestamo'
                              ? 'Revertir Préstamo'
                              : 'Revertir Venta')
                        : (item.tipo == 'evento'
                              ? 'Descartar Registro'
                              : 'Revertir / Eliminar Abono'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
