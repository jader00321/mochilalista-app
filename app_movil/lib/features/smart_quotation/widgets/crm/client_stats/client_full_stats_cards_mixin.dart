part of '../client_full_stats_modal.dart';

mixin _ClientFullStatsCardsMixin on _ClientFullStatsModalBase {
  Widget _buildAnimatedNumber(
    double targetValue, {
    Color? color,
    bool isInt = false,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: targetValue),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final String formatted = isInt
            ? value.toInt().toString()
            : AppCurrency.format(value);
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatted,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color ?? (widget.isDark ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget _buildStatCard(
    String title,
    double value,
    IconData icon,
    Color color, {
    bool isInt = false,
    String? textValue,
  }) {
    final bool isVeryLong = title.length > 16;
    final double titleFontSize = isVeryLong ? 10.0 : 11.2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: widget.isDark ? 0.22 : 0.35),
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isVeryLong ? 155.0 : 125.0,
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: widget.isDark
                            ? Colors.grey[300]
                            : Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: widget.isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: textValue != null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      textValue,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  )
                : _buildAnimatedNumber(value, color: color, isInt: isInt),
          ),
        ],
      ),
    );
  }

  @override
  String _calculatePurchaseFrequency(List<SaleSummary> salesList) {
    final salesOnly =
        salesList.where((s) => s.origenVenta != 'prestamo_personal').toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (salesOnly.isEmpty) return "Sin compras";
    if (salesOnly.length == 1) return "Compra única";

    final firstDate = DateTime.tryParse(salesOnly.first.date);
    final lastDate = DateTime.tryParse(salesOnly.last.date);
    if (firstDate == null || lastDate == null) return "N/A";

    final totalDays = lastDate.difference(firstDate).inDays;
    if (totalDays <= 0) return "Mismo día";

    final double avgDays = totalDays / (salesOnly.length - 1);
    if (avgDays < 1.5) return "Diaria (~1 día)";
    if (avgDays >= 6.0 && avgDays <= 8.5) return "Semanal (~7 días)";
    if (avgDays >= 13.0 && avgDays <= 17.0) return "Quincenal (~15 días)";
    if (avgDays >= 28.0 && avgDays <= 33.0) return "Mensual (~30 días)";

    return "Cada ${avgDays.round()} días";
  }

  @override
  Widget _buildCommercialBalanceCard({
    required double totalComprado,
    required double totalPagado,
    required double tasaCobro,
    required double saldoPendiente,
    required bool isDark,
  }) {
    final Color badgeColor = tasaCobro >= 80
        ? (isDark ? Colors.greenAccent : Colors.green.shade700)
        : (tasaCobro >= 50
              ? (isDark ? Colors.amberAccent : Colors.amber.shade800)
              : (isDark ? Colors.redAccent : Colors.red.shade700));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
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
          // Cabecera responsiva para evitar desbordamiento
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.15)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Comparativa Compras vs. Abonos",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "${tasaCobro.toStringAsFixed(1)}% Cubierto",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Barra Segmentada Dual Animada: Verde Esmeralda (Abonos) vs. Rojo Coral (Saldo Pendiente)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (context, anim, _) {
                  final double paidRatio = totalComprado > 0
                      ? (totalPagado / totalComprado).clamp(0.0, 1.0)
                      : 1.0;
                  final double pendingRatio = totalComprado > 0
                      ? (saldoPendiente / totalComprado).clamp(0.0, 1.0)
                      : 0.0;

                  final int paidFlex = (paidRatio * 1000 * anim).round();
                  final int pendingFlex = (pendingRatio * 1000 * anim).round();

                  return Row(
                    children: [
                      if (paidFlex > 0)
                        Expanded(
                          flex: paidFlex,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFF00E676),
                                        const Color(
                                          0xFF00B0FF,
                                        ).withValues(alpha: 0.7),
                                      ]
                                    : [
                                        const Color(0xFF2E7D32),
                                        const Color(0xFF43A047),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      if (paidFlex > 0 && pendingFlex > 0)
                        Container(
                          width: 2,
                          height: 12,
                          color: isDark
                              ? const Color(0xFF1E1E28)
                              : Colors.white,
                        ),
                      if (pendingFlex > 0)
                        Expanded(
                          flex: pendingFlex,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFFFF5252),
                                        const Color(0xFFFF7043),
                                      ]
                                    : [
                                        Colors.red.shade400,
                                        Colors.deepOrange.shade400,
                                      ],
                              ),
                            ),
                          ),
                        ),
                      if (paidFlex == 0 && pendingFlex == 0)
                        Expanded(
                          child: Container(
                            color: isDark ? Colors.white10 : Colors.grey[300],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Métodos y Resumen con Interactividad Táctil
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBalanceColumn(
                segmentKey: 'compras',
                label: 'Total Compras',
                amount: totalComprado,
                alignment: CrossAxisAlignment.start,
                selectedColor: Colors.blue,
                amountColor: isDark ? Colors.blue[300]! : Colors.blue[800]!,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              _buildBalanceColumn(
                segmentKey: 'abonos',
                label: 'Total Abonos',
                amount: totalPagado,
                alignment: CrossAxisAlignment.center,
                selectedColor: Colors.green,
                amountColor: isDark ? Colors.green[300]! : Colors.green[800]!,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 28,
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
              _buildBalanceColumn(
                segmentKey: 'saldo',
                label: 'Saldo Pendiente',
                amount: saldoPendiente,
                alignment: CrossAxisAlignment.end,
                selectedColor: Colors.red,
                amountColor: saldoPendiente > 0
                    ? (isDark ? Colors.red[300]! : Colors.red[700]!)
                    : (isDark ? Colors.green[300]! : Colors.green[700]!),
                isDark: isDark,
              ),
            ],
          ),

          // Feedback táctil interactivo al pulsar cualquier columna
          if (_selectedBalanceSegment != null) ...[
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _selectedBalanceSegment == 'abonos'
                    ? (isDark
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.green.shade50)
                    : (_selectedBalanceSegment == 'saldo'
                          ? (isDark
                                ? Colors.red.withValues(alpha: 0.12)
                                : Colors.red.shade50)
                          : (isDark
                                ? Colors.blue.withValues(alpha: 0.12)
                                : Colors.blue.shade50)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedBalanceSegment == 'abonos'
                      ? (isDark
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.green.shade200)
                      : (_selectedBalanceSegment == 'saldo'
                            ? (isDark
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.red.shade200)
                            : (isDark
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.blue.shade200)),
                ),
              ),
              child: Text(
                _selectedBalanceSegment == 'abonos'
                    ? "Total Abonos: Amortiza el ${tasaCobro.toStringAsFixed(1)}% de las compras."
                    : (_selectedBalanceSegment == 'saldo'
                          ? "Saldo Pendiente: Falta cobrar el ${(100 - tasaCobro).clamp(0.0, 100.0).toStringAsFixed(1)}%."
                          : "Total Compras: 100% del volumen comercial facturado."),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _selectedBalanceSegment == 'abonos'
                      ? (isDark ? Colors.green[300] : Colors.green[800])
                      : (_selectedBalanceSegment == 'saldo'
                            ? (isDark ? Colors.red[300] : Colors.red[800])
                            : (isDark ? Colors.blue[300] : Colors.blue[800])),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceColumn({
    required String segmentKey,
    required String label,
    required double amount,
    required CrossAxisAlignment alignment,
    required MaterialColor selectedColor,
    required Color amountColor,
    required bool isDark,
  }) {
    final isSelected = _selectedBalanceSegment == segmentKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _selectedBalanceSegment = isSelected ? null : segmentKey;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? selectedColor.withValues(alpha: 0.15)
                      : selectedColor.shade50)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppCurrency.format(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
