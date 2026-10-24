import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

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
              const Text("Aún no hay suficientes datos históricos", 
                         textAlign: TextAlign.center, 
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text("El motor predictivo necesita recopilar datos diarios (snapshots) para generar proyecciones precisas. Vuelve en un par de días para ver tu crecimiento.",
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: 16, color: Colors.grey)),
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

  Widget _buildWarningBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimaciones Teóricas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                const SizedBox(height: 6),
                Text(
                  "Ten en cuenta que estos son cálculos teóricos basados en tu historial de ventas actual. Pueden existir variaciones debido a cambios bruscos en el mercado, feriados o falta de datos prolongados.",
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
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
            offset: const Offset(0, 10)
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_graph, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text("Proyección a 30 Días", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Se proyecta que cerrarás el próximo mes con ventas por:", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _data!.predictedNext30DaysSales),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  AppCurrency.format(value),
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _data!.actionText,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExplainabilityCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              const Text("🤖 Diagnóstico del Motor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _data!.explanationText,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700], height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulator(bool isDark) {
    // Calculos simulados
    double baseSales = _data!.predictedNext30DaysSales;
    
    // Por simplicidad en la UI del simulador, asumimos un margen del 30% si no tenemos el real a mano
    // En el futuro, podría sacarse de analytics_provider
    double assumedMargin = 0.3; 
    double baseCosts = baseSales * (1 - assumedMargin);
    double baseProfit = baseSales - baseCosts;
    
    double simSales = baseSales * (1 + (_salesSimulationPct / 100.0));
    double simCosts = baseCosts * (1 + (_costsSimulationPct / 100.0));
    double simProfit = simSales - simCosts;
    
    double diffProfit = simProfit - baseProfit;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.tune, color: Colors.blueAccent),
              ),
              const SizedBox(width: 12),
              const Text("Simulador de Escenarios", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Ajusta los controles para ver el impacto en tus ganancias proyectadas.",
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          
          // Slider 1: Ventas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Variación en Ventas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Proyecta si logras vender más o menos", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
              Text("${_salesSimulationPct > 0 ? '+' : ''}${_salesSimulationPct.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            ],
          ),
          Slider(
            value: _salesSimulationPct,
            min: -50,
            max: 100,
            divisions: 30,
            activeColor: Colors.blueAccent,
            onChanged: (val) {
              setState(() => _salesSimulationPct = val);
            },
          ),
          const SizedBox(height: 16),
          
          // Slider 2: Costos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Variación en Costos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Qué pasa si suben los precios de proveedor", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
              Text("${_costsSimulationPct > 0 ? '+' : ''}${_costsSimulationPct.toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            ],
          ),
          Slider(
            value: _costsSimulationPct,
            min: -50,
            max: 50,
            divisions: 20,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              setState(() => _costsSimulationPct = val);
            },
          ),
          
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: simProfit >= baseProfit 
                    ? Colors.green.withValues(alpha: 0.3) 
                    : Colors.redAccent.withValues(alpha: 0.3)
              ),
            ),
            child: Column(
              children: [
                const Text("Beneficio Neto Simulado", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: baseProfit, end: simProfit),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, child) {
                      return Text(
                        AppCurrency.format(value),
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: value >= baseProfit ? Colors.green : Colors.redAccent
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(diffProfit >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: diffProfit >= 0 ? Colors.green : Colors.redAccent),
                    const SizedBox(width: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: diffProfit.abs()),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Text(
                          "${AppCurrency.format(value)} vs proy. base",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: diffProfit >= 0 ? Colors.green : Colors.redAccent),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  diffProfit >= 0 
                      ? "¡Excelente! Este escenario aumenta tu ganancia esperada." 
                      : "Cuidado, este escenario reduce tu rentabilidad.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500, 
                    color: isDark ? Colors.grey[400] : Colors.grey[700]
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPatrimonyChart(bool isDark) {
    if (_data!.historicalPoints.length < 2) return const SizedBox.shrink();

    List<FlSpot> inventorySpots = [];
    List<FlSpot> patrimonySpots = []; // Patrimony = Inventory + Profit
    
    for (int i = 0; i < _data!.historicalPoints.length; i++) {
      double invVal = (_data!.historicalPoints[i]['inventoryValue'] as num?)?.toDouble() ?? 0.0;
      double patVal = (_data!.historicalPoints[i]['patrimony'] as num).toDouble();
      
      inventorySpots.add(FlSpot(i.toDouble(), invVal));
      patrimonySpots.add(FlSpot(i.toDouble(), patVal));
    }

    int pointsCount = _data!.historicalPoints.length;
    double dotRadius = 2.0;
    bool showDots = false;
    double interval = 1;
    
    if (pointsCount <= 7) {
      dotRadius = 5.0;
      showDots = true;
      interval = 1;
    } else if (pointsCount <= 30) {
      dotRadius = 3.0;
      showDots = true;
      interval = 5;
    } else if (pointsCount <= 90) {
      dotRadius = 2.0;
      showDots = true;
      interval = 15;
    } else if (pointsCount <= 180) {
      dotRadius = 2.0;
      showDots = false;
      interval = 30;
    } else {
      showDots = false;
      interval = 60;
    }

    return Container(
      padding: const EdgeInsets.all(24),
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
          const Text("Evolución Patrimonial (Desglosada)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(width: 10, height: 10, color: Colors.blueAccent),
              const SizedBox(width: 4),
              const Text("Inventario", style: TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, color: Colors.purpleAccent),
              const SizedBox(width: 4),
              const Text("Beneficio", style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _data!.historicalPoints.length) {
                          String dateStr = _data!.historicalPoints[index]['date']; // yyyy-MM-dd
                          List<String> parts = dateStr.split('-');
                          if (parts.length == 3) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text("${parts[2]}/${parts[1]}", style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: patrimonySpots,
                    isCurved: true,
                    color: Colors.purpleAccent,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: showDots, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: dotRadius, color: Colors.purpleAccent, strokeWidth: 0)),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.purpleAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  LineChartBarData(
                    spots: inventorySpots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: showDots, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: dotRadius, color: Colors.blueAccent, strokeWidth: 0)),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blueAccent.withValues(alpha: 0.3),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipMargin: 20,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        int index = spot.x.toInt();
                        String dateStr = "";
                        if (index >= 0 && index < _data!.historicalPoints.length) {
                           dateStr = _data!.historicalPoints[index]['date'];
                           List<String> parts = dateStr.split('-');
                           if (parts.length == 3) {
                             dateStr = "${parts[2]}/${parts[1]}/${parts[0]}";
                           }
                        }
                        return LineTooltipItem(
                          "$dateStr\n${AppCurrency.format(spot.y)}",
                          TextStyle(color: spot.barIndex == 0 ? Colors.purpleAccent : Colors.blueAccent, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (!event.isInterestedForInteractions || response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                      return;
                    }
                    int index = response.lineBarSpots!.first.x.toInt();
                    if (index >= 0 && index < _data!.historicalPoints.length) {
                      setState(() {
                        _selectedPatrimonyPoint = _data!.historicalPoints[index];
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPatrimonyDetailPanel(isDark),
        ],
      ),
    );
  }

  Widget _buildPatrimonyDetailPanel(bool isDark) {
    if (_selectedPatrimonyPoint == null) return const SizedBox.shrink();
    
    String dateStr = _selectedPatrimonyPoint!['date'];
    List<String> parts = dateStr.split('-');
    String formattedDate = parts.length == 3 ? "${parts[2]}/${parts[1]}/${parts[0]}" : dateStr;
    
    double invValue = (_selectedPatrimonyPoint!['inventoryValue'] as num?)?.toDouble() ?? 0.0;
    double netProfit = (_selectedPatrimonyPoint!['netProfit'] as num?)?.toDouble() ?? 0.0;
    double dailySales = (_selectedPatrimonyPoint!['dailySales'] as num).toDouble();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(dateStr),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.black12 : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.date_range, color: Colors.purpleAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Beneficio", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(AppCurrency.format(netProfit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purpleAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Inventario", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(AppCurrency.format(invValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text("Ventas", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(AppCurrency.format(dailySales), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
