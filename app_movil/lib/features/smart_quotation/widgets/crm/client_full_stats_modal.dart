import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/app_feedback_helper.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/repositories/client_repository.dart';
import 'package:app_movil/features/smart_quotation/services/client_stats_export_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart';

part 'client_stats/client_full_stats_cards_mixin.dart';
part 'client_stats/client_full_stats_export_and_cancellations_mixin.dart';
part 'client_stats/client_full_stats_sections_mixin.dart';

enum TimeFilter { allTime, sixMonths, oneMonth, oneWeek, custom }

class ClientFullStatsModal extends StatefulWidget {
  final ClientModel client;
  final bool isDark;

  const ClientFullStatsModal({
    super.key,
    required this.client,
    required this.isDark,
  });

  @override
  State<ClientFullStatsModal> createState() => _ClientFullStatsModalState();
}

abstract class _ClientFullStatsModalBase extends State<ClientFullStatsModal> {
  TimeFilter _currentFilter = TimeFilter.allTime;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  Map<String, dynamic>? _cancellationStats;
  List<SaleSummary> _allSales = [];
  bool _isLoadingSales = true;
  String? _selectedBalanceSegment; // 'compras', 'abonos', 'saldo'

  List<SaleSummary> _filterSalesByRange({required bool loansOnly}) {
    DateTime now = DateTime.now();
    DateTime start = DateTime(2000);
    DateTime end = now;

    switch (_currentFilter) {
      case TimeFilter.oneWeek:
        start = now.subtract(const Duration(days: 7));
        break;
      case TimeFilter.oneMonth:
        start = now.subtract(const Duration(days: 30));
        break;
      case TimeFilter.sixMonths:
        start = now.subtract(const Duration(days: 180));
        break;
      case TimeFilter.custom:
        start = _customStartDate ?? DateTime(2000);
        end = _customEndDate ?? now;
        break;
      case TimeFilter.allTime:
        break;
    }

    // Normalizar fechas para evitar problemas con la hora
    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _allSales.where((sale) {
      final isLoan = sale.origenVenta == 'prestamo_personal';
      if (isLoan != loansOnly) return false;
      DateTime saleDate = DateTime.tryParse(sale.date) ?? now;
      return saleDate.isAfter(
            cleanStart.subtract(const Duration(seconds: 1)),
          ) &&
          saleDate.isBefore(cleanEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<SaleSummary> get _filteredSales => _filterSalesByRange(loansOnly: false);

  List<SaleSummary> get _filteredLoans => _filterSalesByRange(loansOnly: true);

  Widget _buildStatCard(
    String title,
    double value,
    IconData icon,
    Color color, {
    bool isInt = false,
    String? textValue,
  });

  Widget _buildCommercialBalanceCard({
    required double totalComprado,
    required double totalPagado,
    required double tasaCobro,
    required double saldoPendiente,
    required bool isDark,
  });

  String _calculatePurchaseFrequency(List<SaleSummary> salesList);
}

class _ClientFullStatsModalState extends _ClientFullStatsModalBase
    with
        _ClientFullStatsCardsMixin,
        _ClientFullStatsSectionsMixin,
        _ClientFullStatsExportAndCancellationsMixin {
  @override
  void initState() {
    super.initState();
    _allSales = widget.client.lastSales;
    _loadAllSales();
    _loadCancellationStats();
  }

  Future<void> _loadAllSales() async {
    try {
      final repo = ClientRepository();
      final rows = await repo.getClientSales(widget.client.id, limit: 10000);
      if (mounted) {
        setState(() {
          if (rows.isNotEmpty || _allSales.isEmpty) {
            _allSales = rows.map((e) => SaleSummary.fromJson(e)).toList();
          }
          _isLoadingSales = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingSales = false;
        });
      }
    }
  }

  Future<void> _loadCancellationStats() async {
    try {
      final repo = ClientRepository();
      final stats = await repo.getClientCancellationStats(widget.client.id);
      if (mounted) {
        setState(() {
          _cancellationStats = stats;
        });
      }
    } catch (_) {}
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: widget.isDark
                ? const ColorScheme.dark(
                    primary: Colors.blueAccent,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E28),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Colors.blue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _currentFilter = TimeFilter.custom;
      });
    }
  }

  Widget _buildFilterChip(
    String label,
    TimeFilter filterValue, {
    IconData? icon,
  }) {
    final isSelected = _currentFilter == filterValue;
    final fgColor = isSelected
        ? Colors.white
        : (widget.isDark ? Colors.white70 : Colors.black87);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        key: ValueKey(isSelected),
        onTap: () {
          if (filterValue == TimeFilter.custom) {
            _selectCustomDateRange(context);
          } else {
            setState(() {
              _currentFilter = filterValue;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (widget.isDark ? Colors.blue[600] : Colors.blue[700])
                : (widget.isDark ? Colors.white10 : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected && !widget.isDark
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fgColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fgColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sales = _filteredSales;
    final loans = _filteredLoans;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF14141C)
                : const Color(0xFFF5F7FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Grabber Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Analítica del Cliente",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.file_download,
                        color: widget.isDark
                            ? Colors.blueAccent
                            : Colors.blue[700],
                      ),
                      tooltip: "Exportar Reporte",
                      onSelected: (value) {
                        if (value == 'pdf') _exportReport(true);
                        if (value == 'csv') _exportReport(false);
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: Colors.red),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Descargar PDF Profesional',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'csv',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart, color: Colors.green),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Descargar Excel (CSV)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Time Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 24, right: 32),
                child: Row(
                  children: [
                    _buildFilterChip("Todo", TimeFilter.allTime),
                    const SizedBox(width: 8),
                    _buildFilterChip("6 Meses", TimeFilter.sixMonths),
                    const SizedBox(width: 8),
                    _buildFilterChip("Mes", TimeFilter.oneMonth),
                    const SizedBox(width: 8),
                    _buildFilterChip("Semana", TimeFilter.oneWeek),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      "Rango",
                      TimeFilter.custom,
                      icon: Icons.date_range_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: _isLoadingSales
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildPerformanceAndGlobalSections(sales, loans),
                          if (_cancellationStats != null &&
                              (_cancellationStats!['anuladas'] ?? 0) > 0)
                            _buildCancellationAnalysisSection(),
                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
