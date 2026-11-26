part of '../predictive_analytics_screen.dart';

mixin _PredictivePatrimonyChartSectionMixin
    on _PredictiveAnalyticsScreenStateBase {
  // =========================================================================
  // 4. GRÁFICO PATRIMONIAL CON SELECTOR DE 3 VISTAS (SIN APLASTAR CURVAS)
  // =========================================================================
  @override
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
    double interval = pointsCount <= 7
        ? 1.0
        : (pointsCount <= 30 ? 5.0 : 15.0);

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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.purpleAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Evolución Patrimonial",
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: _buildExplainPill(
                  isDark: isDark,
                  onTap: _showPatrimonyExplainModal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de 3 vistas por pestañas/chips (con iconos vectoriales y cero emojis)
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
                    label: "Normalizada",
                    icon: Icons.tune_rounded,
                    index: 0,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildChartTabButton(
                    label: "Inventario",
                    icon: Icons.inventory_2_outlined,
                    index: 1,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildChartTabButton(
                    label: "Beneficio",
                    icon: Icons.monetization_on_outlined,
                    index: 2,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Leyenda dinámica según la vista activa (con Wrap para CERO overflow)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_selectedChartTab == 0 || _selectedChartTab == 1)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedChartTab == 0
                          ? "Inventario (%)"
                          : "Inventario (S/)",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              if (_selectedChartTab == 0 || _selectedChartTab == 2)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.purpleAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedChartTab == 0
                          ? "Beneficio (%)"
                          : "Beneficio (S/)",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              if (_selectedChartTab == 2)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text("Ventas (S/)", style: TextStyle(fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Gráfico dinámico con holgura superior, padding interno y títulos anti-colisión
          SizedBox(
            height: 230,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 12, bottom: 4),
              child: LineChart(
                LineChartData(
                  minY: 0.0,
                  maxY: _selectedChartTab == 0
                      ? 110.0
                      : (_selectedChartTab == 1
                            ? (maxInv > 0 ? maxInv * 1.15 : 100.0)
                            : ((maxProfit > maxSales ? maxProfit : maxSales) > 0
                                  ? (maxProfit > maxSales
                                            ? maxProfit
                                            : maxSales) *
                                        1.15
                                  : 100.0)),
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
                            // 🛡️ ANTI-COLISIÓN DE FECHAS: Si no es el último pero está pegado al final (< 2 puntos o < 0.75 * interval), suprimir
                            int distanceToLast = points.length - 1 - index;
                            if (distanceToLast > 0 &&
                                (distanceToLast < 2 ||
                                    distanceToLast < (interval * 0.75))) {
                              return const SizedBox.shrink();
                            }
                            String dateStr = points[index]['date'];
                            List<String> parts = dateStr.split('-');
                            if (parts.length == 3) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  "${parts[2]}/${parts[1]}",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
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
                        reservedSize: 54,
                        getTitlesWidget: (value, meta) {
                          if (_selectedChartTab == 0) {
                            // En normalizada, mostrar ticks limpios cada 25% y suprimir el 110% de holgura
                            if (value > 100.0) return const SizedBox.shrink();
                            if (value % 25 != 0 &&
                                value % 20 != 0 &&
                                value != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              "${value.toInt()}%",
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            );
                          } else {
                            if (value < 0) {
                              return const SizedBox.shrink(); // Cero negativos para evitar S/ -1 encimado sobre S/ 0
                            }
                            // 🛡️ ANTI-COLISIÓN DE EJE Y: Si el valor está muy cerca (< 0.35 * interval) de una línea de grilla entera
                            if (meta.appliedInterval > 0) {
                              double dist =
                                  (value / meta.appliedInterval) -
                                  (value / meta.appliedInterval).round();
                              if (dist.abs() > 0.05 && dist.abs() < 0.35) {
                                return const SizedBox.shrink();
                              }
                            }
                            if (value >= 1000) {
                              return Text(
                                "S/ ${(value / 1000).toStringAsFixed(1)}k",
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                ),
                              );
                            }
                            return Text(
                              "S/ ${value.toInt()}",
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey[500],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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
                          String dFmt = parts.length == 3
                              ? "${parts[2]}/${parts[1]}"
                              : dateStr;

                          double invVal =
                              (p['inventoryValue'] as num?)?.toDouble() ?? 0.0;
                          double netProf =
                              (p['netProfit'] as num?)?.toDouble() ?? 0.0;

                          return LineTooltipItem(
                            "$dFmt\nInv: ${AppCurrency.format(invVal)}\nBen: ${AppCurrency.format(netProf)}",
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? response) {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.lineBarSpots == null ||
                              response.lineBarSpots!.isEmpty) {
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
}
