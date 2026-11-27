part of '../client_full_stats_modal.dart';

mixin _ClientFullStatsExportAndCancellationsMixin on _ClientFullStatsModalBase {
  Future<void> _exportReport(bool isPdf) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    AppFeedbackHelper.showSnackBar(
      context,
      "Generando reporte ${isPdf ? 'PDF' : 'CSV'}... esto puede tardar unos segundos.",
      duration: const Duration(seconds: 2),
    );

    try {
      final businessName =
          authProvider.currentBusiness?.commercialName ??
          authProvider.user?.fullName ??
          'Mi Negocio';

      String periodText = "Todo el tiempo";
      if (_currentFilter == TimeFilter.oneWeek) {
        periodText = "Últimos 7 días";
      } else if (_currentFilter == TimeFilter.oneMonth) {
        periodText = "Últimos 30 días";
      } else if (_currentFilter == TimeFilter.sixMonths) {
        periodText = "Últimos 6 meses";
      } else if (_currentFilter == TimeFilter.custom &&
          _customStartDate != null &&
          _customEndDate != null) {
        periodText =
            "${AppDateFormatter.ddMMyy.format(_customStartDate!)} - ${AppDateFormatter.ddMMyy.format(_customEndDate!)}";
      }

      final filtered = _filteredSales;

      var file = isPdf
          ? await ClientStatsExportService.exportToPdf(
              client: widget.client,
              filteredSales: filtered,
              businessName: businessName,
              dateRangeText: periodText,
              extraStats: {'top_products': []},
            )
          : await ClientStatsExportService.exportToCsv(
              client: widget.client,
              filteredSales: filtered,
              businessName: businessName,
              dateRangeText: periodText,
              extraStats: {'top_products': []},
            );

      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'Adjunto el reporte de estadísticas de ${widget.client.fullName}.',
        ),
      );
    } catch (e) {
      if (mounted) {
        AppFeedbackHelper.showSnackBar(context, "Error al exportar: $e");
      }
    }
  }

  Widget _buildCancellationAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          "Análisis de Cancelaciones",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.red[300] : Colors.red[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
          children: [
            _buildStatCard(
              "Ventas Anuladas",
              (_cancellationStats!['anuladas'] as num).toDouble(),
              Icons.cancel_presentation,
              widget.isDark ? Colors.red[400]! : Colors.red[700]!,
              isInt: true,
            ),
            _buildStatCard(
              "Monto Perdido",
              (_cancellationStats!['montoPerdido'] as num).toDouble(),
              Icons.money_off,
              widget.isDark ? Colors.deepOrange[400]! : Colors.deepOrange[700]!,
            ),
            _buildStatCard(
              "Tasa de Cancelación",
              (_cancellationStats!['cancellationRate'] as num).toDouble(),
              Icons.pie_chart,
              widget.isDark ? Colors.pink[400]! : Colors.pink[700]!,
              textValue:
                  "${(_cancellationStats!['cancellationRate'] as num).toStringAsFixed(1)}%",
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withValues(alpha: widget.isDark ? 0.2 : 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Motivos Frecuentes",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              ...(_cancellationStats!['motivos'] as Map<String, int>).entries
                  .map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "${e.value} veces",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.red[300]
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        ),
      ],
    );
  }
}
