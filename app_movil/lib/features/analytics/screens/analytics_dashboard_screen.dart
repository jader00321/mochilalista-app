import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/services/analytics_export_service.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/features/analytics/widgets/charts/monthly_sales_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/payment_method_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/origin_pie_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/sales_by_day_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/top_products_chart.dart';
import 'package:app_movil/features/analytics/widgets/insights_carousel.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/financial_summary_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/kpi_summary_row.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/top_clients_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/extra_metrics_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/restock_alerts_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/dead_stock_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/top_categories_card.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  bool _obscureAmounts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AnalyticsProvider>(context, listen: false).reset();
    });
  }

  void _exportPdf(BuildContext context, AnalyticsProvider prov, AuthProvider auth) async {
    if (prov.data == null) return;
    try {
      final file = await AnalyticsExportService.exportToPdf(prov.data!, auth.businessName);
      if (!context.mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Reporte Estadístico - ${auth.businessName}');
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: 'Error al exportar PDF: $e', isError: true);
    }
  }

  void _exportCsv(BuildContext context, AnalyticsProvider prov, AuthProvider auth) async {
    if (prov.data == null) return;
    try {
      final file = await AnalyticsExportService.exportToCsv(prov.data!, auth.businessName);
      if (!context.mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Datos CSV - ${auth.businessName}');
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: 'Error al exportar CSV: $e', isError: true);
    }
  }

  String _formatCurrency(double amount) {
    if (_obscureAmounts) return 'S/ ***.**';
    return currencyFmt.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AnalyticsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text("Inteligencia de Negocio"),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: prov.currentStep == AnalyticsStep.done ? [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Regenerar reporte",
            onPressed: () => prov.runStaggeredAnalysis(),
          ),
          IconButton(
            icon: Icon(_obscureAmounts ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _obscureAmounts = !_obscureAmounts;
              });
            },
            tooltip: _obscureAmounts ? "Mostrar Saldos" : "Ocultar Saldos",
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'pdf') _exportPdf(context, prov, auth);
              if (value == 'csv') _exportCsv(context, prov, auth);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Text("Exportar a PDF")),
              const PopupMenuItem(value: 'csv', child: Text("Exportar a Excel (CSV)")),
            ],
          )
        ] : null,
      ),
      body: _buildBody(prov, isDark),
      floatingActionButton: prov.currentStep == AnalyticsStep.done ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SmartRestockScreen()));
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add_alert, color: Colors.white),
        label: const Text('Alertas de Reabastecimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildBody(AnalyticsProvider prov, bool isDark) {
    if (prov.currentStep == AnalyticsStep.idle) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats, size: 80, color: Colors.blue[300]),
              const SizedBox(height: 24),
              const Text("Descubre el estado real de tu negocio", 
                         textAlign: TextAlign.center, 
                         style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text("Analizaremos todas tus ventas, inventario y productos para darte un reporte detallado.",
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () => prov.runStaggeredAnalysis(),
                icon: const Icon(Icons.play_arrow),
                label: const Text("Generar Reporte", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    if (prov.currentStep != AnalyticsStep.done && prov.currentStep != AnalyticsStep.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120, height: 120,
                    child: CircularProgressIndicator(value: prov.progress, strokeWidth: 8, backgroundColor: isDark ? Colors.white10 : Colors.grey[200]),
                  ),
                  Text("${(prov.progress * 100).toInt()}%", style: TextStyle(fontSize: 24, color: Colors.blue[400], fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 40),
              _buildLoadingStep("Analizando ventas...", prov.currentStep.index > AnalyticsStep.sales.index, prov.currentStep == AnalyticsStep.sales, isDark),
              _buildLoadingStep("Evaluando clientes...", prov.currentStep.index > AnalyticsStep.clients.index, prov.currentStep == AnalyticsStep.clients, isDark),
              _buildLoadingStep("Procesando inventario...", prov.currentStep.index > AnalyticsStep.insights.index, prov.currentStep == AnalyticsStep.insights, isDark),
            ],
          ),
        ),
      );
    }

    if (prov.currentStep == AnalyticsStep.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(prov.statusMessage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => prov.runStaggeredAnalysis(),
              icon: const Icon(Icons.refresh),
              label: const Text("Intentar Nuevamente"),
            )
          ],
        ),
      );
    }

    final data = prov.data!;
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FinancialSummaryCard(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 16),
          KpiSummaryRow(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          _buildPredictiveButton(context, isDark),
          const SizedBox(height: 24),
          _buildPeriodSelector(prov, isDark),
          const SizedBox(height: 24),
          InsightsCarousel(data: data, isDark: isDark),
          const SizedBox(height: 24),
          MonthlySalesChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          OriginPieChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          PaymentMethodChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          SalesByDayChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          TopProductsChart(data: data, isDark: isDark),
          const SizedBox(height: 24),
          TopCategoriesCard(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TopClientsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency),
                    const SizedBox(height: 24),
                    ExtraMetricsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: TopClientsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency)),
                  const SizedBox(width: 16),
                  Expanded(child: ExtraMetricsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          RestockAlertsCard(data: data, isDark: isDark),
          const SizedBox(height: 24),
          DeadStockCard(data: data, isDark: isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLoadingStep(String text, bool isDone, bool isActive, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : (isActive ? Icons.hourglass_bottom : Icons.radio_button_unchecked),
            color: isDone ? Colors.greenAccent : (isActive ? Colors.blue[400] : (isDark ? Colors.white30 : Colors.black26)),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isDone ? (isDark ? Colors.white : Colors.black87) : (isActive ? Colors.blue[400] : (isDark ? Colors.white54 : Colors.black54)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(AnalyticsProvider prov, bool isDark) {
    final periods = [
      {'val': AnalyticsPeriod.today, 'label': 'Hoy'},
      {'val': AnalyticsPeriod.week, 'label': '7 Días'},
      {'val': AnalyticsPeriod.month, 'label': '30 Días'},
      {'val': AnalyticsPeriod.sixMonths, 'label': '6 Meses'},
      {'val': AnalyticsPeriod.year, 'label': '1 Año'},
      {'val': AnalyticsPeriod.allTime, 'label': 'Todo'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final p = periods[index];
          final val = p['val'] as AnalyticsPeriod;
          final isSelected = prov.selectedPeriod == val;

          return ChoiceChip(
            label: Text(p['label'] as String, style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) prov.changePeriod(val);
            },
            selectedColor: Colors.blueAccent,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.blueAccent : (isDark ? Colors.white10 : Colors.grey[300]!),
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildPredictiveButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictiveAnalyticsScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Motor Predictivo de Crecimiento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Descubre proyecciones y tendencias.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

}
