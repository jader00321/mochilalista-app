part of '../analytics_dashboard_screen.dart';

mixin _AnalyticsDashboardStatesAndActionsMixin
    on _AnalyticsDashboardScreenStateBase {
  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      AnalyticsDashboardTour.buildConfig(keys: _tourKeys),
    );
  }

  @override
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

  @override
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

  @override
  String _formatCurrency(double amount) {
    if (_obscureAmounts) return 'S/ ***.**';
    return AppCurrency.format(amount);
  }

  Future<void> _pickCustomDateRange(AnalyticsProvider prov) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: prov.customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      prov.setCustomDateRange(picked);
    }
  }

  @override
  void _showDashboardGuide(BuildContext context) {
    InfoTooltipButton.showInfoModal(
      context: context,
      title: "Inteligencia de Negocio & Radar",
      description:
          "Panel de analítica ejecutiva, financiera y comercial. Integra predicción con IA, inventario estancado y radar de noticias del mercado en tiempo real.",
      onStartInteractiveTour: () => _startTour(context),
      tips: const [
        InfoTip(
          icon: Icons.dashboard_customize,
          text: "Presiona el ícono de personalización (⚙️ / deslizador) para reordenar u ocultar tarjetas con arrastre táctil.",
        ),
        InfoTip(
          icon: Icons.radar,
          text: "El Radar Comercial sintoniza noticias de carreteras, clima, leyes de SUNAT y campañas en Perú y tu región.",
        ),
        InfoTip(
          icon: Icons.visibility_outlined,
          text: "Oculta saldos con el ícono del ojo para operar seguro frente a clientes en el mostrador.",
        ),
        InfoTip(
          icon: Icons.file_download_outlined,
          text: "Exporta tu informe completo en PDF formal o Excel CSV con la moneda oficial.",
        ),
      ],
    );
  }

  @override
  Widget _buildBody(AnalyticsProvider prov, bool isDark, AuthProvider auth) {
    if (prov.currentStep == AnalyticsStep.idle) {
      return _buildIdleScreen(prov, isDark);
    }

    if (prov.currentStep != AnalyticsStep.done && prov.currentStep != AnalyticsStep.error) {
      return _buildLoadingScreen(prov, isDark);
    }

    if (prov.currentStep == AnalyticsStep.error) {
      return _buildErrorScreen(prov);
    }

    return _buildCustomScrollView(prov, isDark);
  }

  Widget _buildIdleScreen(AnalyticsProvider prov, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing pulsing halo icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.12 + (_pulseController.value * 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.25 * _pulseController.value),
                        blurRadius: 30 * _pulseController.value,
                        spreadRadius: 6 * _pulseController.value,
                      )
                    ],
                  ),
                  child: const Icon(Icons.query_stats, size: 72, color: Colors.blueAccent),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Inteligencia de Negocio & Radar",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              "Métricas auditadas a 0ms, proyecciones comerciales y señales de mercado en tiempo real para tu negocio.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, 
                height: 1.4,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // 4 Sleek Preview Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                KeyedSubtree(
                  key: _tourKeys.financialKpisKey,
                  child: _buildIdleFeatureBadge("📊 Ganancia Neta Real", "Sin margen de error", isDark),
                ),
                KeyedSubtree(
                  key: _tourKeys.salesPaymentChartsKey,
                  child: _buildIdleFeatureBadge("🚀 Motor Predictivo", "Tendencias de ventas", isDark),
                ),
                KeyedSubtree(
                  key: _tourKeys.restockAlertsKey,
                  child: _buildIdleFeatureBadge("📦 Inventario Muerto", "Rescate de liquidez", isDark),
                ),
                KeyedSubtree(
                  key: _tourKeys.radarInsightsKey,
                  child: _buildIdleFeatureBadge("📰 Radar Mercado IA", "Perú & Tu Región", isDark),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pre-selección de Periodo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Selecciona el periodo a analizar:",
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prov.selectedPeriod == AnalyticsPeriod.custom && prov.customDateRange != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "${AppDateFormatter.ddMM.format(prov.customDateRange!.start)} - ${AppDateFormatter.ddMM.format(prov.customDateRange!.end)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: _buildPeriodChipsRow(prov, isDark, isPreSelect: true),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Primary CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => prov.runStaggeredAnalysis(),
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  "Generar Reporte Integral", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleFeatureBadge(String title, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title, 
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold), 
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle, 
            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(AnalyticsProvider prov, bool isDark) {
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
                  child: CircularProgressIndicator(
                    value: prov.progress, 
                    strokeWidth: 8, 
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
                Text(
                  "${(prov.progress * 100).toInt()}%", 
                  style: const TextStyle(fontSize: 24, color: Colors.blueAccent, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildLoadingStep("Consultando ventas del periodo...", prov.currentStep.index > AnalyticsStep.sales.index, prov.currentStep == AnalyticsStep.sales, isDark),
            _buildLoadingStep("Evaluando mejores clientes y recurrencia...", prov.currentStep.index > AnalyticsStep.clients.index, prov.currentStep == AnalyticsStep.clients, isDark),
            _buildLoadingStep("Analizando rotación y capital inmovilizado...", prov.currentStep.index > AnalyticsStep.insights.index, prov.currentStep == AnalyticsStep.insights, isDark),
          ],
        ),
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
            color: isDone ? Colors.greenAccent : (isActive ? Colors.blueAccent : (isDark ? Colors.white30 : Colors.black26)),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isDone 
                    ? (isDark ? Colors.white : Colors.black87) 
                    : (isActive ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.black54)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildErrorScreen(AnalyticsProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 72, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(
              prov.statusMessage, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => prov.runStaggeredAnalysis(),
              icon: const Icon(Icons.refresh),
              label: const Text("Intentar Nuevamente"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildPeriodChipsRow(AnalyticsProvider prov, bool isDark, {required bool isPreSelect}) {
    final periods = [
      {'val': AnalyticsPeriod.today, 'label': 'Hoy'},
      {'val': AnalyticsPeriod.week, 'label': '7 Días'},
      {'val': AnalyticsPeriod.month, 'label': '30 Días'},
      {'val': AnalyticsPeriod.sixMonths, 'label': '6 Meses'},
      {'val': AnalyticsPeriod.allTime, 'label': 'Todo'},
      {'val': AnalyticsPeriod.custom, 'label': 'Personalizado'},
    ];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: isPreSelect ? 0 : 16),
      itemCount: periods.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final p = periods[index];
        final val = p['val'] as AnalyticsPeriod;
        final isSelected = prov.selectedPeriod == val;

        return ChoiceChip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          label: Text(
            p['label'] as String, 
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (val == AnalyticsPeriod.custom) {
              _pickCustomDateRange(prov);
            } else {
              prov.changePeriod(val);
            }
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
    );
  }
}
