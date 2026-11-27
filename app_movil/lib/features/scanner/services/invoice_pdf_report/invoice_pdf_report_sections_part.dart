part of '../invoice_pdf_report_service.dart';

class _InvoicePdfSections {
  _InvoicePdfSections._();

  static pw.Widget buildPageHeader({
    required pw.Context context,
    required InvoiceModel invoice,
    String? providerName,
  }) {
    if (context.pageNumber <= 1) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: InvoicePdfReportService._borderColor,
            width: 0.8,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Factura #${invoice.displayId} - Auditoría de Extracción',
            style: pw.TextStyle(
              color: InvoicePdfReportService._secondaryColor,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            providerName ?? 'Sin proveedor',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildPageFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: InvoicePdfReportService._borderColor,
            width: 0.8,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MochilaLista App - Reporte de Auditoría Digital - Local-First Security',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              color: InvoicePdfReportService._secondaryColor,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildDocumentHeader({
    required InvoiceModel invoice,
    UserModel? currentUser,
  }) {
    final String businessName =
        currentUser?.business?.commercialName.trim().isNotEmpty == true
        ? currentUser!.business!.commercialName
        : 'MOCHILALISTA GESTIÓN COMERCIAL';

    PdfColor statusBg;
    PdfColor statusFg;
    final String statusUpper = invoice.estado.toUpperCase();

    switch (invoice.estado.toLowerCase()) {
      case 'completado':
        statusBg = const PdfColor.fromInt(0xFFDCFCE7);
        statusFg = InvoicePdfReportService._accentGreen;
        break;
      case 'revision':
        statusBg = const PdfColor.fromInt(0xFFFFEDD5);
        statusFg = InvoicePdfReportService._accentOrange;
        break;
      default:
        statusBg = const PdfColor.fromInt(0xFFDBEAFE);
        statusFg = InvoicePdfReportService._accentBlue;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: InvoicePdfReportService._primaryColor,
            width: 2,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(
                  color: InvoicePdfReportService._primaryColor,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'REPORTE DE FACTURA ESCANEADA',
                style: pw.TextStyle(
                  color: InvoicePdfReportService._secondaryColor,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Auditoría y conciliación financiera de comprobante de compra',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: InvoicePdfReportService._primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'FACTURA #${invoice.displayId}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: pw.BoxDecoration(
                  color: statusBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: statusFg, width: 0.8),
                ),
                child: pw.Text(
                  statusUpper,
                  style: pw.TextStyle(
                    color: statusFg,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget buildMetadataBlock({
    String? providerName,
    String? providerRuc,
    required String pdfCreationTimeStr,
    required String scanDateStr,
    required String emissionDateStr,
    required bool isManualInvoice,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: InvoicePdfReportService._tableZebra,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: InvoicePdfReportService._borderColor,
          width: 0.8,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaField(
                  label: 'PROVEEDOR VINCULADO',
                  value: providerName?.trim().isNotEmpty == true
                      ? providerName!
                      : 'Sin proveedor asignado',
                  isBold: true,
                  valueColor: InvoicePdfReportService._primaryColor,
                ),
                if (providerRuc != null && providerRuc.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  _buildMetaField(label: 'RUC PROVEEDOR', value: providerRuc),
                ],
                pw.SizedBox(height: 6),
                _buildMetaField(
                  label: 'TIPO DE COMPROBANTE',
                  value: isManualInvoice
                      ? 'Registro Manual en Sistema'
                      : 'Escaneado con Inteligencia Artificial (IA)',
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaField(
                  label: 'FECHA DE EMISIÓN (FÍSICA)',
                  value: emissionDateStr,
                  isBold: true,
                ),
                pw.SizedBox(height: 4),
                _buildMetaField(
                  label: 'FECHA DE ESCANEO CON IA',
                  value: scanDateStr,
                ),
                pw.SizedBox(height: 4),
                _buildMetaField(
                  label: 'GENERACIÓN DE ESTE REPORTE',
                  value: pdfCreationTimeStr,
                  valueColor: PdfColors.grey700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaField({
    required String label,
    required String value,
    bool isBold = false,
    PdfColor? valueColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey600,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? InvoicePdfReportService._secondaryColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget buildFinancialSummaryCards({
    required InvoiceModel invoice,
    required int totalItemsCount,
    required double totalCalculado,
  }) {
    final double montoTotal = invoice.montoTotalFactura ?? totalCalculado;

    return pw.Row(
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: InvoicePdfReportService._primaryLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(
                color: InvoicePdfReportService._primaryColor,
                width: 1,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MONTO TOTAL FACTURADO',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: InvoicePdfReportService._primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  AppCurrency.format(montoTotal),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: InvoicePdfReportService._primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Monto fiscal consignado en comprobante',
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 3,
          child: _buildKpiSummaryBox(
            label: 'TOTAL ÍTEMS',
            value: '$totalItemsCount',
            valueFontSize: 16,
            subtitle: 'Lotes detectados',
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 3,
          child: _buildKpiSummaryBox(
            label: 'SUMA CALCULADA',
            value: AppCurrency.format(totalCalculado),
            valueFontSize: 14,
            subtitle: 'Suma de ítems extraídos',
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiSummaryBox({
    required String label,
    required String value,
    required double valueFontSize,
    required String subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: pw.BoxDecoration(
        color: InvoicePdfReportService._tableZebra,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: InvoicePdfReportService._borderColor,
          width: 0.8,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: valueFontSize,
              fontWeight: pw.FontWeight.bold,
              color: InvoicePdfReportService._secondaryColor,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildAuditSectionTitle(int totalItemsCount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 14,
              decoration: pw.BoxDecoration(
                color: InvoicePdfReportService._primaryColor,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(
              'AUDITORÍA DE PRODUCTOS EXTRAÍDOS',
              style: pw.TextStyle(
                color: InvoicePdfReportService._secondaryColor,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: pw.BoxDecoration(
            color: InvoicePdfReportService._primaryLight,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: InvoicePdfReportService._primaryColor,
              width: 0.6,
            ),
          ),
          child: pw.Text(
            '$totalItemsCount productos auditados',
            style: pw.TextStyle(
              color: InvoicePdfReportService._primaryColor,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget buildTechnicalAuditNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF1F5F9),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: InvoicePdfReportService._borderColor,
          width: 0.6,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NOTA: ',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: InvoicePdfReportService._primaryColor,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              'Este reporte digital fue generado automáticamente por MochilaLista a partir del comprobante físico escaneado con IA. Los costos unitarios reales incluyen la distribución exacta del precio por unidad de empaque y volumen de lote.',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
