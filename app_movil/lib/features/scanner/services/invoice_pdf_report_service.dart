import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';

part 'invoice_pdf_report/invoice_pdf_report_sections_part.dart';
part 'invoice_pdf_report/invoice_pdf_report_tables_part.dart';

/// Motor de generación de reportes PDF profesionales de facturas escaneadas.
class InvoicePdfReportService {
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF004D40);
  static const PdfColor _primaryLight = PdfColor.fromInt(0xFFE0F2F1);
  static const PdfColor _secondaryColor = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor _accentGreen = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _accentOrange = PdfColor.fromInt(0xFFC2410C);
  static const PdfColor _accentBlue = PdfColor.fromInt(0xFF1D4ED8);
  static const PdfColor _tableZebra = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFCBD5E1);

  /// Genera los bytes del documento PDF y lo guarda en la carpeta Downloads.
  static Future<File> generateAndSavePdfReport({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) async {
    final pdfBytes = await generatePdfBytes(
      invoice: invoice,
      providerName: providerName,
      providerRuc: providerRuc,
      currentUser: currentUser,
      linkedPresentations: linkedPresentations,
    );

    final provSanitized = InvoiceFileService.sanitizeFileName(
      providerName ?? 'PROVEEDOR',
    );
    final dateSuffix = AppDateFormatter.fileTimestamp.format(DateTime.now());
    final fileName =
        'Factura_${invoice.displayId}_Reporte_${provSanitized}_$dateSuffix.pdf';

    return await InvoiceFileService.saveBytesToDownloads(
      bytes: pdfBytes,
      fileName: fileName,
    );
  }

  /// Alias amigable para [generatePdfBytes].
  static Future<Uint8List> buildExecutivePdf({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) => generatePdfBytes(
    invoice: invoice,
    providerName: providerName,
    providerRuc: providerRuc,
    currentUser: currentUser,
    linkedPresentations: linkedPresentations,
  );

  /// Construye la estructura completa del PDF y retorna los bytes generados.
  static Future<Uint8List> generatePdfBytes({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) async {
    final pdf = pw.Document(
      title: 'Factura #${invoice.displayId} - Reporte de Auditoría',
      author: 'MochilaLista App',
    );

    final now = DateTime.now();
    final pdfCreationTimeStr = AppDateFormatter.ddMMyyyyHhmmsA.format(now);
    final scanDateStr = AppDateFormatter.ddMMMyyyyHhmma.format(
      invoice.fechaCarga.toLocal(),
    );
    final emissionDateStr = invoice.fechaEmision != null
        ? AppDateFormatter.ddMMyyyy.format(invoice.fechaEmision!)
        : 'No especificada en comprobante';

    List<dynamic> rawItems = [];
    if (invoice.datosCrudosIaJson != null &&
        invoice.datosCrudosIaJson!['items'] != null) {
      rawItems = invoice.datosCrudosIaJson!['items'];
    }

    final bool isManualInvoice =
        rawItems.isEmpty && linkedPresentations.isNotEmpty;
    final int totalItemsCount = isManualInvoice
        ? linkedPresentations.length
        : (invoice.cantidadItemsExtraidos ?? rawItems.length);

    double totalCalculado = 0.0;
    if (!isManualInvoice) {
      for (final it in rawItems) {
        final pago =
            num.tryParse(
              it['total_pago_lote']?.toString() ?? '0',
            )?.toDouble() ??
            0.0;
        totalCalculado += pago;
      }
    } else {
      for (final pres in linkedPresentations) {
        final pCosto = (pres['precio_costo'] as num?)?.toDouble() ?? 0.0;
        final stock = (pres['cantidad_stock'] as num?)?.toDouble() ?? 1.0;
        totalCalculado += (pCosto * stock);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (pw.Context context) => _InvoicePdfSections.buildPageHeader(
          context: context,
          invoice: invoice,
          providerName: providerName,
        ),
        footer: (pw.Context context) =>
            _InvoicePdfSections.buildPageFooter(context),
        build: (pw.Context context) {
          return [
            _InvoicePdfSections.buildDocumentHeader(
              invoice: invoice,
              currentUser: currentUser,
            ),
            pw.SizedBox(height: 14),
            _InvoicePdfSections.buildMetadataBlock(
              providerName: providerName,
              providerRuc: providerRuc,
              pdfCreationTimeStr: pdfCreationTimeStr,
              scanDateStr: scanDateStr,
              emissionDateStr: emissionDateStr,
              isManualInvoice: isManualInvoice,
            ),
            pw.SizedBox(height: 14),
            _InvoicePdfSections.buildFinancialSummaryCards(
              invoice: invoice,
              totalItemsCount: totalItemsCount,
              totalCalculado: totalCalculado,
            ),
            pw.SizedBox(height: 16),
            _InvoicePdfSections.buildAuditSectionTitle(totalItemsCount),
            pw.SizedBox(height: 8),
            if (isManualInvoice)
              _InvoicePdfTables.buildManualItemsTable(linkedPresentations)
            else if (rawItems.isNotEmpty)
              _InvoicePdfTables.buildExtractedItemsTable(rawItems)
            else
              _InvoicePdfTables.buildEmptyTablePlaceholder(),
            pw.SizedBox(height: 14),
            _InvoicePdfSections.buildTechnicalAuditNote(),
          ];
        },
      ),
    );

    return await pdf.save();
  }
}
