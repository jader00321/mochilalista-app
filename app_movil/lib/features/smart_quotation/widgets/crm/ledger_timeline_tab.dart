import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class LedgerTimelineTab extends StatefulWidget {
  final int? clientId;
  final VoidCallback? onRefresh;

  const LedgerTimelineTab({
    super.key,
    this.clientId,
    this.onRefresh,
  });

  @override
  State<LedgerTimelineTab> createState() => _LedgerTimelineTabState();
}

class _LedgerTimelineTabState extends State<LedgerTimelineTab> {
  String _selectedFilter = 'all'; // 'all', 'cargo', 'abono', 'devolucion'
  bool _vistaClienteOnly = false; // Modo Vista Cliente (historial limpio)

  int _getClientId(TrackingProvider provider) {
    if (widget.clientId != null) return widget.clientId!;
    for (var item in provider.currentClientLedger) {
      if (item.ventaId != null) return item.ventaId!;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    final rawLedger = provider.currentClientLedger;

    if (rawLedger.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No hay movimientos registrados",
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Filtrar por Vista Cliente (oculta eventos informativos o anotaciones internas)
    final ledger = _vistaClienteOnly
        ? rawLedger.where((i) => i.tipo != 'evento').toList()
        : rawLedger;

    final int allCount = ledger.length;
    final int cargosCount = ledger.where((i) => i.tipo == 'cargo').length;
    final int abonosCount = ledger.where((i) => i.tipo == 'abono').length;
    final int devolucionesCount = ledger.where((i) => i.subtipo == 'devolucion').length;

    List<LedgerItem> filtered;
    switch (_selectedFilter) {
      case 'cargo':
        filtered = ledger.where((i) => i.tipo == 'cargo').toList();
        break;
      case 'abono':
        filtered = ledger.where((i) => i.tipo == 'abono').toList();
        break;
      case 'devolucion':
        filtered = ledger.where((i) => i.subtipo == 'devolucion').toList();
        break;
      default:
        filtered = ledger;
    }

    final effectiveClientId = _getClientId(provider);

    return Column(
      children: [
        // Barra Superior: Filtros Segmentados y Toggle Modo Vista Cliente
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141C) : Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSegmentChip(
                      id: 'all',
                      label: 'Todos',
                      count: allCount,
                      icon: Icons.receipt_long_rounded,
                      color: Colors.blueAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentChip(
                      id: 'cargo',
                      label: 'Cargos',
                      count: cargosCount,
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.redAccent,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildSegmentChip(
                      id: 'abono',
                      label: 'Abonos',
                      count: abonosCount,
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                    if (devolucionesCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildSegmentChip(
                        id: 'devolucion',
                        label: 'Devoluciones',
                        count: devolucionesCount,
                        icon: Icons.undo_rounded,
                        color: Colors.purpleAccent,
                        isDark: isDark,
                      ),
                    ],
                    const SizedBox(width: 12),
                    // Toggle Vista Cliente (Historial Limpio para mostrar al cliente)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _vistaClienteOnly = !_vistaClienteOnly;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _vistaClienteOnly
                              ? (_clientViewColor.withValues(alpha: isDark ? 0.3 : 0.15))
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _vistaClienteOnly
                                ? _clientViewColor
                                : (isDark ? Colors.white12 : Colors.grey.shade300),
                            width: _vistaClienteOnly ? 1.6 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _vistaClienteOnly ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 15,
                              color: _vistaClienteOnly ? _clientViewColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Vista Cliente",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _vistaClienteOnly ? FontWeight.bold : FontWeight.w500,
                                color: _vistaClienteOnly ? _clientViewColor : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_vistaClienteOnly) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _clientViewColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _clientViewColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 14, color: _clientViewColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Modo Vista Cliente activo: historial depurado sin registros internos.",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _clientViewColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Lista de Movimientos con Timeline
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filtered.isEmpty
                ? Center(
                    key: ValueKey('empty_${_selectedFilter}_$_vistaClienteOnly'),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.filter_list_off_rounded,
                            size: 54,
                            color: isDark ? Colors.grey[700] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No hay movimientos para este filtro",
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('list_${_selectedFilter}_$_vistaClienteOnly'),
                    padding: const EdgeInsets.only(top: 16, bottom: 140, left: 16, right: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final bool isCargo = item.tipo == "cargo";
                      final bool isEvento = item.tipo == "evento";
                      final bool isLast = index == filtered.length - 1;

                      IconData iconData = isCargo ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
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
                                    child: Icon(
                                      iconData,
                                      size: 17,
                                      color: highlightColor,
                                    ),
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
                                            Text(
                                              isCargo
                                                  ? "- ${AppCurrency.format(item.monto)}"
                                                  : (isEvento
                                                      ? "+ ${AppCurrency.format(item.monto)}"
                                                      : "+ ${AppCurrency.format(item.monto)}"),
                                              style: TextStyle(
                                                color: highlightColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                          // Menú de Gestión Rápida (⋮) para Edición y Reversión
                                          if (item.canEdit || item.canDelete)
                                            _buildActionMenu(context, item, effectiveClientId, isDark),
                                        ],
                                      ),

                                      // Badges y Metadatos (Chips de Método de Pago, Histórico, etc.)
                                      if (!isEvento) ...[
                                        const SizedBox(height: 8),
                                        _buildItemMetadataChips(item, isDark),
                                      ],

                                      // Desglose de Préstamo con Mora Activa
                                      if (isCargo && item.moraMonto != null && item.moraMonto! > 0.01) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.warning_amber_rounded, size: 14, color: isDark ? Colors.orange[300] : Colors.orange[800]),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  "Base: ${AppCurrency.format(item.montoBase ?? item.monto)} • + Mora: ${AppCurrency.format(item.moraMonto!)}",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.orange[300] : Colors.orange[800],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Nota o Descripción de Evento
                                      if (item.nota != null && item.nota!.isNotEmpty && !_isRedundantNota(item)) ...[
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
                                            DateFormat('dd MMM yyyy - hh:mm a').format(item.fecha),
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (!isEvento)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: item.saldoResultante < 0
                                                    ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber[50])
                                                    : (isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.blueGrey[50]),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.saldoResultante < 0
                                                    ? "Saldo a Favor: ${AppCurrency.format(item.saldoResultante.abs())}"
                                                    : "Saldo Deuda: ${AppCurrency.format(item.saldoResultante)}",
                                                style: TextStyle(
                                                  color: item.saldoResultante < 0
                                                      ? (isDark ? Colors.amber[300] : Colors.amber[800])
                                                      : (isDark ? Colors.blueGrey[200] : Colors.blueGrey[800]),
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
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Color get _clientViewColor => Colors.tealAccent.shade700;

  bool _isRedundantNota(LedgerItem item) {
    if (item.nota == null) return true;
    final n = item.nota!.toLowerCase().trim();
    final d = item.detalle.toLowerCase().trim();
    return d.contains(n) || n == d;
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
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(mIcon, size: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 12, color: Colors.blueAccent),
              const SizedBox(width: 4),
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

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: chips,
    );
  }

  Widget _buildActionMenu(BuildContext context, LedgerItem item, int clientId, bool isDark) {
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
          PopupMenuItem(
            value: 'edit',
            height: 40,
            child: Row(
              children: [
                const Icon(Icons.edit_rounded, size: 17, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text(
                  'Corregir / Editar Abono',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  item.tipo == 'cargo'
                      ? (item.subtipo == 'prestamo' ? 'Revertir Préstamo' : 'Revertir Venta')
                      : (item.tipo == 'evento' ? 'Descartar Registro' : 'Revertir / Eliminar Abono'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showEditPagoModal(BuildContext context, LedgerItem item, int clientId) {
    if (item.pagoId == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final montoCtrl = TextEditingController(text: item.monto.toStringAsFixed(2));
    final notaCtrl = TextEditingController(text: item.nota ?? '');
    String metodoSeleccionado = item.metodoPago ?? 'Efectivo';
    DateTime fechaSeleccionada = item.fecha;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final mediaQuery = MediaQuery.of(context);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: mediaQuery.viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              "Corregir / Editar Abono",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Advertencia de Recálculo en Cascada
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Al guardar, se recalculará automáticamente la cuota, la venta asociada y el saldo del cliente.",
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monto
                    const Text("Monto del Abono (S/)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Método de Pago
                    const Text("Método de Pago", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ['Efectivo', 'Yape', 'Plin', 'Transferencia'].map((met) {
                        final isSel = metodoSeleccionado.toLowerCase() == met.toLowerCase();
                        return ChoiceChip(
                          label: Text(met),
                          selected: isSel,
                          onSelected: (sel) {
                            if (sel) setModalState(() => metodoSeleccionado = met);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Fecha de Pago
                    const Text("Fecha del Pago", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => fechaSeleccionada = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(fechaSeleccionada)),
                            const Icon(Icons.calendar_today_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nota Explicativa
                    const Text("Nota / Motivo de Corrección", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notaCtrl,
                      decoration: InputDecoration(
                        hintText: "Ej. Corrección por error de digitación",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text("Guardar Cambios", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final nuevoMonto = double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
                          if (nuevoMonto <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("El monto debe ser mayor a 0")),
                            );
                            return;
                          }

                          Navigator.of(modalCtx).pop();

                          final prov = Provider.of<TrackingProvider>(context, listen: false);
                          final ok = await prov.editarPago(
                            clientId,
                            item.pagoId!,
                            nuevoMonto: nuevoMonto,
                            nuevoMetodoPago: metodoSeleccionado,
                            nuevaFechaPago: fechaSeleccionada,
                            nuevaNota: notaCtrl.text.trim().isNotEmpty ? notaCtrl.text.trim() : null,
                          );

                          if (ok) {
                            widget.onRefresh?.call();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Abono corregido con éxito"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No se pudo corregir el abono"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmModal(BuildContext context, LedgerItem item, int clientId) {
    String title = "¿Confirmar Eliminación?";
    String content = "Esta acción modificará los saldos contables.";
    String confirmLabel = "Eliminar";

    if (item.tipo == 'cargo') {
      final String opName = item.subtipo == 'prestamo' ? 'Préstamo' : 'Venta';
      title = "¿Revertir este $opName?";
      content = "Se revertirá la operación de ${AppCurrency.format(item.monto)} y sus cronogramas asociados. La deuda del cliente se recalculará automáticamente.";
      confirmLabel = "Revertir $opName";
    } else if (item.tipo == 'abono') {
      title = "¿Revertir este Abono?";
      content = "Se anulará el abono de ${AppCurrency.format(item.monto)}. La deuda del cliente aumentará y la cuota volverá a estar pendiente.";
      confirmLabel = "Revertir Abono";
    } else if (item.tipo == 'evento') {
      title = "¿Descartar Registro?";
      content = "Este registro informativo se eliminará del historial contable.";
      confirmLabel = "Descartar";
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(dlgCtx).pop();
              final prov = Provider.of<TrackingProvider>(context, listen: false);
              bool ok = false;

              if (item.tipo == 'cargo' && item.ventaId != null) {
                ok = await prov.revertirVentaOPrestamo(clientId, item.ventaId!);
              } else if (item.tipo == 'abono' && item.pagoId != null) {
                ok = await prov.revertirPago(clientId, item.pagoId!);
              } else if (item.tipo == 'evento' && item.eventoId != null) {
                ok = await prov.eliminarEventoFinanciero(clientId, item.eventoId!);
              }

              if (ok) {
                widget.onRefresh?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Operación revertida con éxito"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("No se pudo completar la reversión"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentChip({
    required String id,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final bool isSelected = _selectedFilter == id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilter = id;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDark ? Colors.white12 : Colors.grey.shade300),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : color)
                        : (isDark ? Colors.grey[300] : Colors.grey[700]),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
