part of '../predictive_analytics_screen.dart';

mixin _PredictiveSummaryAndDiagnosisCardsMixin
    on _PredictiveAnalyticsScreenStateBase {
  // =========================================================================
  // 1. TARJETA PRINCIPAL: PROYECCIÓN A 30 DÍAS CON 3 ESCENARIOS Y ACCESO RÁPIDO
  // =========================================================================
  @override
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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_graph,
                  color: Colors.white,
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
                    "Proyección a 30 Días",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
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
                  onTap: _showProjectionExplainModal,
                  isLightOnGradient: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            "Se proyecta que cerrarás el próximo mes con ventas por:",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0,
                end: _data!.predictedNext30DaysSales,
              ),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Text(
                  AppCurrency.format(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
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
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.amberAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _data!.actionText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 14,
                    ),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isFeatured ? FontWeight.bold : FontWeight.normal,
              color: isFeatured ? Colors.white : Colors.white70,
            ),
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
}
