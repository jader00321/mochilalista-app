import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';

part 'predictive_analytics/predictive_summary_and_diagnosis_cards.dart';
part 'predictive_analytics/predictive_diagnosis_and_confidence_cards.dart';
part 'predictive_analytics/predictive_simulator_section.dart';
part 'predictive_analytics/predictive_simulator_result_panel.dart';
part 'predictive_analytics/predictive_patrimony_chart_section.dart';
part 'predictive_analytics/predictive_patrimony_detail_panel.dart';
part 'predictive_analytics/predictive_explain_modals.dart';

class PredictiveAnalyticsScreen extends StatefulWidget {
  final PredictiveData? initialData;

  const PredictiveAnalyticsScreen({super.key, this.initialData});

  @override
  State<PredictiveAnalyticsScreen> createState() =>
      _PredictiveAnalyticsScreenState();
}

abstract class _PredictiveAnalyticsScreenStateBase
    extends State<PredictiveAnalyticsScreen> {
  final PredictiveService _service = PredictiveService();
  PredictiveData? _data;
  bool _isLoading = true;
  String? _error;

  // Simulador state
  double _salesSimulationPct = 0.0; // -50% to +100%
  double _costsSimulationPct = 0.0; // -50% to +50%
  double _discountPct = 0.0; // 0% to 20% (descuento en precio en liquidación)

  // Gráfico patrimonial state
  int _selectedChartTab =
      0; // 0: Normalizada %, 1: Valor Inventario, 2: Beneficio y Ventas
  Map<String, dynamic>? _selectedPatrimonyPoint;

  Widget _buildPredictionCard(bool isDark);
  Widget _buildSimulator(bool isDark);
  Widget _buildExplainabilityCard(bool isDark);
  Widget _buildPatrimonyChart(bool isDark);
  Widget _buildWarningBanner(bool isDark);
  Widget _buildSimulatorResultPanel({
    required bool isDark,
    required double baseProfit,
    required double simSales,
    required double simCosts,
    required double simProfit,
    required double diffProfit,
    required double simMargin,
    required double breakEven,
    required bool isBaseScenario,
    required bool isFavorable,
    required String scenarioTitle,
    required Color scenarioColor,
    required IconData scenarioIcon,
  });
  Widget _buildQuickSimulationChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool isReset = false,
  });
  Widget _buildChartTabButton({
    required String label,
    required IconData icon,
    required int index,
    required bool isDark,
  });
  Widget _buildPatrimonyDetailPanel(bool isDark);
  void _showProjectionExplainModal();
  void _showSimulatorExplainModal();
  void _showDiagnosisExplainModal();
  void _showPatrimonyExplainModal();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _data = widget.initialData;
      if (_data!.historicalPoints.isNotEmpty) {
        _selectedPatrimonyPoint = _data!.historicalPoints.last;
      }
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.activeBusinessId == null) {
        throw Exception("No hay negocio seleccionado");
      }

      final data = await _service.generatePrediction(auth.activeBusinessId!);

      setState(() {
        _data = data;
        if (_data != null && _data!.historicalPoints.isNotEmpty) {
          _selectedPatrimonyPoint = _data!.historicalPoints.last;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Proyecciones y Crecimiento",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          InfoTooltipButton(
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.all(6),
            title: "Proyecciones y Crecimiento",
            description:
                "Simulador financiero y curva de tendencia basados en el histórico real de snapshots diarios de tu negocio.",
            tips: [
              InfoTip(
                icon: Icons.trending_up_rounded,
                text:
                    "Curva de Tendencia: Estima ingresos y utilidades futuras a partir de tu evolución reciente de ventas.",
              ),
              InfoTip(
                icon: Icons.tune_rounded,
                text:
                    "Simulador de Escenarios: Ajusta los controles de crecimiento en ventas o ahorro de costos para evaluar impacto financiero.",
              ),
              InfoTip(
                icon: Icons.account_balance_outlined,
                text:
                    "Patrimonio Neto Real: Combina valuación exacta de inventario físico, cuentas por cobrar y flujo acumulado.",
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text("Ocurrió un error: $_error", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null || _data!.historicalPoints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.query_stats, size: 80, color: Colors.blue[300]),
              const SizedBox(height: 24),
              const Text(
                "Aún no hay suficientes datos históricos",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "El motor predictivo necesita recopilar datos diarios (snapshots) para generar proyecciones precisas. Vuelve en un par de días para ver tu crecimiento.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPredictionCard(isDark),
          const SizedBox(height: 16),
          _buildSimulator(isDark),
          const SizedBox(height: 16),
          _buildExplainabilityCard(isDark),
          const SizedBox(height: 24),
          _buildPatrimonyChart(isDark),
          const SizedBox(height: 24),
          _buildWarningBanner(isDark),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. HELPER PÍLDORA "¿CÓMO FUNCIONA? ⓘ"
  // =========================================================================
  Widget _buildExplainPill({
    required bool isDark,
    required VoidCallback onTap,
    bool isLightOnGradient = false,
    String label = "¿Cómo funciona?",
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: isLightOnGradient
                ? Colors.white.withValues(alpha: 0.18)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.blueAccent.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLightOnGradient
                  ? Colors.white30
                  : (isDark
                        ? Colors.white24
                        : Colors.blueAccent.withValues(alpha: 0.3)),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 12,
                  color: isLightOnGradient ? Colors.white : Colors.blueAccent,
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLightOnGradient ? Colors.white : Colors.blueAccent,
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

class _PredictiveAnalyticsScreenState
    extends _PredictiveAnalyticsScreenStateBase
    with
        _PredictiveSummaryAndDiagnosisCardsMixin,
        _PredictiveDiagnosisAndConfidenceCardsMixin,
        _PredictiveSimulatorSectionMixin,
        _PredictiveSimulatorResultPanelMixin,
        _PredictivePatrimonyChartSectionMixin,
        _PredictivePatrimonyDetailPanelMixin,
        _PredictiveExplainModalsMixin {}
