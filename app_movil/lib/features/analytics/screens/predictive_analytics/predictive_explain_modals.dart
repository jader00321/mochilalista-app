part of '../predictive_analytics_screen.dart';

mixin _PredictiveExplainModalsMixin on _PredictiveAnalyticsScreenStateBase {
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              "Entendido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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

  @override
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
            description:
                "El motor tomó los ${_data!.totalSnapshots} días de ventas registrados en tu negocio.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Ritmo Diario Promedio",
            description:
                "Tus ventas promedio actuales son de ${AppCurrency.format(_data!.dailyAverageSales)} por día.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "Suavizado y Amortiguación de Tendencia",
            description:
                "Se atenúan picos atípicos y se amortigua la pendiente para garantizar proyecciones financieramente coherentes.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "4",
            title: "Regresión Amortiguada y 3 Escenarios",
            description:
                "Tendencia detectada: ${_data!.trendSlopeM >= 0 ? '+' : ''}${AppCurrency.format(_data!.trendSlopeM)}/día. Se estiman 3 escenarios de cierre de mes:",
            isDark: isDark,
            extraContent: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Conservador (80%):",
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(_data!.conservativeEstimate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Esperado (100%):",
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(_data!.expectedEstimate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Optimista (120%):",
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppCurrency.format(_data!.optimisticEstimate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip:
                "Utiliza la proyección para presupuestar tus compras a proveedores sin arriesgar tu liquidez ni sobreendeudarte.",
          ),
        ],
      ),
    );
  }

  @override
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
    double breakEven = simMargin > 0
        ? ((baseSales * 0.15) / (simMargin / 100.0))
        : 0.0;

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
            description:
                "Ventas = Ventas Base × (1 + % Volumen) × (1 - % Descuento). Simula tanto más unidades como promociones.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Costos Conectados al Volumen y Proveedor",
            description:
                "Costos = Costos Base × (1 + % Volumen) × (1 + % Proveedor). Al vender más unidades, el costo de mercadería escala en armonía.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "Beneficio y Margen Resultante",
            description:
                "Beneficio = Ventas - Costos. En este escenario tu margen neto es de ${simMargin.toStringAsFixed(1)}%.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "4",
            title: "Punto de Equilibrio Operativo",
            description:
                "Ventas mínimas estimadas (${AppCurrency.format(breakEven)}) necesarias para cubrir los costos de operación del mes.",
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip:
                "Usa los chips de 1 toque para simular campañas comerciales antes de lanzar ofertas y verificar si el volumen compensará el descuento.",
          ),
        ],
      ),
    );
  }

  @override
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
                ? "Etapa Inicial"
                : "${_data!.salesVelocity >= 0 ? '+' : ''}${_data!.salesVelocity.toStringAsFixed(1)}%",
            color: _data!.isInitialPhase
                ? Colors.teal
                : (_data!.salesVelocity >= 0 ? Colors.green : Colors.redAccent),
          ),
          const SizedBox(height: 16),
          _buildTimelineStepCard(
            stepNumber: "1",
            title: "Comparación de Quincenas",
            description:
                "Quincena Actual (${AppCurrency.format(_data!.current15Sales)}) vs Quincena Anterior (${AppCurrency.format(_data!.previous15Sales)}).",
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
            tip:
                "Revisa este indicador cada semana para anticiparte a quiebres de stock o temporadas lentas antes de que termine el mes.",
          ),
        ],
      ),
    );
  }

  @override
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
            description:
                "Es la suma del stock físico multiplicado por su costo unitario de compra a proveedores.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "2",
            title: "Beneficio Diario vs Acumulado",
            description:
                "El detalle diario muestra el beneficio neto estricto de la jornada (siempre menor o igual a las ventas del día) y el acumulado histórico.",
            isDark: isDark,
          ),
          _buildTimelineStepCard(
            stepNumber: "3",
            title: "¿Por qué hay 3 vistas en el gráfico?",
            description:
                "La vista 'Normalizada' (0% a 100%) permite comparar la curva de inventario y la de beneficios sin que una aplaste a la otra.",
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildModalPracticalTip(
            tip:
                "Un inventario en continuo ascenso con beneficio plano indica sobrecompra de mercadería estancada. Mantén ambas curvas creciendo en armonía.",
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalPracticalTip({required String tip}) {
    String cleanTip = tip.startsWith("💡 ") ? tip.substring(3) : tip;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cleanTip,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.amber,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
