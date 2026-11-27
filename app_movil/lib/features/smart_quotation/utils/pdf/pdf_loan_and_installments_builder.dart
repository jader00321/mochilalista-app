part of '../pdf_generator.dart';

/// Construye la sección específica de préstamos personales.
pw.Widget _buildPdfLoanSection(
  Map<String, dynamic>? saleData,
  PdfConfig config,
  Map<String, PdfColor> colors, {
  required bool isTicket,
}) {
  if (saleData == null) return pw.Container();
  final double interesRate = (saleData['porcentaje_interes'] ?? 0.0).toDouble();
  final double totalWithInterest = (saleData['monto_total'] ?? 0.0).toDouble();
  final double abonoInicial = (saleData['abono_inicial'] ?? 0.0).toDouble();

  final double moraTotal = _extractPdfMoraTotal(saleData);

  // Proteger Capital e Interés Original ante recargos de mora
  final double pureTotalWithInterest = (totalWithInterest - moraTotal) > 0
      ? (totalWithInterest - moraTotal)
      : 0.0;
  final double debtWithInterest = (pureTotalWithInterest - abonoInicial) > 0
      ? (pureTotalWithInterest - abonoInicial)
      : 0.0;
  final double debtBase = (interesRate > 0 && debtWithInterest > 0)
      ? debtWithInterest / (1 + (interesRate / 100))
      : debtWithInterest;
  final double interestAmount = debtWithInterest - debtBase;
  final double capitalNeto = abonoInicial + debtBase;

  final double abonado = (saleData['monto_pagado'] ?? 0.0).toDouble();
  final double saldo = totalWithInterest - abonado > 0
      ? totalWithInterest - abonado
      : 0.0;

  final String rateLabel = interesRate > 0
      ? '${interesRate.toStringAsFixed(1)}%'
      : '0%';
  final String interestDisplay = interestAmount > 0.01
      ? "+ ${AppCurrency.format(interestAmount)}"
      : AppCurrency.format(0.0);

  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: colors['accent'],
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "RESUMEN DE PRÉSTAMO",
          style: pw.TextStyle(
            fontSize: isTicket ? 9 : 11,
            fontWeight: pw.FontWeight.bold,
            color: colors['primary'],
          ),
        ),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        _buildPdfPaymentRow(
          "Capital Prestado:",
          AppCurrency.format(capitalNeto),
          isTicket: isTicket,
        ),
        _buildPdfPaymentRow(
          "Interés Aplicado ($rateLabel):",
          interestDisplay,
          isTicket: isTicket,
        ),
        if (moraTotal > 0.01)
          _buildPdfPaymentRow(
            "Recargo por Mora:",
            "+ ${AppCurrency.format(moraTotal)}",
            isBold: true,
            valueColor: colors['debt'],
            isTicket: isTicket,
          ),
        _buildPdfPaymentRow(
          "Total a Devolver:",
          AppCurrency.format(totalWithInterest),
          isBold: true,
          isTicket: isTicket,
        ),
        if (abonoInicial > 0.01)
          _buildPdfPaymentRow(
            "Abono Inicial:",
            AppCurrency.format(abonoInicial),
            isTicket: isTicket,
          ),
        _buildPdfPaymentRow(
          "Monto Abonado:",
          AppCurrency.format(abonado),
          isTicket: isTicket,
        ),
        _buildPdfPaymentRow(
          "Saldo Pendiente:",
          AppCurrency.format(saldo),
          isBold: true,
          valueColor: saldo > 0 ? colors['debt'] : colors['savings'],
          isTicket: isTicket,
        ),
      ],
    ),
  );
}

pw.Widget? _buildPdfInstallmentsBox(
  List<dynamic>? cuotasRaw,
  PdfConfig config, {
  required bool isLoan,
  required bool isTicket,
}) {
  if (!config.showInstallments || cuotasRaw == null || cuotasRaw.isEmpty) {
    return null;
  }

  return pw.Container(
    margin: pw.EdgeInsets.only(top: isLoan ? 0 : 10),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "PLAN DE CUOTAS (${cuotasRaw.length} cuotas)",
          style: pw.TextStyle(
            fontSize: isTicket ? 8 : 9.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ...cuotasRaw.map((c) {
          final double cuotaMonto = (num.tryParse(c['monto'].toString()) ?? 0.0)
              .toDouble();
          final double cuotaPagado =
              (num.tryParse((c['monto_pagado'] ?? 0.0).toString()) ?? 0.0)
                  .toDouble();
          final double saldoFalta = (cuotaMonto - cuotaPagado) > 0.001
              ? (cuotaMonto - cuotaPagado)
              : 0.0;
          final double moraMonto =
              (num.tryParse((c['mora_monto'] ?? 0.0).toString()) ?? 0.0)
                  .toDouble();
          final double montoOriginal =
              (num.tryParse((c['monto_original'] ?? cuotaMonto).toString()) ??
                      cuotaMonto)
                  .toDouble();
          final bool tieneMora = moraMonto > 0.01;
          final bool pagado =
              c['estado'] == 'pagado' || (saldoFalta <= 0.01 && cuotaMonto > 0);

          final dateInfo = CuotaDateHelper.evaluate(c['fecha_vencimiento']);
          final int daysOverdue = dateInfo.daysOverdue;
          final bool isVencida = !pagado && dateInfo.isPast;

          String statusText;
          PdfColor statusColor;

          if (pagado) {
            statusText = "PAGADA";
            statusColor = PdfColors.green700;
          } else if (isVencida) {
            statusColor = PdfColors.red700;
            if (cuotaPagado > 0.01) {
              statusText =
                  "VENCIDA ($daysOverdue d) | PAGO PARCIAL (Abonó: ${AppCurrency.format(cuotaPagado)} | Falta: ${AppCurrency.format(saldoFalta)})";
            } else if (tieneMora) {
              statusText = "VENCIDA ($daysOverdue d) | CON MORA";
            } else {
              statusText = "VENCIDA ($daysOverdue d)";
            }
          } else if (cuotaPagado > 0.01) {
            statusText =
                "PAGO PARCIAL (Abonó: ${AppCurrency.format(cuotaPagado)} | Falta: ${AppCurrency.format(saldoFalta)})";
            statusColor = PdfColors.orange800;
          } else if (dateInfo.isToday) {
            statusText = "VENCE HOY";
            statusColor = PdfColors.amber800;
          } else {
            statusText = "PENDIENTE";
            statusColor = PdfColors.orange700;
          }

          final String moraInfo = tieneMora
              ? " (Base: ${AppCurrency.format(montoOriginal)} + Mora: ${AppCurrency.format(moraMonto)})"
              : "";

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: isTicket
                ? pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            "Cuota ${c['numero_cuota']}: ${AppCurrency.format(cuotaMonto)}",
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            dateInfo.fullLabel,
                            style: const pw.TextStyle(
                              fontSize: 7,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      if (tieneMora)
                        pw.Text(
                          moraInfo.trim(),
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                      pw.Text(
                        statusText,
                        style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                    ],
                  )
                : pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          "Cuota ${c['numero_cuota']}: ${AppCurrency.format(cuotaMonto)}$moraInfo",
                          style: const pw.TextStyle(fontSize: 8.5),
                        ),
                      ),
                      pw.Text(
                        dateInfo.fullLabel,
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        statusText,
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
          );
        }),
      ],
    ),
  );
}
