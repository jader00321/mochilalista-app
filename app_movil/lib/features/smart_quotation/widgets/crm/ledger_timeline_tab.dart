import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class LedgerTimelineTab extends StatefulWidget {
  const LedgerTimelineTab({super.key});

  @override
  State<LedgerTimelineTab> createState() => _LedgerTimelineTabState();
}

class _LedgerTimelineTabState extends State<LedgerTimelineTab> {
  String _selectedFilter = 'all'; // 'all', 'cargo', 'abono', 'devolucion'

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoadingLedger) {
      return const Center(child: CircularProgressIndicator());
    }

    final ledger = provider.currentClientLedger;

    if (ledger.isEmpty) {
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

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

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

    return Column(
      children: [
        // 🏆 Timeline Financiero Segmentado (Pestañas/Chips animados)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141C) : Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
          ),
          child: SingleChildScrollView(
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
              ],
            ),
          ),
        ),

        // Lista Animada
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: filtered.isEmpty
                ? Center(
                    key: ValueKey('empty_$_selectedFilter'),
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
                    key: ValueKey('list_$_selectedFilter'),
                    padding: const EdgeInsets.only(top: 16, bottom: 100, left: 16, right: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final bool isCargo = item.tipo == "cargo";
                      final bool isLast = index == filtered.length - 1;

                      IconData iconData = isCargo ? Icons.arrow_upward : Icons.arrow_downward;
                      Color highlightColor = isCargo
                          ? (isDark ? Colors.red[400]! : Colors.red)
                          : (isDark ? Colors.green[400]! : Colors.green);

                      if (item.subtipo == 'prestamo') {
                        iconData = Icons.account_balance;
                        highlightColor = isDark ? Colors.orange[400]! : Colors.orange[700]!;
                      } else if (item.subtipo == 'devolucion') {
                        iconData = Icons.undo;
                        highlightColor = isDark ? Colors.purple[300]! : Colors.purple[700]!;
                      } else if (item.subtipo == 'retiro_saldo') {
                        iconData = Icons.output;
                        highlightColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
                      } else if (item.subtipo == 'venta') {
                        iconData = Icons.receipt_long;
                      }

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                      size: 18,
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
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
                                                height: 1.2,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            isCargo
                                                ? "- ${currency.format(item.monto)}"
                                                : "+ ${currency.format(item.monto)}",
                                            style: TextStyle(
                                              color: highlightColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(
                                        height: 1,
                                        color: isDark ? Colors.white10 : Colors.grey[200],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          Text(
                                            DateFormat('dd MMM yyyy - hh:mm a').format(item.fecha),
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: item.saldoResultante < 0
                                                  ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber[50])
                                                  : (isDark ? Colors.blueGrey.withValues(alpha: 0.2) : Colors.blueGrey[50]),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              item.saldoResultante < 0
                                                  ? "Saldo a Favor: ${currency.format(item.saldoResultante.abs())}"
                                                  : "Saldo Deuda: ${currency.format(item.saldoResultante)}",
                                              style: TextStyle(
                                                color: item.saldoResultante < 0
                                                    ? (isDark ? Colors.amber[300] : Colors.amber[800])
                                                    : (isDark ? Colors.blueGrey[200] : Colors.blueGrey[800]),
                                                fontSize: 13,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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