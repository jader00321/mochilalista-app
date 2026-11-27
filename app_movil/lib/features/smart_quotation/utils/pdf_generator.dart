import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_image_helper.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/cuota_date_helper.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:printing/printing.dart';

part 'pdf/pdf_theme_and_sanitizers.dart';
part 'pdf/pdf_header_builder.dart';
part 'pdf/pdf_table_builder.dart';
part 'pdf/pdf_loan_and_installments_builder.dart';
part 'pdf/pdf_totals_and_footer_builder.dart';

/// MOTOR GENERADOR DE DOCUMENTOS PDF (MULTI-SITUACIÓN Y DUAL-FORMAT A4/TICKET 80mm)
/// Soporta Cotizaciones, Proformas, Boletas/Notas de Venta, Ventas a Crédito y Préstamos.
class PdfGenerator {
  static pw.Font? _cachedRobotoRegular;
  static pw.Font? _cachedRobotoBold;

  /// Determina si un texto corresponde a un código autogenerado del sistema
  /// para evitar que se renderice como nombre de cliente.
  static bool isInternalDraftCode(String? text) {
    if (text == null) return true;
    final clean = text.trim();
    if (clean.isEmpty || clean == 'null') return true;

    final lower = clean.toLowerCase();
    if (lower == 'cliente general' ||
        lower == 'sin cliente' ||
        lower == 'venta de mostrador' ||
        lower == 'venta rapida' ||
        lower == 'venta rápida' ||
        lower == 'borrador' ||
        lower == 'nota de venta' ||
        lower == 'proforma' ||
        lower == 'cotizacion' ||
        lower == 'cotización' ||
        lower == 'pedido' ||
        lower == 'comprobante' ||
        lower == 'boleta' ||
        lower == 'boleta de venta' ||
        lower == 'factura') {
      return true;
    }

    if (lower.startsWith('cotizacion manual #') ||
        lower.startsWith('cotización manual #') ||
        lower.startsWith('cotizacion #') ||
        lower.startsWith('cotización #') ||
        lower.startsWith('venta #') ||
        lower.startsWith('nota de venta #') ||
        lower.startsWith('nota de venta') ||
        lower.startsWith('borrador #') ||
        lower.startsWith('pedido manual #')) {
      return true;
    }

    return false;
  }

  /// Sanitiza y limpia el nombre del cliente, eliminando códigos internos y sufijos.
  static String cleanClientDisplayName(String? raw) {
    if (raw == null) return "";
    if (isInternalDraftCode(raw)) return "";
    String clean = raw.trim();
    clean = clean.replaceAll(
      RegExp(r'\s*#\d+[\w-]*', caseSensitive: false),
      '',
    );
    clean = clean.replaceAll(RegExp(r'\s*\(\d+\)', caseSensitive: false), '');
    clean = clean.replaceAll(
      RegExp(
        r'\s*-\s*(?:Manual|Cotizaci[oó]n|Venta|Pedido|Borrador|POS|R[aá]pida).*$',
        caseSensitive: false,
      ),
      '',
    );
    clean = clean.replaceAll(RegExp(r'\s*-\s*\d{1,2}:\d{2}.*$'), '');
    clean = clean.trim();
    return isInternalDraftCode(clean) ? "" : clean;
  }

  /// Normaliza caracteres descompuestos (NFD como E + \u0301) a NFC.
  static String normalizeSpanishText(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('E\u0301', 'É')
        .replaceAll('e\u0301', 'é')
        .replaceAll('A\u0301', 'Á')
        .replaceAll('a\u0301', 'á')
        .replaceAll('I\u0301', 'Í')
        .replaceAll('i\u0301', 'í')
        .replaceAll('O\u0301', 'Ó')
        .replaceAll('o\u0301', 'ó')
        .replaceAll('U\u0301', 'Ú')
        .replaceAll('u\u0301', 'ú')
        .replaceAll('N\u0303', 'Ñ')
        .replaceAll('n\u0303', 'ñ')
        .replaceAll('\u0301', '')
        .replaceAll('\u0300', '')
        .replaceAll('\u0303', '');
  }

  /// Elimina emojis y símbolos no soportados por fuentes PDF estándar (Latin-1).
  static String stripUnsupportedEmojis(String text) {
    if (text.isEmpty) return text;
    final normalized = normalizeSpanishText(text);
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1FAFF}'
      r'\u{1F000}-\u{1F2FF}'
      r'\u{2600}-\u{27BF}'
      r'\u{2300}-\u{23FF}'
      r'\u{2B50}-\u{2B55}'
      r'\u{FE00}-\u{FE0F}'
      r'\u{200D}'
      r']+',
      unicode: true,
    );
    String cleaned = normalized.replaceAll(emojiRegex, '');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return cleaned.trim();
  }

  /// Genera el documento PDF completo según la configuración y los datos proporcionados.
  static Future<Uint8List> generatePdf({
    required SmartQuotationModel quotation,
    required UserModel? ownerInfo,
    required PdfConfig config,
    Map<String, dynamic>? saleData,
  }) async {
    pw.ThemeData? docTheme;
    if (_cachedRobotoRegular != null && _cachedRobotoBold != null) {
      docTheme = pw.ThemeData.withFont(
        base: _cachedRobotoRegular!,
        bold: _cachedRobotoBold!,
      );
    } else {
      try {
        final baseFont = await PdfGoogleFonts.robotoRegular().timeout(
          const Duration(milliseconds: 300),
        );
        final boldFont = await PdfGoogleFonts.robotoBold().timeout(
          const Duration(milliseconds: 300),
        );
        _cachedRobotoRegular = baseFont;
        _cachedRobotoBold = boldFont;
        docTheme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);
      } catch (_) {
        // Fallback transparente a fuentes integradas si no hay acceso de red o en tests
      }
    }

    final pdf = pw.Document(theme: docTheme);
    final colors = _getPdfThemeColors(config.theme);
    final bool isGrayscale = config.theme == PdfTheme.classic;

    pw.ImageProvider? logoImage;
    if (config.showBusinessInfo &&
        config.includeLogo &&
        ownerInfo?.business?.logoUrl != null) {
      logoImage = await PdfImageHelper.resolveImage(
        ownerInfo!.business!.logoUrl!,
        isGrayscale: isGrayscale,
        maxDimension: 300,
      );
    }

    final Map<int, pw.ImageProvider> productImages = {};
    if (config.showImages) {
      final itemsWithImages = quotation.items
          .where((i) => i.imageUrl != null && i.imageUrl!.trim().isNotEmpty)
          .toList();
      await Future.wait(
        itemsWithImages.map((item) async {
          final img = await PdfImageHelper.resolveImage(
            item.imageUrl,
            isGrayscale: isGrayscale,
            maxDimension: 120,
          );
          if (img != null) {
            productImages[item.id] = img;
          }
        }),
      );
    }

    final bool isTicket = config.pageSize == PdfPageSize.ticket80;
    final bool isSale = saleData != null;
    final bool isLoan =
        isSale && saleData['origen_venta'] == 'prestamo_personal';
    final bool isCredit =
        isSale &&
        !isLoan &&
        (saleData['estado_pago'] == 'pendiente' ||
            (saleData['cuotas'] != null &&
                (saleData['cuotas'] as List).isNotEmpty));

    if (isTicket) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfHeader(
                  quotation,
                  ownerInfo,
                  config,
                  logoImage,
                  colors,
                  saleData,
                  isTicket: true,
                ),
                pw.SizedBox(height: 10),
                if (!isLoan) ...[
                  _buildPdfDynamicTable(
                    quotation.items,
                    config,
                    productImages,
                    colors,
                    isTicket: true,
                  ),
                  pw.SizedBox(height: 10),
                ],
                if (isLoan) ...[
                  _buildPdfLoanSection(
                    saleData,
                    config,
                    colors,
                    isTicket: true,
                  ),
                  if (config.showInstallments &&
                      saleData['cuotas'] != null &&
                      (saleData['cuotas'] as List).isNotEmpty)
                    pw.SizedBox(height: 10),
                ],
                _buildPdfTotalsSection(
                  quotation,
                  config,
                  colors,
                  saleData,
                  isTicket: true,
                ),
                pw.SizedBox(height: 12),
                _buildPdfFooter(
                  config,
                  ownerInfo,
                  isTicket: true,
                  isLoan: isLoan,
                  isCredit: isCredit,
                ),
              ],
            );
          },
        ),
      );
    } else {
      final bool isCompact =
          config.layoutTemplate == PdfLayoutTemplate.compactWholesale;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: isCompact
              ? const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 20)
              : const pw.EdgeInsets.all(30),
          build: (pw.Context context) {
            return [
              if (config.layoutTemplate == PdfLayoutTemplate.executiveModern)
                pw.Container(
                  height: 4,
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  decoration: pw.BoxDecoration(
                    color: colors['primary'],
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                ),
              _buildPdfHeader(
                quotation,
                ownerInfo,
                config,
                logoImage,
                colors,
                saleData,
                isTicket: false,
              ),
              pw.SizedBox(height: isCompact ? 10 : 18),
              if (!isLoan) ...[
                _buildPdfDynamicTable(
                  quotation.items,
                  config,
                  productImages,
                  colors,
                  isTicket: false,
                ),
                pw.SizedBox(height: isCompact ? 8 : 14),
              ],
              if (isLoan) ...[
                _buildPdfLoanSection(saleData, config, colors, isTicket: false),
                if (config.showInstallments &&
                    saleData['cuotas'] != null &&
                    (saleData['cuotas'] as List).isNotEmpty)
                  pw.SizedBox(height: isCompact ? 8 : 14),
              ],
              _buildPdfTotalsSection(
                quotation,
                config,
                colors,
                saleData,
                isTicket: false,
              ),
              pw.Spacer(),
              _buildPdfFooter(
                config,
                ownerInfo,
                isTicket: false,
                isLoan: isLoan,
                isCredit: isCredit,
              ),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }
}
