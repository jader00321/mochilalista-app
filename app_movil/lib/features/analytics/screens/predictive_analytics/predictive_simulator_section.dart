part of '../predictive_analytics_screen.dart';

mixin _PredictiveSimulatorSectionMixin
    on _PredictiveAnalyticsScreenStateBase {
  // =========================================================================
  // 2. SIMULADOR DE ESCENARIOS INTELIGENTE
  // =========================================================================
  @override
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
    double breakEven = simMargin > 0
        ? ((baseSales * 0.15) / (simMargin / 100.0))
        : 0.0;

    // Distinción estricta de estados lógicos
    final bool isBaseScenario = diffProfit.abs() < 0.01;
    final bool isFavorable = diffProfit > 0.01;

    String scenarioTitle;
    Color scenarioColor;
    IconData scenarioIcon;

    if (isBaseScenario) {
      scenarioTitle =
          "Escenario base proyectado. Ajusta los controles para ver el impacto.";
      scenarioColor = isDark ? Colors.grey[400]! : Colors.blueGrey;
      scenarioIcon = Icons.info_outline;
    } else if (isFavorable) {
      scenarioTitle = "¡Excelente! Este escenario aumenta tu ganancia esperada.";
      scenarioColor = Colors.green;
      scenarioIcon = Icons.arrow_upward_rounded;
    } else {
      scenarioTitle =
          "Cuidado, este escenario reduce tu rentabilidad proyectada.";
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
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune,
                  color: Colors.blueAccent,
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
                    "Simulador de Escenarios",
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
                  onTap: _showSimulatorExplainModal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Ajusta los controles o usa accesos rápidos para ver el impacto en tus ganancias proyectadas.",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),

          // Chips de simulación rápida en 1 toque (Usa Wrap para CERO unbounded height)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickSimulationChip(
                label: "Campaña (+30% ventas)",
                icon: Icons.trending_up,
                isSelected:
                    _salesSimulationPct == 30.0 &&
                    _costsSimulationPct == 0.0 &&
                    _discountPct == 0.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 30.0 &&
                        _costsSimulationPct == 0.0 &&
                        _discountPct == 0.0) {
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
                label: "Subida Proveedor (+10% costos)",
                icon: Icons.local_shipping_outlined,
                isSelected:
                    _salesSimulationPct == 0.0 &&
                    _costsSimulationPct == 10.0 &&
                    _discountPct == 0.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 0.0 &&
                        _costsSimulationPct == 10.0 &&
                        _discountPct == 0.0) {
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
                label: "Liquidación (+20% ventas, -5% dto.)",
                icon: Icons.local_offer_outlined,
                isSelected:
                    _salesSimulationPct == 20.0 &&
                    _costsSimulationPct == 0.0 &&
                    _discountPct == 5.0,
                onTap: () {
                  setState(() {
                    if (_salesSimulationPct == 20.0 &&
                        _costsSimulationPct == 0.0 &&
                        _discountPct == 5.0) {
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
                label: "Restaurar 0%",
                icon: Icons.refresh_rounded,
                isSelected:
                    _salesSimulationPct == 0.0 &&
                    _costsSimulationPct == 0.0 &&
                    _discountPct == 0.0,
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
          _buildSimulationSlider(
            isDark: isDark,
            title: "Variación en Volumen",
            subtitle: "Proyecta si logras vender más o menos mercadería",
            valueLabel:
                "${_salesSimulationPct > 0 ? '+' : ''}${_salesSimulationPct.toInt()}%",
            valueColor: Colors.blueAccent,
            value: _salesSimulationPct,
            min: -50,
            max: 100,
            divisions: 30,
            activeColor: Colors.blueAccent,
            minLabel: "-50%",
            midLabel: "0%",
            maxLabel: "+100%",
            onChanged: (val) {
              setState(() {
                _salesSimulationPct = val;
                if (val != 20.0) _discountPct = 0.0;
              });
            },
          ),
          const SizedBox(height: 14),

          // Slider 2: Costos
          _buildSimulationSlider(
            isDark: isDark,
            title: "Variación en Costos de Proveedor",
            subtitle: "Qué pasa si suben o bajan precios de compra",
            valueLabel:
                "${_costsSimulationPct > 0 ? '+' : ''}${_costsSimulationPct.toInt()}%",
            valueColor: Colors.redAccent,
            value: _costsSimulationPct,
            min: -50,
            max: 50,
            divisions: 20,
            activeColor: Colors.redAccent,
            minLabel: "-50%",
            midLabel: "0%",
            maxLabel: "+50%",
            onChanged: (val) {
              setState(() {
                _costsSimulationPct = val;
                if (val != 0.0) _discountPct = 0.0;
              });
            },
          ),
          const SizedBox(height: 14),

          // Slider 3: Descuento Comercial en Precio
          _buildSimulationSlider(
            isDark: isDark,
            title: "Variación en Precio / Descuento",
            subtitle: "Rebajas de precio en promociones o liquidación",
            valueLabel: _discountPct > 0 ? "-${_discountPct.toInt()}%" : "0%",
            valueColor: _discountPct > 0 ? Colors.amber[700]! : Colors.grey,
            value: _discountPct,
            min: 0,
            max: 25,
            divisions: 5,
            activeColor: Colors.amber[700]!,
            minLabel: "0%",
            midLabel: "-10%",
            maxLabel: "-25%",
            onChanged: (val) {
              setState(() {
                _discountPct = val;
              });
            },
          ),

          const SizedBox(height: 20),
          _buildSimulatorResultPanel(
            isDark: isDark,
            baseProfit: baseProfit,
            simSales: simSales,
            simCosts: simCosts,
            simProfit: simProfit,
            diffProfit: diffProfit,
            simMargin: simMargin,
            breakEven: breakEven,
            isBaseScenario: isBaseScenario,
            isFavorable: isFavorable,
            scenarioTitle: scenarioTitle,
            scenarioColor: scenarioColor,
            scenarioIcon: scenarioIcon,
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationSlider({
    required bool isDark,
    required String title,
    required String subtitle,
    required String valueLabel,
    required Color valueColor,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color activeColor,
    required String minLabel,
    required String midLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minLabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Text(
                midLabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Text(
                maxLabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
