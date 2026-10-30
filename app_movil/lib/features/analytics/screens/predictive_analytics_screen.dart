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

class PredictiveAnalyticsScreen extends StatefulWidget {
  const PredictiveAnalyticsScreen({super.key});

  @override
  State<PredictiveAnalyticsScreen> createState() => _PredictiveAnalyticsScreenState();
}

class _PredictiveAnalyticsScreenState extends State<PredictiveAnalyticsScreen> {
  final PredictiveService _service = PredictiveService();
  PredictiveData? _data;
  bool _isLoading = true;
  String? _error;

  // Simulador state
  double _salesSimulationPct = 0.0; // -50% to +100%
  double _costsSimulationPct = 0.0; // -50% to +50%
  double _discountPct = 0.0; // 0% to 20% (descuento en precio en liquidación)

  // Gráfico patrimonial state
  int _selectedChartTab = 0; // 0: Normalizada %, 1: Valor Inventario, 2: Beneficio y Ventas
  Map<String, dynamic>? _selectedPatrimonyPoint;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.activeBusinessId == null) throw Exception("No hay negocio seleccionado");
      
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Proyecciones y Crecimiento", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          InfoTooltipButton(
            title: "Proyecciones y Crecimiento",
            description:
                "Simulador financiero y algoritmos de proyección que anticipan la evolución de tu patrimonio, ventas e inventario a futuro.",
            tips: [
              InfoTip(
                icon: Icons.trending_up_rounded,
                text:
                    "Curva de Tendencia: Proyección matemática basada en el histórico de snapshots diarios de tu negocio.",
              ),
              InfoTip(
                icon: Icons.tune_rounded,
                text:
                    "Simulador de Escenarios: Mueve los sliders de incremento de ventas o reducción de costos para ver el impacto financiero proyectado.",
              ),
              InfoTip(
                icon: Icons.account_balance_outlined,
                text:
                    "Patrimonio Total: Valuación combinada del inventario físico en stock y el flujo de caja.",
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
              ElevatedButton(onPressed: _loadData, child: const Text("Reintentar"))
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
  // 1. TARJETA PRINCIPAL: PROYECCIÓN A 30 DÍAS CON 3 ESCENARIOS Y ACCESO RÁPIDO
  // =========================================================================
  Widget _buildPredictionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)] 
              : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.4), 
            blurRadius: 20, 
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.auto_graph, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        "Proyección a 30 Días",
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildExplainPill(
                isDark: isDark,
                onTap: _showProjectionExplainModal,
                isLightOnGradient: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text("Se proyecta que cerrarás el próximo mes con ventas por:", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _data!.predictedNext30DaysSales),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  AppCurrency.format(value),
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Desglose de 3 Escenarios de Cierre de Mes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildScenarioMiniTile(
                    label: "Conservador",
                    amount: _data!.conservativeEstimate,
                    color: Colors.amberAccent,
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _buildScenarioMiniTile(
                    label: "Esperado",
                    amount: _data!.expectedEstimate,
                    color: Colors.greenAccent,
                    isFeatured: true,
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white24),
                Expanded(
                  child: _buildScenarioMiniTile(
                    label: "Optimista",
                    amount: _data!.optimisticEstimate,
                    color: Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Consejo accionable con navegación directa al Motor de Abastecimiento (Sin doble icono)
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartRestockScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb_outline, color: Colors.amberAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _data!.actionText,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioMiniTile({
    required String label,
    required double amount,
    required Color color,
    bool isFeatured = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isFeatured ? FontWeight.bold : FontWeight.normal,
            color: isFeatured ? Colors.white : Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppCurrency.format(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 2. SIMULADOR DE ESCENARIOS INTELIGENTE
  // =========================================================================
  Widget _buildSimulator(bool isDark) {
    double baseSales = _data!.predictedNext30DaysSales;
    double assumedMargin = _data!.historicalProfitMargin; 
    double baseCosts = baseSales * (1 - assumedMargin);
    double baseProfit = baseSales - baseCosts;
    
    // Conexión financiera: El costo escala con el volumen vendido (1 + salesSimulationPct)
    double volumeFactor = 1.0 + (_salesSimulationPct / 100.0);
    double costFactor = 1.0 + (_costsSimulationPct / 100.0);
    double priceFactor = 1.0 - (_discountPct / 100.0);

    double simSales = baseSales * volumeFactor * priceFactor;
    double simCosts = baseCosts * volumeFactor * costFactor;
    double simProfit = simSales - simCosts;
    double diffProfit = simProfit - baseProfit;
    double simMargin = simSales > 0 ? (simProfit / simSales) * 100.0 : 0.0;
    // Punto de equilibrio operativo estimado (gastos fijos aprox 15% de ventas base)
    double breakEven = simMargin > 0 ? ((baseSales * 0.15) / (simMargin / 100.0)) : 0.0;

    // Distinción estricta de estados lógicos
    final bool isBaseScenario = diffProfit.abs() < 0.01;
    final bool isFavorable = diffProfit > 0.01;

    String scenarioTitle;
    Color scenarioColor;
    IconData scenarioIcon;

    if (isBaseScenario) {
      scenarioTitle = "Escenario base proyectado. Ajusta los controles para ver el impacto.";
      scenarioColor = isDark ? Colors.grey[400]! : Colors.blueGrey;
      scenarioIcon = Icons.info_outline;
    } else if (isFavorable) {
      scenarioTitle = "¡Excelente! Este escenario aumenta tu ganancia esperada.";
      scenarioColor = Colors.green;
      scenarioIcon = Icons.arrow_upward_rounded;
    } else {
      scenarioTitle = "Cuidado, este escenario reduce tu rentabilidad proyectada.";
      scenarioColor = Colors.redAccent;
      scenarioIcon = Icons.arrow_downward_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.tune, color: Colors.blueAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        "Simulador de Escenarios",
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildExplainPill(
                isDark: isDark,
                onTap: _showSimulatorExplainModal,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Ajusta los controles o usa accesos rápidos para ver el impacto en tus ganancias proyectadas.",
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 16),

          // Chips de simulación rápida en 1 toque (Usa Wrap para CERO unbounded height)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickSimulationChip(
                label: "📈 Campaña (+30% ventas)",
                isSelected: _salesSimulationPct == 30.0 && _costsSimulationPct == 0.0 && _discountPct == 0.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 30.0 && _costsSimulationPct == 0.0 && _discountPct == 0.0) {
                      _salesSimulationPct = 0.0;
                      _costsSimulationPct = 0.0;
                      _discountPct = 0.0;
                    } else {
                      _salesSimulationPct = 30.0;
                      _costsSimulationPct = 0.0;
                      _discountPct = 0.0;
                    }
                  });
                },
                isDark: isDark,
              ),
              _buildQuickSimulationChip(
                label: "🚛 Subida Proveedor (+10% costos)",
                isSelected: _salesSimulationPct == 0.0 && _costsSimulationPct == 10.0 && _discountPct == 0.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 0.0 && _costsSimulationPct == 10.0 && _discountPct == 0.0) {
                      _salesSimulationPct = 0.0;
                      _costsSimulationPct = 0.0;
                      _discountPct = 0.0;
                    } else {
                      _salesSimulationPct = 0.0;
                      _costsSimulationPct = 10.0;
                      _discountPct = 0.0;
                    }
                  });
                },
                isDark: isDark,
              ),
              _buildQuickSimulationChip(
                label: "🏷️ Liquidación (+20% ventas, -5% dto.)",
                isSelected: _salesSimulationPct == 20.0 && _costsSimulationPct == 0.0 && _discountPct == 5.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 20.0 && _costsSimulationPct == 0.0 && _discountPct == 5.0) {
                      _salesSimulationPct = 0.0;
                      _costsSimulationPct = 0.0;
                      _discountPct = 0.0;
                    } else {
                      _salesSimulationPct = 20.0;
                      _costsSimulationPct = 0.0;
                      _discountPct = 5.0;
                    }
                  });
                },
                isDark: isDark,
              ),
              _buildQuickSimulationChip(
                label: "🔄 Restaurar 0%",
                isSelected: _salesSimulationPct == 0.0 && _costsSimulationPct == 0.0 && _discountPct == 0.0,
                onTap: () {
                  setState(() {
                    _salesSimulationPct = 0.0;
                    _costsSimulationPct = 0.0;
                    _discountPct = 0.0;
                  });
                },
                isDark: isDark,
                isReset: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Slider 1: Ventas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Variación en Volumen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Proyecta si logras vender más o menos mercadería", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
              Text(
                "${_salesSimulationPct > 0 ? '+' : ''}${_salesSimulationPct.toInt()}%", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 15),
              ),
            ],
          ),
          Slider(
            value: _salesSimulationPct,
            min: -50,
            max: 100,
            divisions: 30,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
              setState(() {
                _salesSimulationPct = val;
                if (val != 20.0) _discountPct = 0.0;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("-50%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text("0%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text("+100%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(height: 14),
          
          // Slider 2: Costos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Variación en Costos de Proveedor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Qué pasa si suben o bajan precios de compra", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
              Text(
                "${_costsSimulationPct > 0 ? '+' : ''}${_costsSimulationPct.toInt()}%", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 15),
              ),
            ],
          ),
          Slider(
            value: _costsSimulationPct,
            min: -50,
            max: 50,
            divisions: 20,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              setState(() {
                _costsSimulationPct = val;
                if (val != 0.0) _discountPct = 0.0;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("-50%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text("0%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                Text("+50%", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isBaseScenario 
                    ? (isDark ? Colors.white12 : Colors.grey[300]!)
                    : (isFavorable ? Colors.green.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4)),
              ),
            ),
            child: Column(
              children: [
                const Text("Beneficio Neto Simulado", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: baseProfit, end: simProfit),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return Text(
                        AppCurrency.format(value),
                        style: TextStyle(
                          fontSize: 30, 
                          fontWeight: FontWeight.bold, 
                          color: isBaseScenario 
                              ? (isDark ? Colors.white : Colors.black87) 
                              : (isFavorable ? Colors.green : Colors.redAccent),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      scenarioIcon,
                      size: 15,
                      color: isBaseScenario ? Colors.grey : (isFavorable ? Colors.green : Colors.redAccent),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBaseScenario 
                          ? "${AppCurrency.format(0.0)} vs proy. base"
                          : "${diffProfit >= 0 ? '+' : '-'}${AppCurrency.format(diffProfit.abs())} vs proy. base",
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: isBaseScenario ? Colors.grey : (isFavorable ? Colors.green : Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  scenarioTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500, 
                    color: scenarioColor,
                  ),
                ),
                if (_discountPct > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      "🏷️ Descuento Comercial: -${_discountPct.toInt()}% en precio de venta",
                      style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Desglose de Ventas Simuladas y Costos Simulados
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Ventas Simuladas", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            AppCurrency.format(simSales),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.grey.withValues(alpha: 0.3)),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Costos Simulados", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            AppCurrency.format(simCosts),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Métricas financieras adicionales: Margen Neto Resultante y Punto de Equilibrio
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text("Margen Resultante", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              "${simMargin.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 12.5, 
                                color: simMargin >= 25.0 ? Colors.green : (simMargin >= 15.0 ? Colors.amber : Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.2)),
                      Expanded(
                        child: Column(
                          children: [
                            const Text("Pto. Equilibrio", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              AppCurrency.format(breakEven),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.indigoAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickSimulationChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool isReset = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isReset ? Colors.grey[700] : Colors.blueAccent)
                : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.grey[300]!),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. DIAGNÓSTICO DEL MOTOR (TARJETA VISUAL ANIMADA, SIN DOBLE ROBOT)
  // =========================================================================
  Widget _buildExplainabilityCard(bool isDark) {
    bool isInitialPhase = _data!.isInitialPhase;
    double velocity = _data!.salesVelocity;
    bool isPositive = velocity >= 0;
    double progressValue = isInitialPhase 
        ? (_data!.totalSnapshots / 30.0).clamp(0.05, 1.0)
        : (velocity.abs() / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.speed_rounded, color: Colors.indigoAccent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Flexible(
                      child: Text(
                        "Diagnóstico del Motor", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildExplainPill(
                isDark: isDark,
                onTap: _showDiagnosisExplainModal,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Medidor visual de aceleración quincenal
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isInitialPhase ? "Estado de Calibración del Motor" : "Ritmo Quincenal de Ventas",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                    ),
                    Text(
                      isInitialPhase ? "🌱 Etapa Inicial" : "${isPositive ? '+' : ''}${velocity.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isInitialPhase ? Colors.teal : (isPositive ? Colors.green : Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isInitialPhase ? Colors.teal : (isPositive ? Colors.green : Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Píldoras comparativas: Quincena Anterior vs Quincena Actual
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Quincena Anterior", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              AppCurrency.format(_data!.previous15Sales),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Quincena Actual", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              AppCurrency.format(_data!.current15Sales),
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 12, 
                                color: isInitialPhase ? Colors.teal : (isPositive ? Colors.green : Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Texto estructurado y recomendaciones
          Text(
            _data!.explanationText,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.45),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. GRÁFICO PATRIMONIAL CON SELECTOR DE 3 VISTAS (SIN APLASTAR CURVAS)
  // =========================================================================
  Widget _buildPatrimonyChart(bool isDark) {
    if (_data!.historicalPoints.length < 2) return const SizedBox.shrink();

    final points = _data!.historicalPoints;
    double maxInv = 0.0;
    double maxProfit = 0.0;
    double maxSales = 0.0;

    for (var p in points) {
      double inv = (p['inventoryValue'] as num?)?.toDouble() ?? 0.0;
      double prof = (p['netProfit'] as num?)?.toDouble() ?? 0.0;
      double sale = (p['dailySales'] as num?)?.toDouble() ?? 0.0;
      if (inv > maxInv) maxInv = inv;
      if (prof > maxProfit) maxProfit = prof;
      if (sale > maxSales) maxSales = sale;
    }

    List<FlSpot> inventorySpots = [];
    List<FlSpot> profitSpots = [];
    List<FlSpot> salesSpots = [];

    for (int i = 0; i < points.length; i++) {
      double inv = (points[i]['inventoryValue'] as num?)?.toDouble() ?? 0.0;
      double prof = (points[i]['netProfit'] as num?)?.toDouble() ?? 0.0;
      double sale = (points[i]['dailySales'] as num?)?.toDouble() ?? 0.0;

      if (_selectedChartTab == 0) {
        // Normalizada: 0% a 100% de su máximo para comparar tendencia sin aplastar
        double normInv = maxInv > 0 ? (inv / maxInv) * 100.0 : 0.0;
        double normProf = maxProfit > 0 ? (prof / maxProfit) * 100.0 : 0.0;
        inventorySpots.add(FlSpot(i.toDouble(), normInv));
        profitSpots.add(FlSpot(i.toDouble(), normProf));
      } else if (_selectedChartTab == 1) {
        // Valor Inventario
        inventorySpots.add(FlSpot(i.toDouble(), inv));
      } else {
        // Beneficio y Ventas
        profitSpots.add(FlSpot(i.toDouble(), prof));
        salesSpots.add(FlSpot(i.toDouble(), sale));
      }
    }

    int pointsCount = points.length;
    double interval = pointsCount <= 7 ? 1.0 : (pointsCount <= 30 ? 5.0 : 15.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Evolución Patrimonial", 
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildExplainPill(
                isDark: isDark,
                onTap: _showPatrimonyExplainModal,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de 3 vistas por pestañas/chips
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildChartTabButton(
                    label: "📊 Normalizada",
                    index: 0,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildChartTabButton(
                    label: "📦 Inventario",
                    index: 1,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildChartTabButton(
                    label: "💰 Beneficio",
                    index: 2,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Leyenda dinámica según la vista activa
          Row(
            children: [
              if (_selectedChartTab == 0 || _selectedChartTab == 1) ...[
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(_selectedChartTab == 0 ? "Inventario (%)" : "Inventario (S/)", style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
              ],
              if (_selectedChartTab == 0 || _selectedChartTab == 2) ...[
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(_selectedChartTab == 0 ? "Beneficio (%)" : "Beneficio (S/)", style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 12),
              ],
              if (_selectedChartTab == 2) ...[
                Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text("Ventas (S/)", style: TextStyle(fontSize: 11)),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Gráfico dinámico con etiquetas en Eje Y y X acotado en ClipRRect
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LineChart(
                LineChartData(
                  minY: _selectedChartTab == 0 ? 0.0 : null,
                  maxY: _selectedChartTab == 0 ? 100.0 : null,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: isDark ? Colors.white10 : Colors.grey[200]!,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < points.length) {
                            String dateStr = points[index]['date'];
                            List<String> parts = dateStr.split('-');
                            if (parts.length == 3) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text("${parts[2]}/${parts[1]}", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          if (_selectedChartTab == 0) {
                            return Text("${value.toInt()}%", style: TextStyle(fontSize: 9, color: Colors.grey[500]));
                          } else {
                            if (value >= 1000) {
                              return Text("S/ ${(value / 1000).toStringAsFixed(1)}k", style: TextStyle(fontSize: 9, color: Colors.grey[500]));
                            }
                            return Text("S/ ${value.toInt()}", style: TextStyle(fontSize: 9, color: Colors.grey[500]));
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    if (_selectedChartTab == 0 || _selectedChartTab == 1)
                      LineChartBarData(
                        spots: inventorySpots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: Colors.blueAccent,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blueAccent.withValues(alpha: 0.18),
                        ),
                      ),
                    if (_selectedChartTab == 0 || _selectedChartTab == 2)
                      LineChartBarData(
                        spots: profitSpots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: Colors.purpleAccent,
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purpleAccent.withValues(alpha: 0.22),
                        ),
                      ),
                    if (_selectedChartTab == 2)
                      LineChartBarData(
                        spots: salesSpots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: Colors.green,
                        barWidth: 2.0,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipMargin: 16,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          int index = spot.x.toInt();
                          if (index < 0 || index >= points.length) return null;
                          var p = points[index];
                          String dateStr = p['date'];
                          List<String> parts = dateStr.split('-');
                          String dFmt = parts.length == 3 ? "${parts[2]}/${parts[1]}" : dateStr;
                          
                          double invVal = (p['inventoryValue'] as num?)?.toDouble() ?? 0.0;
                          double netProf = (p['netProfit'] as num?)?.toDouble() ?? 0.0;
                          
                          return LineTooltipItem(
                            "$dFmt\nInv: ${AppCurrency.format(invVal)}\nBen: ${AppCurrency.format(netProf)}",
                            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          );
                        }).toList();
                      },
                    ),
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                        return;
                      }
                      int index = response.lineBarSpots!.first.x.toInt();
                      if (index >= 0 && index < points.length) {
                        setState(() {
                          _selectedPatrimonyPoint = points[index];
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          
          // Panel inferior de detalle por fecha espacioso
          _buildPatrimonyDetailPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildChartTabButton({
    required String label,
    required int index,
    required bool isDark,
  }) {
    bool isSelected = _selectedChartTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedChartTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blueAccent : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatrimonyDetailPanel(bool isDark) {
    if (_selectedPatrimonyPoint == null) return const SizedBox.shrink();
    
    String dateStr = _selectedPatrimonyPoint!['date'];
    List<String> parts = dateStr.split('-');
    String formattedDate = parts.length == 3 ? "${parts[2]}/${parts[1]}/${parts[0]}" : dateStr;
    
    double invValue = (_selectedPatrimonyPoint!['inventoryValue'] as num?)?.toDouble() ?? 0.0;
    double cumulativeProfit = (_selectedPatrimonyPoint!['netProfit'] as num?)?.toDouble() ?? 0.0;
    double dailySales = (_selectedPatrimonyPoint!['dailySales'] as num?)?.toDouble() ?? 0.0;
    double dailyProfit = (_selectedPatrimonyPoint!['dailyProfit'] as num?)?.toDouble() ?? 
        math.max(0.0, math.min(dailySales, cumulativeProfit));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.purpleAccent.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              Text("Detalle del día", style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Beneficio del Día", style: TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppCurrency.format(dailyProfit),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purpleAccent),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Acum: ${AppCurrency.format(cumulativeProfit)}",
                        style: TextStyle(fontSize: 8.5, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Inventario", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppCurrency.format(invValue),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ventas del Día", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppCurrency.format(dailySales),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. ESTIMACIONES TEÓRICAS Y NIVEL DE CONFIANZA ESTADÍSTICA
  // =========================================================================
  Widget _buildWarningBanner(bool isDark) {
    final confidence = _data?.confidenceDisplayName ?? 'Inicial';
    final int days = _data?.totalSnapshots ?? 0;
    Color confColor = Colors.teal;
    if (confidence == 'Alta') {
      confColor = Colors.green;
    } else if (confidence == 'Media') {
      confColor = Colors.blueAccent;
    } else {
      confColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: confColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: confColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: confColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Estimaciones Teóricas & Confianza",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: confColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: confColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "Confianza $confidence",
                  style: TextStyle(color: confColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso visual del nivel de precisión
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (days / 30.0).clamp(0.05, 1.0),
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(confColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "$days de 30 días óptimos",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: confColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Estos cálculos se basan en tus $days días de snapshots históricos. "
            "${confidence == 'Alta' 
                ? 'Tu volumen de datos permite proyecciones sumamente confiables.' 
                : 'A medida que registres más ventas diarias en Caja Rápida, Cotizaciones y Catálogo, la precisión de las proyecciones aumentará automáticamente.'}",
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4),
          ),
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
    String label = "ⓘ ¿Cómo funciona?",
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLightOnGradient 
                ? Colors.white.withValues(alpha: 0.18) 
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.blueAccent.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLightOnGradient 
                  ? Colors.white30 
                  : (isDark ? Colors.white24 : Colors.blueAccent.withValues(alpha: 0.3)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isLightOnGradient ? Colors.white : Colors.blueAccent,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 7. MODALES EXPLICATIVOS PASO A PASO (REDiseño Mobile Awards)
  // =========================================================================
  void _showUnifiedExplainModal({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    InteractiveSheetWrapper.show(
      context: context,
      enableDrag: false,
      builder: (ctx) => InteractiveSheetWrapper(
        title: title,
        titleMaxLines: 2,
        showCloseButton: true,
        icon: icon,
        iconColor: iconColor,
        enableDragToDismiss: false,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        bottomAction: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: iconColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTimelineStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required bool isDark,
    Widget? extraContent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                if (extraContent != null) ...[
                  const SizedBox(height: 8),
                  extraContent,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectionExplainModal() {
    if (_data == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _showUnifiedExplainModal(
      context: context,
      title: "¿Cómo se calcula la Proyección a 30 Días?",
      icon: Icons.auto_graph,
      iconColor: Colors.blueAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModalMetricHeader(
            label: "Proyección Base a 30 Días",
            value: AppCurrency.format(_data!.predictedNext30DaysSales),
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          _buildTimelineStepCard(
            stepNumber: "1",
            title: "Recopilación de Historial Real",
            description: "El motor tomó los ${_data!.totalSnapshots} días de ventas registrados en tu negocio.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Ritmo Diario Promedio",
            description: "Tus ventas promedio actuales son de ${AppCurrency.format(_data!.dailyAverageSales)} por día.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "Suavizado y Amortiguación de Tendencia",
            description: "Se atenúan picos atípicos y se amortigua la pendiente para garantizar proyecciones financieramente coherentes.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "4",
            title: "Regresión Amortiguada y 3 Escenarios",
            description: "Tendencia detectada: ${_data!.trendSlopeM >= 0 ? '+' : ''}${AppCurrency.format(_data!.trendSlopeM)}/día. Se estiman 3 escenarios de cierre de mes:",
            isDark: isDark,
            extraContent: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🛡️ Conservador (80%):", style: TextStyle(fontSize: 11.5)),
                      Text(AppCurrency.format(_data!.conservativeEstimate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.amber)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🎯 Esperado (100%):", style: TextStyle(fontSize: 11.5)),
                      Text(AppCurrency.format(_data!.expectedEstimate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("🚀 Optimista (120%):", style: TextStyle(fontSize: 11.5)),
                      Text(AppCurrency.format(_data!.optimisticEstimate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.blueAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip: "💡 ¿Cómo usarlo? Utiliza la proyección para presupuestar tus compras a proveedores sin arriesgar tu liquidez ni sobreendeudarte.",
          ),
        ],
      ),
    );
  }

  void _showSimulatorExplainModal() {
    if (_data == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double baseSales = _data!.predictedNext30DaysSales;
    double baseMargin = _data!.historicalProfitMargin; 
    double baseCosts = baseSales * (1 - baseMargin);
    double volumeFactor = 1.0 + (_salesSimulationPct / 100.0);
    double costFactor = 1.0 + (_costsSimulationPct / 100.0);
    double priceFactor = 1.0 - (_discountPct / 100.0);

    double simSales = baseSales * volumeFactor * priceFactor;
    double simCosts = baseCosts * volumeFactor * costFactor;
    double simProfit = simSales - simCosts;
    double simMargin = simSales > 0 ? (simProfit / simSales) * 100.0 : 0.0;
    double breakEven = simMargin > 0 ? ((baseSales * 0.15) / (simMargin / 100.0)) : 0.0;

    _showUnifiedExplainModal(
      context: context,
      title: "¿Cómo funciona el Simulador de Escenarios?",
      icon: Icons.tune,
      iconColor: Colors.blueAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModalMetricHeader(
            label: "Beneficio Neto Simulado Actual",
            value: AppCurrency.format(simProfit),
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          _buildTimelineStepCard(
            stepNumber: "1",
            title: "Ventas Simuladas con Volumen y Descuento",
            description: "Ventas = Ventas Base × (1 + % Volumen) × (1 - % Descuento). Simula tanto más unidades como promociones.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Costos Conectados al Volumen y Proveedor",
            description: "Costos = Costos Base × (1 + % Volumen) × (1 + % Proveedor). Al vender más unidades, el costo de mercadería escala en armonía.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "Beneficio y Margen Resultante",
            description: "Beneficio = Ventas - Costos. En este escenario tu margen neto es de ${simMargin.toStringAsFixed(1)}%.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "4",
            title: "Punto de Equilibrio Operativo",
            description: "Ventas mínimas estimadas (${AppCurrency.format(breakEven)}) necesarias para cubrir los costos de operación del mes.",
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip: "💡 Consejo Práctico: Usa los chips de 1 toque para simular campañas comerciales antes de lanzar ofertas y verificar si el volumen compensará el descuento.",
          ),
        ],
      ),
    );
  }

  void _showDiagnosisExplainModal() {
    if (_data == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _showUnifiedExplainModal(
      context: context,
      title: "¿Cómo se calcula el Diagnóstico del Motor?",
      icon: Icons.speed_rounded,
      iconColor: Colors.indigoAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModalMetricHeader(
            label: "Diagnóstico de Quincena",
            value: _data!.isInitialPhase 
                ? "🌱 Etapa Inicial" 
                : "${_data!.salesVelocity >= 0 ? '+' : ''}${_data!.salesVelocity.toStringAsFixed(1)}%",
            color: _data!.isInitialPhase ? Colors.teal : (_data!.salesVelocity >= 0 ? Colors.green : Colors.redAccent),
          ),
          const SizedBox(height: 16),
          _buildTimelineStepCard(
            stepNumber: "1",
            title: "Comparación de Quincenas",
            description: "Quincena Actual (${AppCurrency.format(_data!.current15Sales)}) vs Quincena Anterior (${AppCurrency.format(_data!.previous15Sales)}).",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Evaluación de Crecimiento y Madurez",
            description: _data!.isInitialPhase 
                ? "Con ${_data!.totalSnapshots} días registrados (< 14 días), el motor evalúa el arranque sin dividir entre cero." 
                : "Fórmula: [(Quincena Actual - Quincena Previa) / Quincena Previa] × 100.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "Recomendación Comercial",
            description: _data!.explanationText,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip: "💡 Revisa este indicador cada semana para anticiparte a quiebres de stock o temporadas lentas antes de que termine el mes.",
          ),
        ],
      ),
    );
  }

  void _showPatrimonyExplainModal() {
    if (_data == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _showUnifiedExplainModal(
      context: context,
      title: "¿Qué muestra la Evolución Patrimonial?",
      icon: Icons.account_balance_rounded,
      iconColor: Colors.purpleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModalMetricHeader(
            label: "Valor Actual del Inventario",
            value: AppCurrency.format(_data!.currentInventoryValue),
            color: Colors.blueAccent,
          ),
          const SizedBox(height: 16),
          _buildTimelineStepCard(
            stepNumber: "1",
            title: "Inventario Valuado al Costo",
            description: "Es la suma del stock físico multiplicado por su costo unitario de compra a proveedores.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Beneficio Diario vs Acumulado",
            description: "El detalle diario muestra el beneficio neto estricto de la jornada (siempre menor o igual a las ventas del día) y el acumulado histórico.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "¿Por qué hay 3 vistas en el gráfico?",
            description: "La vista 'Normalizada' (0% a 100%) permite comparar la curva de inventario y la de beneficios sin que una aplaste a la otra.",
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip: "💡 Un inventario en continuo ascenso con beneficio plano indica sobrecompra de mercadería estancada. Mantén ambas curvas creciendo en armonía.",
          ),
        ],
      ),
    );
  }

  Widget _buildModalMetricHeader({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildModalPracticalTip({required String tip}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Text(
        tip,
        style: const TextStyle(fontSize: 12, color: Colors.amber, height: 1.4, fontWeight: FontWeight.w500),
      ),
    );
  }
}
