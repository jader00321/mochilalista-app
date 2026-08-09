import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/analytics_provider.dart';
import '../services/analytics_export_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_snackbar.dart';
import '../widgets/charts/monthly_sales_chart.dart';
import '../widgets/charts/origin_pie_chart.dart';
import '../widgets/charts/sales_by_day_chart.dart';
import '../widgets/charts/top_products_chart.dart';
import '../widgets/insights_carousel.dart';
import '../widgets/dashboard/financial_summary_card.dart';
import '../widgets/dashboard/kpi_summary_row.dart';
import '../widgets/dashboard/top_clients_card.dart';
import '../widgets/dashboard/extra_metrics_card.dart';
import '../widgets/dashboard/restock_alerts_card.dart';
import '../widgets/dashboard/dead_stock_card.dart';
import '../widgets/dashboard/top_categories_card.dart';

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
        title: const Text("Inteligencia de Negocio"),
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
              _buildLoadingStep("Procesando inventario...", prov.currentStep.index > AnalyticsStep.predictions.index, prov.currentStep == AnalyticsStep.predictions, isDark),
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
          InsightsCarousel(data: data, isDark: isDark),
          const SizedBox(height: 24),
          MonthlySalesChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          OriginPieChart(data: data, isDark: isDark),
          const SizedBox(height: 24),
          SalesByDayChart(data: data, isDark: isDark, formatCurrency: _formatCurrency),
          const SizedBox(height: 24),
          TopProductsChart(data: data, isDark: isDark),
          const SizedBox(height: 24),
          TopCategoriesCard(data: data, isDark: isDark),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: TopClientsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency)),
              const SizedBox(width: 16),
              Expanded(child: ExtraMetricsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency)),
            ],
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

  Widget _buildLoadingStep(String text, bool isCompleted, bool isCurrent, bool isDark) {
    Color iconColor = isCompleted ? Colors.green : (isCurrent ? Colors.blue : Colors.grey);
    IconData icon = isCompleted ? Icons.check_circle : (isCurrent ? Icons.circle_outlined : Icons.circle_outlined);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Text(text, style: TextStyle(fontSize: 16, color: isCompleted || isCurrent ? (isDark ? Colors.white : Colors.black) : Colors.grey, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

}
