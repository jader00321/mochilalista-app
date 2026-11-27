part of '../sale_financial_detail_screen.dart';

mixin _SaleFinancialInstallmentsMixin on _SaleFinancialDetailScreenStateBase {
  Widget _buildInstallmentsSection(
    List<dynamic> cuotas,
    bool isDark,
    Color cardColor,
    Color textColor,
    bool isLoan,
  ) {
    if (cuotas.isEmpty) {
      return Center(
        child: Container(
          key: _tourKeys.scheduleTileKey,
          padding: const EdgeInsets.all(24),
          child: Text(
            "Esta venta se realizó al contado (Sin cuotas)",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            "Cronograma de Pagos",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.blueGrey[300] : Colors.blueGrey,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cuotas.length,
          itemBuilder: (ctx, i) => _buildInstallmentCard(
            index: i,
            c: cuotas[i] as Map<String, dynamic>,
            isDark: isDark,
            cardColor: cardColor,
            textColor: textColor,
            isLoan: isLoan,
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentCard({
    required int index,
    required Map<String, dynamic> c,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required bool isLoan,
  }) {
    final double cMonto = (num.tryParse(c['monto'].toString()) ?? 0.0)
        .toDouble();
    final double cPagado =
        (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0).toDouble();
    final double cMontoOriginal =
        (num.tryParse((c['monto_original'] ?? cMonto).toString()) ?? cMonto)
            .toDouble();
    final double cMoraMonto =
        (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0).toDouble();
    final double cMoraPorcentaje =
        (num.tryParse((c['mora_porcentaje'] ?? 0.0).toString()) ?? 0.0)
            .toDouble();
    final bool isAutoMora =
        c['mora_automatica'] == 1 || c['mora_automatica'] == true;

    double cSaldo = cMonto - cPagado;
    bool isPaid = c['estado'] == 'pagado';
    String statusText = c['estado'].toString().toUpperCase();

    if (cSaldo <= 0.02) {
      cSaldo = 0.0;
      isPaid = true;
      statusText = 'PAGADA';
    }

    final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
    final DateTime dueDate =
        CuotaDateHelper.parseFlexible(c['fecha_vencimiento']) ?? DateTime.now();
    final bool isOverdue = !isPaid && dateInfo.isPast;
    final int daysOverdue = dateInfo.daysOverdue;

    late final Color statusColor;
    late final IconData statusIcon;

    if (isPaid) {
      statusColor = isDark ? Colors.green[300]! : Colors.green.shade700;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'PAGADA';
    } else if (isOverdue) {
      statusColor = isDark ? Colors.red[300]! : Colors.red.shade700;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'VENCIDA';
    } else if (dateInfo.isToday) {
      statusColor = isDark ? Colors.amber[300]! : Colors.amber.shade800;
      statusIcon = Icons.notification_important_outlined;
      statusText = 'VENCE HOY';
    } else if (dateInfo.daysDifference >= -3) {
      statusColor = isDark ? Colors.orange[300]! : Colors.orange.shade800;
      statusIcon = Icons.schedule_rounded;
      statusText = 'PRÓXIMA';
    } else if (cPagado > 0) {
      statusColor = isDark ? Colors.blue[300]! : Colors.blue.shade700;
      statusIcon = Icons.payments_rounded;
      statusText = 'PARCIAL';
    } else {
      statusColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
      statusIcon = Icons.hourglass_top_rounded;
      statusText = 'PENDIENTE';
    }

    return Card(
      key: index == 0 ? _tourKeys.scheduleTileKey : null,
      elevation: 0,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: index == 0 ? _firstInstallmentController : null,
          iconColor: textColor,
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Cuota ${c['numero_cuota']}",
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  if (isAutoMora) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 11,
                            color: isDark
                                ? Colors.amber[300]
                                : Colors.amber[800],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            "Auto",
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.amber[300]
                                  : Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOverdue
                      ? "Venció hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'}"
                      : dateInfo.fullLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isOverdue
                        ? (isDark ? Colors.red[300] : Colors.red.shade800)
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (cMoraMonto > 0.01) ...[
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.amber : Colors.orange)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isDark ? Colors.amber : Colors.orange)
                              .withValues(alpha: 0.3),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        "Base: ${AppCurrency.format(cMontoOriginal)} • + Mora: ${AppCurrency.format(cMoraMonto)} (${cMoraPorcentaje.toStringAsFixed(1)}%)",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amber[300]
                              : Colors.orange[900],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 108, maxHeight: 48),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppCurrency.format(cMonto),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildFinancialRow(
                          "Monto Base:",
                          AppCurrency.format(cMontoOriginal),
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        _buildFinancialRow(
                          "Recargo por Mora:",
                          cMoraMonto > 0.01
                              ? "+ ${AppCurrency.format(cMoraMonto)}"
                              : AppCurrency.format(0.0),
                          valueColor: cMoraMonto > 0.01
                              ? (isDark ? Colors.redAccent : Colors.red)
                              : null,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 6),
                        _buildFinancialRow(
                          "Monto Abonado:",
                          AppCurrency.format(cPagado),
                          valueColor: isDark
                              ? Colors.greenAccent
                              : Colors.green.shade700,
                          isDark: isDark,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Divider(height: 1, thickness: 0.8),
                        ),
                        _buildFinancialRow(
                          "Saldo Exigible Cuota:",
                          AppCurrency.format(cSaldo),
                          isBold: true,
                          valueColor: cSaldo <= 0.02
                              ? (isDark ? Colors.greenAccent : Colors.green)
                              : (isDark ? Colors.redAccent : Colors.red),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  if (!isPaid) ...[
                    const SizedBox(height: 12),
                    _buildInstallmentActionsRow(
                      index: index,
                      c: c,
                      dueDate: dueDate,
                      cMoraMonto: cMoraMonto,
                      isOverdue: isOverdue,
                      isDark: isDark,
                      isLoan: isLoan,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
