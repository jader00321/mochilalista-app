part of '../pdf_generator.dart';

/// Construye los totales financieros con verdad contable estricta.
pw.Widget _buildPdfTotalsSection(
  SmartQuotationModel q,
  PdfConfig config,
  Map<String, PdfColor> colors,
  Map<String, dynamic>? saleData, {
  required bool isTicket,
}) {
  if (!config.showTotalGlobal && !config.showTransactionDetails) {
    return pw.Container();
  }

  final bool isSale = saleData != null;
  final bool isLoan = isSale && saleData['origen_venta'] == 'prestamo_personal';

  final List<dynamic>? cuotasRaw = isSale ? saleData['cuotas'] : null;
  final pw.Widget? cuotasWidget = _buildPdfInstallmentsBox(
    cuotasRaw,
    config,
    isLoan: isLoan,
    isTicket: isTicket,
  );

  // Si es préstamo personal, no duplicar bloque de totales globales
  if (isLoan) {
    return cuotasWidget ?? pw.Container();
  }

  final double finalTotal = isSale
      ? (saleData['monto_total'] ?? 0.0).toDouble()
      : q.totalAmount;
  final double finalSavings = isSale
      ? (saleData['descuento_aplicado'] ?? 0.0).toDouble()
      : q.totalSavings;
  final double paidAmount = isSale
      ? (saleData['monto_pagado'] ?? 0.0).toDouble()
      : 0.0;
  final double debt = finalTotal - paidAmount > 0
      ? finalTotal - paidAmount
      : 0.0;
  final bool showTransDetails = isSale && config.showTransactionDetails;

  final double moraTotalSale = isSale ? _extractPdfMoraTotal(saleData) : 0.0;

  final totalsBox = pw.Container(
    width: isTicket ? double.infinity : 250,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: colors['accent'],
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      border: pw.Border.all(color: colors['primary']!, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        if (config.showTotalSavings && finalSavings > 0.01) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Ahorro / Descuento:",
                style: pw.TextStyle(fontSize: isTicket ? 8 : 10),
              ),
              pw.Text(
                "- ${AppCurrency.format(finalSavings)}",
                style: pw.TextStyle(
                  fontSize: isTicket ? 8.5 : 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: colors['savings'],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        ],
        if (moraTotalSale > 0.01) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "Recargo por Mora:",
                style: pw.TextStyle(
                  fontSize: isTicket ? 8 : 10,
                  color: colors['debt'],
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "+ ${AppCurrency.format(moraTotalSale)}",
                style: pw.TextStyle(
                  fontSize: isTicket ? 8.5 : 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: colors['debt'],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        ],
        if (config.showTotalGlobal) ...[
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "IMPORTE TOTAL:",
                style: pw.TextStyle(
                  fontSize: isTicket ? 10 : 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                AppCurrency.format(finalTotal),
                style: pw.TextStyle(
                  fontSize: isTicket ? 13 : 16,
                  fontWeight: pw.FontWeight.bold,
                  color: colors['primary'],
                ),
              ),
            ],
          ),
          if (isSale && debt > 0.01) ...[
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Monto Abonado:",
                  style: pw.TextStyle(fontSize: isTicket ? 8 : 10),
                ),
                pw.Text(
                  AppCurrency.format(paidAmount),
                  style: pw.TextStyle(fontSize: isTicket ? 8.5 : 10.5),
                ),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "SALDO PENDIENTE:",
                  style: pw.TextStyle(
                    fontSize: isTicket ? 9 : 11,
                    fontWeight: pw.FontWeight.bold,
                    color: colors['debt'],
                  ),
                ),
                pw.Text(
                  AppCurrency.format(debt),
                  style: pw.TextStyle(
                    fontSize: isTicket ? 11 : 13,
                    fontWeight: pw.FontWeight.bold,
                    color: colors['debt'],
                  ),
                ),
              ],
            ),
          ],
        ],
        if (config.showStatusStamp) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: debt <= 0.01 ? PdfColors.green700 : PdfColors.orange800,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            ),
            child: pw.Text(
              debt <= 0.01 ? "PAGADO COMPLETO" : "SALDO PENDIENTE",
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  pw.Widget? transBox;
  if (showTransDetails && !isTicket) {
    transBox = pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "DETALLE DE PAGO",
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          _buildPdfPaymentRow(
            "Método:",
            saleData['metodo_pago'].toString().toUpperCase(),
            isTicket: false,
          ),
          _buildPdfPaymentRow(
            "Estado:",
            debt <= 0.01 ? 'CANCELADO' : 'CON SALDO',
            isTicket: false,
          ),
          if (saleData['fecha_entrega'] != null)
            _buildPdfPaymentRow(
              "Entrega:",
              AppDateFormatter.formatDate(
                DateTime.parse(saleData['fecha_entrega']),
              ),
              isTicket: false,
            ),
        ],
      ),
    );
  }

  final mainRow = isTicket
      ? totalsBox
      : pw.Row(
          mainAxisAlignment: showTransDetails
              ? pw.MainAxisAlignment.spaceBetween
              : pw.MainAxisAlignment.end,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [if (transBox != null) transBox, totalsBox],
        );

  if (cuotasWidget != null) {
    return pw.Column(children: [mainRow, cuotasWidget]);
  }

  return mainRow;
}

/// Construye el pie de página (cuentas bancarias, notas de validez y créditos legales).
pw.Widget _buildPdfFooter(
  PdfConfig config,
  UserModel? user, {
  required bool isTicket,
  bool isLoan = false,
  bool isCredit = false,
}) {
  final String? effectivePayment = _stripOptionalUnsupportedEmojis(
    (config.customPaymentInfo != null &&
            config.customPaymentInfo!.trim().isNotEmpty)
        ? config.customPaymentInfo!.trim()
        : user?.business?.paymentInfo,
  );
  String? effectiveFooterNote = _stripOptionalUnsupportedEmojis(
    config.footerNote,
  );

  if (isLoan || isCredit) {
    if (effectiveFooterNote == null ||
        effectiveFooterNote.trim().isEmpty ||
        effectiveFooterNote.toLowerCase().contains("válida por") ||
        effectiveFooterNote.toLowerCase().contains("valida por") ||
        effectiveFooterNote.toLowerCase().contains("cotización") ||
        effectiveFooterNote.toLowerCase().contains("cotizacion")) {
      effectiveFooterNote =
          "El pago puntual de cada cuota evita la generación de recargos por mora. Comprobante emitido para control y cobranza.";
    }
  }

  final bool hasPaymentAccounts =
      config.showPaymentAccounts && (effectivePayment?.isNotEmpty ?? false);
  final bool hasFooterNote =
      effectiveFooterNote != null && effectiveFooterNote.trim().isNotEmpty;

  return pw.Column(
    children: [
      if (hasPaymentAccounts || hasFooterNote) ...[
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF5F6F8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (hasPaymentAccounts && effectivePayment != null) ...[
                pw.Text(
                  "Cuentas de Pago / Transferencias:",
                  style: pw.TextStyle(
                    fontSize: isTicket ? 7.5 : 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.Text(
                  effectivePayment,
                  style: pw.TextStyle(
                    fontSize: isTicket ? 7 : 8,
                    color: PdfColors.grey700,
                  ),
                ),
                if (hasFooterNote) pw.SizedBox(height: 3),
              ],
              if (hasFooterNote)
                pw.Text(
                  "Condiciones: $effectiveFooterNote",
                  style: pw.TextStyle(
                    fontSize: isTicket ? 7 : 8,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey800,
                  ),
                ),
            ],
          ),
        ),
      ],
      if (config.layoutTemplate == PdfLayoutTemplate.corporateFramed &&
          !isTicket) ...[
        pw.SizedBox(height: 18),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Container(width: 140, height: 0.8, color: PdfColors.grey700),
                pw.SizedBox(height: 3),
                pw.Text(
                  "Firma y Sello Autorizado",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              children: [
                pw.Container(width: 140, height: 0.8, color: PdfColors.grey700),
                pw.SizedBox(height: 3),
                pw.Text(
                  "Conformidad del Cliente",
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
      ],
      pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "${OwnerLegalIdentity.appCommercialName} • Desarrollado por ${OwnerLegalIdentity.authorFullName}",
            style: pw.TextStyle(
              fontSize: isTicket ? 6.5 : 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            "Gracias por su preferencia",
            style: pw.TextStyle(
              fontSize: isTicket ? 7.5 : 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  );
}
