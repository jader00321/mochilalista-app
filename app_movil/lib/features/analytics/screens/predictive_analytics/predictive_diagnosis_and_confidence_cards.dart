part of '../predictive_analytics_screen.dart';

mixin _PredictiveDiagnosisAndConfidenceCardsMixin
    on _PredictiveAnalyticsScreenStateBase {
  // =========================================================================
  // 3. DIAGNÓSTICO DEL MOTOR (TARJETA VISUAL ANIMADA, SIN DOBLE ROBOT)
  // =========================================================================
  @override
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
                  color: Colors.indigoAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: Colors.indigoAccent,
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
                    "Diagnóstico del Motor",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 4,
                child: _buildExplainPill(
                  isDark: isDark,
                  onTap: _showDiagnosisExplainModal,
                ),
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
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isInitialPhase
                              ? "Estado de Calibración del Motor"
                              : "Ritmo Quincenal de Ventas",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isInitialPhase
                                    ? Colors.teal
                                    : (isPositive
                                          ? Colors.green
                                          : Colors.redAccent))
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInitialPhase
                                ? Icons.spa_outlined
                                : (isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down),
                            size: 13,
                            color: isInitialPhase
                                ? Colors.teal
                                : (isPositive
                                      ? Colors.green
                                      : Colors.redAccent),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInitialPhase
                                ? "Etapa Inicial"
                                : "${isPositive ? '+' : ''}${velocity.toStringAsFixed(1)}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isInitialPhase
                                  ? Colors.teal
                                  : (isPositive
                                        ? Colors.green
                                        : Colors.redAccent),
                            ),
                          ),
                        ],
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
                      isInitialPhase
                          ? Colors.teal
                          : (isPositive ? Colors.green : Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Píldoras comparativas: Quincena Anterior vs Quincena Actual
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quincena Anterior",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppCurrency.format(_data!.previous15Sales),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quincena Actual",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                AppCurrency.format(_data!.current15Sales),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isInitialPhase
                                      ? Colors.teal
                                      : (isPositive
                                            ? Colors.green
                                            : Colors.redAccent),
                                ),
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
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. ESTIMACIONES TEÓRICAS Y NIVEL DE CONFIANZA ESTADÍSTICA
  // =========================================================================
  @override
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
              Icon(Icons.verified_outlined, color: confColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Estimaciones Teóricas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: confColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: confColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      "Confianza $confidence",
                      style: TextStyle(
                        color: confColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
              Flexible(
                child: Text(
                  "$days de 30 días óptimos",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: confColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Estos cálculos se basan en tus $days días de snapshots históricos. "
            "${confidence == 'Alta' ? 'Tu volumen de datos permite proyecciones sumamente confiables.' : 'A medida que registres más ventas diarias en Caja Rápida, Cotizaciones y Catálogo, la precisión de las proyecciones aumentará automáticamente.'}",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: confColor,
                side: BorderSide(color: confColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              icon: const Icon(Icons.point_of_sale_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "Registrar Ventas en Caja Rápida",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
