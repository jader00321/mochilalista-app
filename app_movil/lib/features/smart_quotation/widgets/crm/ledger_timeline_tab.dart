import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';

part 'ledger_timeline/ledger_timeline_card_mixin.dart';
part 'ledger_timeline/ledger_timeline_modals_mixin.dart';

class LedgerTimelineTab extends StatefulWidget {
  final int? clientId;
  final VoidCallback? onRefresh;

  const LedgerTimelineTab({super.key, this.clientId, this.onRefresh});

  @override
  State<LedgerTimelineTab> createState() => _LedgerTimelineTabState();
}

abstract class _LedgerTimelineTabBase extends State<LedgerTimelineTab> {
  String _selectedFilter = 'all'; // 'all', 'cargo', 'abono', 'devolucion'
  bool _vistaClienteOnly = false; // Modo Vista Cliente (historial limpio)

  void _showEditPagoModal(BuildContext context, LedgerItem item, int clientId);
  void _showDeleteConfirmModal(
    BuildContext context,
    LedgerItem item,
    int clientId,
  );
}

class _LedgerTimelineTabState extends _LedgerTimelineTabBase
    with _LedgerTimelineCardMixin, _LedgerTimelineModalsMixin {
  int _getClientId(TrackingProvider provider) {
    if (widget.clientId != null) return widget.clientId!;
    for (var item in provider.currentClientLedger) {
      if (item.ventaId != null) return item.ventaId!;
    }
    return 0;
  }

  Color get _clientViewColor => Colors.tealAccent.shade700;

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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 56,
                color: isDark ? Colors.white10 : Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text(
                "No hay movimientos registrados",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
    final int devolucionesCount = ledger
        .where((i) => i.subtipo == 'devolucion')
        .length;

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
        _buildFilterToolbar(
          isDark: isDark,
          allCount: allCount,
          cargosCount: cargosCount,
          abonosCount: abonosCount,
          devolucionesCount: devolucionesCount,
        ),

        // Lista de Movimientos con Timeline
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filtered.isEmpty
                ? Center(
                    key: ValueKey(
                      'empty_${_selectedFilter}_$_vistaClienteOnly',
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
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
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
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
                    padding: const EdgeInsets.only(
                      top: 16,
                      bottom: 140,
                      left: 16,
                      right: 16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildLedgerTimelineRow(
                      context: context,
                      item: filtered[index],
                      isLast: index == filtered.length - 1,
                      effectiveClientId: effectiveClientId,
                      isDark: isDark,
                      cardColor: cardColor,
                      textColor: textColor,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToolbar({
    required bool isDark,
    required int allCount,
    required int cargosCount,
    required int abonosCount,
    required int devolucionesCount,
  }) {
    return Container(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _vistaClienteOnly
                          ? (_clientViewColor.withValues(
                              alpha: isDark ? 0.3 : 0.15,
                            ))
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.white),
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
                          _vistaClienteOnly
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 15,
                          color: _vistaClienteOnly
                              ? _clientViewColor
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Vista Cliente",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _vistaClienteOnly
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: _vistaClienteOnly
                                ? _clientViewColor
                                : (isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700]),
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
                border: Border.all(
                  color: _clientViewColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: _clientViewColor,
                  ),
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
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
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
