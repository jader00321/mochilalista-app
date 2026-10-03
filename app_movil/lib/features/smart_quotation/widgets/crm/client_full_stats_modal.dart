import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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

  @override
  void initState() {
    super.initState();
    _allSales = widget.client.lastSales;
    _loadAllSales();
    _loadCancellationStats();
  }

  Future<void> _loadAllSales() async {
    final repo = ClientRepository();
    final rows = await repo.getClientSales(widget.client.id, limit: 10000); 
    if (mounted) {
      setState(() {
        _allSales = rows.map((e) => SaleSummary.fromJson(e)).toList();
        _isLoadingSales = false;
      });
    }
  }

  Future<void> _loadCancellationStats() async {
    final repo = ClientRepository();
    final stats = await repo.getClientCancellationStats(widget.client.id);
    if (mounted) {
      setState(() {
        _cancellationStats = stats;
      });
    }
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
          formatted = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ').format(value);
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: widget.isDark ? 0.2 : 0.3)),
        boxShadow: [if (!widget.isDark) BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[700], 
                    fontWeight: FontWeight.bold
                  ), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          textValue != null
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(textValue, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
                )
              : _buildAnimatedNumber(value, prefix: isInt ? '' : 'S/ ', color: color, isInt: isInt),
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
                    const Text("Analítica del Cliente", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    Text("Rendimiento Comercial (Filtro Activo)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[300] : Colors.blue[800])),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        _buildStatCard("Total Comprado", totalComprado, Icons.shopping_bag, widget.isDark ? Colors.blue[400]! : Colors.blue[700]!),
                        _buildStatCard("Total Pagado", totalPagado, Icons.check_circle, widget.isDark ? Colors.green[400]! : Colors.green[700]!),
                        _buildStatCard("Ticket Promedio", ticketPromedio, Icons.analytics, widget.isDark ? Colors.teal[300]! : Colors.teal[800]!),
                        _buildStatCard("N° de Compras", numCompras.toDouble(), Icons.receipt_long, widget.isDark ? Colors.purple[300]! : Colors.purple[700]!, isInt: true),
                      ],
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCION 2: Estado Actual (Global, no afectado por el filtro)
    Text("Estado de Cuenta Actual (Global)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white70 : Colors.black54)),
    const SizedBox(height: 16),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard("Deuda Total", deudaGlobal, Icons.account_balance_wallet, deudaGlobal > 0 ? (widget.isDark ? Colors.red[400]! : Colors.red) : (widget.isDark ? Colors.green[400]! : Colors.green)),
        _buildStatCard("Deuda (Solo Compras)", deudaCompras, Icons.shopping_cart, deudaCompras > 0 ? (widget.isDark ? Colors.red[300]! : Colors.red[600]!) : (widget.isDark ? Colors.green[300]! : Colors.green[600]!)),
        _buildStatCard("Saldo a Favor", saldoFavor, Icons.savings, widget.isDark ? Colors.amber[400]! : Colors.amber[800]!),
        _buildStatCard("Por Entregar", porEntregar.toDouble(), Icons.local_shipping, widget.isDark ? Colors.orange[400]! : Colors.orange[800]!, isInt: true),
        _buildStatCard("Última Compra", 0, Icons.event_available, widget.isDark ? Colors.indigo[300]! : Colors.indigo[800]!, textValue: ultimaCompra),
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
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
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
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.4,
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
