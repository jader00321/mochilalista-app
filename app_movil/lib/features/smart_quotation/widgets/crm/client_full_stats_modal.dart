import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_stats_export_service.dart';
import 'package:app_movil/features/smart_quotation/repositories/client_repository.dart';

enum TimeFilter {
  allTime,
  sixMonths,
  oneMonth,
  oneWeek,
  custom
}

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

class _ClientFullStatsModalState extends State<ClientFullStatsModal> {
  TimeFilter _currentFilter = TimeFilter.allTime;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  Map<String, dynamic>? _cancellationStats;
  List<SaleSummary> _allSales = [];
  bool _isLoadingSales = true;
  String? _selectedBalanceSegment; // 'compras', 'abonos', 'saldo'

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

  List<SaleSummary> get _filteredSales {
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
      if (sale.origenVenta == 'prestamo_personal') return false;
      DateTime saleDate = DateTime.tryParse(sale.date) ?? now;
      return saleDate.isAfter(cleanStart.subtract(const Duration(seconds: 1))) && 
             saleDate.isBefore(cleanEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  List<SaleSummary> get _filteredLoans {
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

    final cleanStart = DateTime(start.year, start.month, start.day);
    final cleanEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _allSales.where((sale) {
      if (sale.origenVenta != 'prestamo_personal') return false;
      DateTime saleDate = DateTime.tryParse(sale.date) ?? now;
      return saleDate.isAfter(cleanStart.subtract(const Duration(seconds: 1))) && 
             saleDate.isBefore(cleanEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  Future<void> _exportReport(bool isPdf) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Generando reporte ${isPdf ? 'PDF' : 'CSV'}... esto puede tardar unos segundos."), duration: const Duration(seconds: 2))
    );

    try {
      final businessName = authProvider.currentBusiness?.commercialName ?? authProvider.user?.fullName ?? 'Mi Negocio';
      
      String periodText = "Todo el tiempo";
      if (_currentFilter == TimeFilter.oneWeek) {
        periodText = "Últimos 7 días";
      } else if (_currentFilter == TimeFilter.oneMonth) {
        periodText = "Últimos 30 días";
      } else if (_currentFilter == TimeFilter.sixMonths) {
        periodText = "Últimos 6 meses";
      } else if (_currentFilter == TimeFilter.custom && _customStartDate != null && _customEndDate != null) {
        periodText = "${DateFormat('dd/MM/yy').format(_customStartDate!)} - ${DateFormat('dd/MM/yy').format(_customEndDate!)}";
      }

      final filtered = _filteredSales;

      // Extract top products from the filtered sales
      // Map<String, int> productCounts = {};
      
      var file = isPdf 
          ? await ClientStatsExportService.exportToPdf(
              client: widget.client,
              filteredSales: filtered,
              businessName: businessName,
              dateRangeText: periodText,
              extraStats: {'top_products': []} // Ideally we'd calculate this from items, but we only have SaleSummary here.
            )
          : await ClientStatsExportService.exportToCsv(
              client: widget.client,
              filteredSales: filtered,
              businessName: businessName,
              dateRangeText: periodText,
              extraStats: {'top_products': []}
            );

      if (!mounted) return;
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: 'Adjunto el reporte de estadísticas de ${widget.client.fullName}.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
    }
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
              ? const ColorScheme.dark(primary: Colors.blueAccent, onPrimary: Colors.white, surface: Color(0xFF1E1E28), onSurface: Colors.white)
              : const ColorScheme.light(primary: Colors.blue, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black87),
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

  Widget _buildFilterChip(String label, TimeFilter filterValue) {
    final isSelected = _currentFilter == filterValue;
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
                ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected 
                  ? Colors.white 
                  : (widget.isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedNumber(double targetValue, {required String prefix, Color? color, bool isInt = false}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        String formatted;
        if (isInt) {
          formatted = value.toInt().toString();
        } else {
          formatted = AppCurrency.format(value);
        }
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatted, 
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.w900, 
              color: color ?? (widget.isDark ? Colors.white : Colors.black87)
            )
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color, {bool isInt = false, String? textValue}) {
    final bool isVeryLong = title.length > 16;
    final double titleFontSize = isVeryLong ? 10.0 : 11.2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: widget.isDark ? 0.22 : 0.35)),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isVeryLong ? 155.0 : 125.0),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: widget.isDark ? Colors.grey[300] : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: widget.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          textValue != null
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    textValue,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                )
              : _buildAnimatedNumber(value, prefix: isInt ? '' : 'S/ ', color: color, isInt: isInt),
        ],
      ),
    );
  }

  String _calculatePurchaseFrequency(List<SaleSummary> salesList) {
    final salesOnly = salesList.where((s) => s.origenVenta != 'prestamo_personal').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (salesOnly.isEmpty) return "Sin compras";
    if (salesOnly.length == 1) return "Compra única";

    final firstDate = DateTime.tryParse(salesOnly.first.date);
    final lastDate = DateTime.tryParse(salesOnly.last.date);
    if (firstDate == null || lastDate == null) return "N/A";

    final totalDays = lastDate.difference(firstDate).inDays;
    if (totalDays <= 0) return "Mismo día";

    final double avgDays = totalDays / (salesOnly.length - 1);
    if (avgDays < 1.5) return "Diaria (~1 día)";
    if (avgDays >= 6.0 && avgDays <= 8.5) return "Semanal (~7 días)";
    if (avgDays >= 13.0 && avgDays <= 17.0) return "Quincenal (~15 días)";
    if (avgDays >= 28.0 && avgDays <= 33.0) return "Mensual (~30 días)";

    return "Cada ${avgDays.round()} días";
  }

  Widget _buildCommercialBalanceCard({
    required double totalComprado,
    required double totalPagado,
    required double tasaCobro,
    required double saldoPendiente,
    required bool isDark,
  }) {
    final Color badgeColor = tasaCobro >= 80
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : (tasaCobro >= 50
            ? (isDark ? Colors.amberAccent : Colors.amber.shade800)
            : (isDark ? Colors.redAccent : Colors.red.shade700));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera en 2 líneas responsivas para evitar cualquier desbordamiento o truncamiento
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.compare_arrows_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Comparativa Compras vs. Abonos",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  "${tasaCobro.toStringAsFixed(1)}% Cubierto",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Barra Segmentada Dual Animada: Verde Esmeralda (Abonos) vs. Rojo Coral (Saldo Pendiente)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (context, anim, _) {
                  final double paidRatio = totalComprado > 0 ? (totalPagado / totalComprado).clamp(0.0, 1.0) : 1.0;
                  final double pendingRatio = totalComprado > 0 ? (saldoPendiente / totalComprado).clamp(0.0, 1.0) : 0.0;
                  
                  final int paidFlex = (paidRatio * 1000 * anim).round();
                  final int pendingFlex = (pendingRatio * 1000 * anim).round();

                  return Row(
                    children: [
                      if (paidFlex > 0)
                        Expanded(
                          flex: paidFlex,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF00E676), const Color(0xFF00B0FF).withValues(alpha: 0.7)]
                                    : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                              ),
                            ),
                          ),
                        ),
                      if (paidFlex > 0 && pendingFlex > 0)
                        Container(width: 2, height: 12, color: isDark ? const Color(0xFF1E1E28) : Colors.white),
                      if (pendingFlex > 0)
                        Expanded(
                          flex: pendingFlex,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFFFF5252), const Color(0xFFFF7043)]
                                    : [Colors.red.shade400, Colors.deepOrange.shade400],
                              ),
                            ),
                          ),
                        ),
                      if (paidFlex == 0 && pendingFlex == 0)
                        Expanded(
                          child: Container(
                            color: isDark ? Colors.white10 : Colors.grey[300],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Métodos y Resumen con Interactividad Táctil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedBalanceSegment = _selectedBalanceSegment == 'compras' ? null : 'compras';
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: _selectedBalanceSegment == 'compras'
                          ? (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Total Compras", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(totalComprado),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: isDark ? Colors.white10 : Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedBalanceSegment = _selectedBalanceSegment == 'abonos' ? null : 'abonos';
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: _selectedBalanceSegment == 'abonos'
                          ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.shade50)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text("Total Abonos", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(totalPagado),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.green[300] : Colors.green[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: isDark ? Colors.white10 : Colors.grey.shade200),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedBalanceSegment = _selectedBalanceSegment == 'saldo' ? null : 'saldo';
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: _selectedBalanceSegment == 'saldo'
                          ? (isDark ? Colors.red.withValues(alpha: 0.15) : Colors.red.shade50)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("Saldo Pendiente", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(saldoPendiente),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: saldoPendiente > 0
                                  ? (isDark ? Colors.red[300] : Colors.red[700])
                                  : (isDark ? Colors.green[300] : Colors.green[700]),
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

          // Feedback táctil interactivo al pulsar cualquier columna
          if (_selectedBalanceSegment != null) ...[
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedBalanceSegment == 'abonos'
                    ? (isDark ? Colors.green.withValues(alpha: 0.12) : Colors.green.shade50)
                    : (_selectedBalanceSegment == 'saldo'
                        ? (isDark ? Colors.red.withValues(alpha: 0.12) : Colors.red.shade50)
                        : (isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedBalanceSegment == 'abonos'
                      ? (isDark ? Colors.green.withValues(alpha: 0.3) : Colors.green.shade200)
                      : (_selectedBalanceSegment == 'saldo'
                          ? (isDark ? Colors.red.withValues(alpha: 0.3) : Colors.red.shade200)
                          : (isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200)),
                ),
              ),
              child: Text(
                _selectedBalanceSegment == 'abonos'
                    ? "Total Abonos: Amortiza el ${tasaCobro.toStringAsFixed(1)}% de las compras."
                    : (_selectedBalanceSegment == 'saldo'
                        ? "Saldo Pendiente: Falta cobrar el ${(100 - tasaCobro).clamp(0.0, 100.0).toStringAsFixed(1)}%."
                        : "Total Compras: 100% del volumen comercial facturado."),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _selectedBalanceSegment == 'abonos'
                      ? (isDark ? Colors.green[300] : Colors.green[800])
                      : (_selectedBalanceSegment == 'saldo'
                          ? (isDark ? Colors.red[300] : Colors.red[800])
                          : (isDark ? Colors.blue[300] : Colors.blue[800])),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculos Globales (Estado Actual)
    final double deudaGlobal = widget.client.totalDebt;
    
    // Calcular deuda de préstamos vs deuda de compras
    double deudaPrestamos = 0.0;
    int prestamosActivos = 0;
    for (var sale in _allSales) {
      if (sale.origenVenta == 'prestamo_personal' && !sale.isArchived) {
        double deudaVenta = sale.trueTotal - sale.montoPagado;
        if (deudaVenta > 0) {
          deudaPrestamos += deudaVenta;
          prestamosActivos++;
        }
      }
    }
    double deudaCompras = deudaGlobal - deudaPrestamos;
    if (deudaCompras < 0) deudaCompras = 0;

    final double saldoFavor = widget.client.saldoAFavor;
    final int porEntregar = widget.client.pendingDeliveryCount;

    String ultimaCompra = "N/A";
    if (_allSales.isNotEmpty) {
      final salesOnly = _allSales.where((s) => s.origenVenta != 'prestamo_personal').toList();
      if (salesOnly.isNotEmpty) {
        DateTime? dt = DateTime.tryParse(salesOnly.first.date);
        if (dt != null) {
          int diff = DateTime.now().difference(dt).inDays;
          if (diff == 0) {
            ultimaCompra = "Hoy";
          } else if (diff == 1) {
            ultimaCompra = "Ayer";
          } else {
            ultimaCompra = "Hace $diff días";
          }
        }
      }
    }

    // Calculos Dinámicos (Según Filtro)
    final sales = _filteredSales;
    final double totalComprado = sales.fold(0.0, (sum, sale) => sum + sale.total);
    final double totalPagado = sales.fold(0.0, (sum, sale) => sum + sale.montoPagado);
    final int numCompras = sales.length;
    final double ticketPromedio = numCompras > 0 ? (totalComprado / numCompras) : 0;
    final double tasaCobro = totalComprado > 0 ? ((totalPagado / totalComprado) * 100).clamp(0.0, 100.0) : 100.0;
    final double saldoPendienteFiltro = (totalComprado - totalPagado).clamp(0.0, double.infinity);
    final String frecuenciaMedia = _calculatePurchaseFrequency(sales);

    final loans = _filteredLoans;
    final double totalPrestado = loans.fold(0.0, (sum, loan) => sum + loan.total);

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF14141C) : const Color(0xFFF5F7FA),
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
                      icon: Icon(Icons.file_download, color: widget.isDark ? Colors.blueAccent : Colors.blue[700]),
                      tooltip: "Exportar Reporte",
                      onSelected: (value) {
                        if (value == 'pdf') _exportReport(true);
                        if (value == 'csv') _exportReport(false);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Descargar PDF Profesional'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.table_chart, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Descargar Excel (CSV)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                    )
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
                    _buildFilterChip("Rango 📅", TimeFilter.custom),
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
                    
                    // SECCION 1: Rendimiento Comercial (Dinámico)
                    Text(
                      "Rendimiento Comercial (Filtro Activo)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tarjeta Visual de Comparativa Compras vs. Abonos
                    _buildCommercialBalanceCard(
                      totalComprado: totalComprado,
                      totalPagado: totalPagado,
                      tasaCobro: tasaCobro,
                      saldoPendiente: saldoPendienteFiltro,
                      isDark: widget.isDark,
                    ),

                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.20,
                      children: [
                        _buildStatCard("Ticket Promedio", ticketPromedio, Icons.analytics, widget.isDark ? Colors.teal[300]! : Colors.teal[800]!),
                        _buildStatCard("Frecuencia Media", 0, Icons.update_rounded, widget.isDark ? Colors.indigo[300]! : Colors.indigo[800]!, textValue: frecuenciaMedia),
                        _buildStatCard("N° de Compras", numCompras.toDouble(), Icons.receipt_long, widget.isDark ? Colors.purple[300]! : Colors.purple[700]!, isInt: true),
                        _buildStatCard("Última Compra", 0, Icons.event_available, widget.isDark ? Colors.blueGrey[300]! : Colors.blueGrey[700]!, textValue: ultimaCompra),
                      ],
                    ),

                    const SizedBox(height: 12),
                    ClientComplianceSparkline(
                      client: widget.client,
                      sales: sales,
                      isDark: widget.isDark,
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCION 2: Estado Actual (Global, no afectado por el filtro)
                    Text(
                      "Estado de Cuenta Actual (Global)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.20,
                      children: [
                        _buildStatCard("Deuda Total", deudaGlobal, Icons.account_balance_wallet, deudaGlobal > 0 ? (widget.isDark ? Colors.red[400]! : Colors.red) : (widget.isDark ? Colors.green[400]! : Colors.green)),
                        _buildStatCard("Deuda (Solo Compras)", deudaCompras, Icons.shopping_cart, deudaCompras > 0 ? (widget.isDark ? Colors.red[300]! : Colors.red[600]!) : (widget.isDark ? Colors.green[300]! : Colors.green[600]!)),
                        _buildStatCard("Saldo a Favor", saldoFavor, Icons.savings, widget.isDark ? Colors.amber[400]! : Colors.amber[800]!),
                        _buildStatCard("Por Entregar", porEntregar.toDouble(), Icons.local_shipping, widget.isDark ? Colors.orange[400]! : Colors.orange[800]!, isInt: true),
                      ],
                    ),

    const SizedBox(height: 32),
    const Divider(),
    const SizedBox(height: 16),

    // SECCION 3: Préstamos
    Text("Préstamos Personales", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.orange[300] : Colors.orange[800])),
    const SizedBox(height: 16),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 10,
      childAspectRatio: 1.20,
      children: [
        _buildStatCard("Deuda por Préstamos", deudaPrestamos, Icons.account_balance, deudaPrestamos > 0 ? (widget.isDark ? Colors.orange[400]! : Colors.orange[700]!) : (widget.isDark ? Colors.green[400]! : Colors.green[700]!)),
        _buildStatCard("Préstamos Activos", prestamosActivos.toDouble(), Icons.list_alt, widget.isDark ? Colors.amber[300]! : Colors.amber[800]!, isInt: true),
        _buildStatCard("Total Histórico Prestado", totalPrestado, Icons.monetization_on, widget.isDark ? Colors.deepOrange[300]! : Colors.deepOrange[700]!),
      ],
    ),

    // SECCION 4: Análisis de Cancelaciones (Solo si hay anuladas)
                    if (_cancellationStats != null && (_cancellationStats!['anuladas'] ?? 0) > 0) ...[
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text("Análisis de Cancelaciones", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[300] : Colors.red[800])),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.20,
                        children: [
                          _buildStatCard("Ventas Anuladas", (_cancellationStats!['anuladas'] as num).toDouble(), Icons.cancel_presentation, widget.isDark ? Colors.red[400]! : Colors.red[700]!, isInt: true),
                          _buildStatCard("Monto Perdido", (_cancellationStats!['montoPerdido'] as num).toDouble(), Icons.money_off, widget.isDark ? Colors.deepOrange[400]! : Colors.deepOrange[700]!),
                          _buildStatCard("Tasa de Cancelación", (_cancellationStats!['cancellationRate'] as num).toDouble(), Icons.pie_chart, widget.isDark ? Colors.pink[400]! : Colors.pink[700]!, textValue: "${(_cancellationStats!['cancellationRate'] as num).toStringAsFixed(1)}%"),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.withValues(alpha: widget.isDark ? 0.2 : 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Motivos Frecuentes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[300] : Colors.grey[700])),
                            const SizedBox(height: 12),
                            ...(_cancellationStats!['motivos'] as Map<String, int>).entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key, style: TextStyle(fontSize: 14, color: widget.isDark ? Colors.white70 : Colors.black87)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                      child: Text("${e.value} veces", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.red[300] : Colors.red)),
                                    )
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
