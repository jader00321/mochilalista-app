import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/models/user_model.dart'; 
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart'; 
import 'package:app_movil/features/smart_quotation/utils/pdf_image_helper.dart';

/// 🖨️ MOTOR GENERADOR DE DOCUMENTOS PDF (MULTI-SITUACIÓN Y DUAL-FORMAT A4/TICKET 80mm)
/// Soporta Cotizaciones, Proformas, Boletas/Notas de Venta, Ventas a Crédito y Préstamos.
/// Totalmente libre de glifos no Latin-1 para garantizar cero errores de renderizado.
class PdfGenerator {
  
  static Map<String, PdfColor> _getThemeColors(PdfTheme theme) {
    switch (theme) {
      case PdfTheme.modern:
        return {
          'primary': const PdfColor.fromInt(0xFF1565C0), // Azul Moderno
          'accent': const PdfColor.fromInt(0xFFE3F2FD),
          'text': const PdfColor.fromInt(0xFF212121),
          'header_bg': const PdfColor.fromInt(0xFF1565C0),
          'header_txt': PdfColors.white,
          'savings': PdfColors.green700,
          'debt': PdfColors.red700,
          'avatar_bg': const PdfColor.fromInt(0xFFE3F2FD),
          'avatar_txt': const PdfColor.fromInt(0xFF1565C0),
        };
      case PdfTheme.emerald:
        return {
          'primary': const PdfColor.fromInt(0xFF00796B), // Esmeralda Comercial
          'accent': const PdfColor.fromInt(0xFFE0F2F1),
          'text': const PdfColor.fromInt(0xFF212121),
          'header_bg': const PdfColor.fromInt(0xFF00796B),
          'header_txt': PdfColors.white,
          'savings': PdfColors.teal800,
          'debt': PdfColors.red800,
          'avatar_bg': const PdfColor.fromInt(0xFFE0F2F1),
          'avatar_txt': const PdfColor.fromInt(0xFF00796B),
        };
      case PdfTheme.dark:
        return {
          'primary': const PdfColor.fromInt(0xFF263238), // Ejecutivo Oscuro (Slate)
          'accent': const PdfColor.fromInt(0xFFECEFF1),
          'text': const PdfColor.fromInt(0xFF212121),
          'header_bg': const PdfColor.fromInt(0xFF263238),
          'header_txt': PdfColors.white,
          'savings': PdfColors.green800,
          'debt': PdfColors.red800,
          'avatar_bg': const PdfColor.fromInt(0xFFECEFF1),
          'avatar_txt': const PdfColor.fromInt(0xFF263238),
        };
      case PdfTheme.classic:
        return {
          'primary': PdfColors.black,
          'accent': const PdfColor.fromInt(0xFFF5F5F5),
          'text': PdfColors.black,
          'header_bg': const PdfColor.fromInt(0xFFEEEEEE),
          'header_txt': PdfColors.black,
          'savings': PdfColors.black,
          'debt': PdfColors.black,
          'avatar_bg': const PdfColor.fromInt(0xFFEEEEEE),
          'avatar_txt': PdfColors.black,
        };
      case PdfTheme.minimal:
        return {
          'primary': PdfColors.black,
          'accent': const PdfColor.fromInt(0xFFFAFAFA),
          'text': PdfColors.black,
          'header_bg': PdfColors.white,
          'header_txt': PdfColors.black,
          'savings': PdfColors.black,
          'debt': PdfColors.black,
          'avatar_bg': const PdfColor.fromInt(0xFFF0F0F0),
          'avatar_txt': PdfColors.black,
        };
      case PdfTheme.burgundy:
        return {
          'primary': const PdfColor.fromInt(0xFF880E4F), // Borgoña Elegante
          'accent': const PdfColor.fromInt(0xFFFCE4EC),
          'text': const PdfColor.fromInt(0xFF212121),
          'header_bg': const PdfColor.fromInt(0xFF880E4F),
          'header_txt': PdfColors.white,
          'savings': PdfColors.green800,
          'debt': const PdfColor.fromInt(0xFFC2185B),
          'avatar_bg': const PdfColor.fromInt(0xFFFCE4EC),
          'avatar_txt': const PdfColor.fromInt(0xFF880E4F),
        };
      case PdfTheme.indigo:
        return {
          'primary': const PdfColor.fromInt(0xFF1A237E), // Índigo Real
          'accent': const PdfColor.fromInt(0xFFE8EAF6),
          'text': const PdfColor.fromInt(0xFF212121),
          'header_bg': const PdfColor.fromInt(0xFF1A237E),
          'header_txt': PdfColors.white,
          'savings': PdfColors.teal800,
          'debt': PdfColors.red800,
          'avatar_bg': const PdfColor.fromInt(0xFFE8EAF6),
          'avatar_txt': const PdfColor.fromInt(0xFF1A237E),
        };
    }
  }

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

  /// Sanitiza y limpia el nombre del cliente, eliminando cualquier código interno,
  /// ID de borrador, sufijo (#22-0146, (2), - Manual, - Cotización) o timestamp.
  static String cleanClientDisplayName(String? raw) {
    if (raw == null) return "";
    if (isInternalDraftCode(raw)) return "";
    String clean = raw.trim();
    // 1. Elimina sufijos de códigos numéricos o compuestos (#22-0146, #1234, etc.)
    clean = clean.replaceAll(RegExp(r'\s*#\d+[\w-]*', caseSensitive: false), '');
    // 2. Elimina números o duplicados entre paréntesis (ej. (2), (copia))
    clean = clean.replaceAll(RegExp(r'\s*\(\d+\)', caseSensitive: false), '');
    // 3. Elimina etiquetas de origen de borrador/manual/cotización/pos
    clean = clean.replaceAll(
      RegExp(r'\s*-\s*(?:Manual|Cotizaci[oó]n|Venta|Pedido|Borrador|POS|R[aá]pida).*$', caseSensitive: false), 
      ''
    );
    // 4. Elimina sufijos de timestamp (- 14:30)
    clean = clean.replaceAll(RegExp(r'\s*-\s*\d{1,2}:\d{2}.*$'), '');
    clean = clean.trim();
    return isInternalDraftCode(clean) ? "" : clean;
  }

  /// Genera el documento PDF completo según la configuración y los datos proporcionados
  static Future<Uint8List> generatePdf({
    required SmartQuotationModel quotation,
    required UserModel? ownerInfo,
    required PdfConfig config,
    Map<String, dynamic>? saleData, 
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final colors = _getThemeColors(config.theme);
    final bool isGrayscale = config.theme == PdfTheme.classic;

    // 1. Carga universal y resiliente del logo del negocio (0ms si está en caché)
    pw.ImageProvider? logoImage;
    if (config.showBusinessInfo && config.includeLogo && ownerInfo?.business?.logoUrl != null) {
      logoImage = await PdfImageHelper.resolveImage(
        ownerInfo!.business!.logoUrl!,
        isGrayscale: isGrayscale,
        maxDimension: 300,
      );
    }

    // 2. Carga universal de fotos de productos con redimensionado y caché
    final Map<int, pw.ImageProvider> productImages = {};
    if (config.showImages) {
      final itemsWithImages = quotation.items.where((i) => i.imageUrl != null && i.imageUrl!.trim().isNotEmpty).toList();
      await Future.wait(itemsWithImages.map((item) async {
        final img = await PdfImageHelper.resolveImage(
          item.imageUrl,
          isGrayscale: isGrayscale,
          maxDimension: 120,
        );
        if (img != null) {
          productImages[item.id] = img;
        }
      }));
    }

    final bool isTicket = config.pageSize == PdfPageSize.ticket80;
    final bool isLoan = saleData != null && saleData['origen_venta'] == 'prestamo_personal';

    // 3. Generación Dual: pw.MultiPage (A4) vs pw.Page (Ticket Térmico 80mm)
    if (isTicket) {
      // PRECISIÓN CRÍTICA: pw.Page con rollo térmico 80mm adaptado sin desbordes
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(quotation, ownerInfo, config, logoImage, dateFormat, colors, saleData, isTicket: true),
                pw.SizedBox(height: 10),
                if (!isLoan)
                  _buildDynamicTable(quotation.items, config, currency, productImages, colors, isTicket: true),
                if (isLoan)
                  _buildLoanSection(saleData, config, currency, colors, isTicket: true),
                pw.SizedBox(height: 10),
                _buildTotalsSection(quotation, config, currency, colors, saleData, isTicket: true),
                pw.SizedBox(height: 12),
                _buildFooter(config, ownerInfo, isTicket: true),
              ],
            );
          },
        ),
      );
    } else {
      // Hoja A4 MultiPágina con Estilos Estructurales
      final bool isCompact = config.layoutTemplate == PdfLayoutTemplate.compactWholesale;
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
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                ),
              _buildHeader(quotation, ownerInfo, config, logoImage, dateFormat, colors, saleData, isTicket: false),
              pw.SizedBox(height: isCompact ? 10 : 18),
              if (!isLoan)
                _buildDynamicTable(quotation.items, config, currency, productImages, colors, isTicket: false),
              if (isLoan)
                _buildLoanSection(saleData, config, currency, colors, isTicket: false),
              pw.SizedBox(height: isCompact ? 8 : 14),
              _buildTotalsSection(quotation, config, currency, colors, saleData, isTicket: false),
              pw.Spacer(),
              _buildFooter(config, ownerInfo, isTicket: false),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Construye la cabecera del documento (Logo, datos del negocio, título, fecha y cliente real)
  static pw.Widget _buildHeader(
    SmartQuotationModel q, UserModel? user, PdfConfig config, 
    pw.ImageProvider? logo, DateFormat fmt, Map<String, PdfColor> colors,
    Map<String, dynamic>? saleData, {required bool isTicket}
  ) {
    final bizName = user?.business?.commercialName ?? user?.fullName ?? "Mi Negocio";
    final bizRuc = user?.business?.ruc;
    final bizAddress = user?.business?.address;
    final bizPhone = user?.phone;

    final bool isSale = saleData != null;
    final bool isLoan = isSale && saleData['origen_venta'] == 'prestamo_personal';
    
    final String defaultTitle = isLoan 
        ? "COMPROBANTE DE PRÉSTAMO" 
        : (isSale ? "COMPROBANTE DE PAGO" : "COTIZACIÓN");
    final String docTitle = config.documentTitle ?? defaultTitle;
    final String docNumber = isSale 
        ? (saleData['id'] ?? 0).toString().padLeft(6, '0') 
        : q.id.toString().padLeft(6, '0');
    final String docDate = isSale && saleData['fecha_venta'] != null 
        ? fmt.format(DateTime.parse(saleData['fecha_venta'])) 
        : fmt.format(DateTime.parse(q.createdAt));

    // Resolución limpia del nombre del cliente real (sin códigos internos)
    String? rawClientName = config.customClientName;
    if (rawClientName == null || rawClientName.trim().isEmpty) {
      rawClientName = isSale ? saleData['cliente_nombre'] : q.clientName;
    }

    final String cleanClientName = cleanClientDisplayName(rawClientName);
    final bool hasRealClient = cleanClientName.isNotEmpty;
    final String? clientPhone = isSale ? saleData['cliente_telefono'] : null;

    final bool isQuickSale = isSale && saleData['origen_venta'] == 'pos_rapido';
    final String? note = isSale && saleData['notas'] != null && saleData['notas'].toString().isNotEmpty 
        ? saleData['notas'] 
        : (q.notas != null && q.notas!.isNotEmpty ? q.notas : null);

    // Bloque de datos del cliente
    final clientWidget = pw.Column(
      crossAxisAlignment: isTicket ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
      children: [
        if (config.showClientName && hasRealClient) ...[
          pw.Text("CLIENTE: ${cleanClientName.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isTicket ? 9 : 11)),
          if (clientPhone != null && clientPhone.isNotEmpty)
            pw.Text("Tel: $clientPhone", style: pw.TextStyle(fontSize: isTicket ? 8 : 9, color: PdfColors.grey700)),
        ],
        if (config.showInstitutionInfo) ...[
          if (note != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text("Nota: $note", style: pw.TextStyle(fontSize: isTicket ? 8 : 9, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic)),
            ),
          if (!isQuickSale && !isLoan) ...[
            if (q.institutionName != null && q.institutionName!.isNotEmpty)
              pw.Text(q.institutionName!, style: pw.TextStyle(fontSize: isTicket ? 8 : 9)),
            if (q.gradeLevel != null && q.gradeLevel!.isNotEmpty)
              pw.Text(q.gradeLevel!, style: pw.TextStyle(fontSize: isTicket ? 8 : 9)),
          ]
        ]
      ]
    );

    // Formato Ticket 80mm
    if (isTicket) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (config.showBusinessInfo && config.includeLogo && logo != null)
            pw.Container(
              height: 40,
              margin: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          if (config.showBusinessInfo) ...[
            pw.Text(bizName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: colors['primary']), textAlign: pw.TextAlign.center),
            if (config.includeShopRuc && bizRuc != null) pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 8)),
            if (config.includeShopAddress && bizAddress != null) pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center),
            if (config.includeOwnerPhone && bizPhone != null) pw.Text("Tel: $bizPhone", style: const pw.TextStyle(fontSize: 8)),
          ],
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Text(docTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colors['primary'])),
          pw.Text("N° #$docNumber  |  $docDate", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          if ((config.showClientName && hasRealClient) || config.showInstitutionInfo) ...[
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(color: colors['accent'], borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: clientWidget,
            ),
          ],
        ],
      );
    }

    // Formato Hoja A4 con soporte para plantillas estructurales
    final bool isCorporate = config.layoutTemplate == PdfLayoutTemplate.corporateFramed;

    final logoWidget = (config.showBusinessInfo && config.includeLogo && logo != null)
        ? pw.Container(
            width: 68,
            height: 68,
            margin: const pw.EdgeInsets.only(right: 14),
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(3),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )
        : null;

    final businessContent = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoWidget != null) logoWidget,
        if (config.showBusinessInfo)
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(bizName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15, color: colors['primary'])),
                pw.SizedBox(height: 3),
                if (config.includeShopRuc && bizRuc != null) pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 9)),
                if (config.includeShopAddress && bizAddress != null) pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 9)),
                if (config.includeOwnerPhone && bizPhone != null) pw.Text("Tel: $bizPhone", style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
      ],
    );

    final docHeaderContent = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(docTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: colors['primary'])),
        pw.Text("N° #$docNumber", style: pw.TextStyle(fontSize: 13, color: PdfColors.grey800)),
        pw.Text(docDate, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        if ((config.showClientName && hasRealClient) || config.showInstitutionInfo) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: colors['accent'], 
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: isCorporate ? pw.Border.all(color: colors['primary']!, width: 0.5) : null,
            ),
            child: clientWidget,
          ),
        ],
      ],
    );

    if (isCorporate) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: businessContent,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: colors['primary']!, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: colors['accent'],
              ),
              child: docHeaderContent,
            ),
          ),
        ],
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: businessContent,
        ),
        pw.Expanded(
          flex: 4,
          child: docHeaderContent,
        ),
      ],
    );
  }

  /// Construye la tabla dinámica de productos adaptada para A4 o Ticket 80mm
  static pw.Widget _buildDynamicTable(
    List<QuotationItem> items, PdfConfig config, NumberFormat currency,
    Map<int, pw.ImageProvider> imagesMap, Map<String, PdfColor> colors,
    {required bool isTicket}
  ) {
    final bool isCompact = config.layoutTemplate == PdfLayoutTemplate.compactWholesale;
    final bool isCatalog = config.layoutTemplate == PdfLayoutTemplate.commercialCatalog;
    final bool isCorporate = config.layoutTemplate == PdfLayoutTemplate.corporateFramed;

    final headers = <String>['Cant.'];
    final Map<int, pw.TableColumnWidth> colWidths = {0: pw.FixedColumnWidth(isTicket ? 24 : (isCompact ? 32 : 38))};
    int i = 1;

    if (config.showImages) { 
      headers.add('Foto'); 
      colWidths[i++] = pw.FixedColumnWidth(isTicket ? 24 : (isCatalog ? 48 : (isCompact ? 30 : 40))); 
    }
    
    headers.add('Descripción'); 
    colWidths[i++] = const pw.FlexColumnWidth(4);
    
    if (config.showProductUnit && !isTicket) {
      headers.add('Unid.'); 
      colWidths[i++] = pw.FlexColumnWidth(isCompact ? 1.0 : 1.2); 
    }

    if (config.showProductUnitPrice) {
      headers.add('Unit.'); 
      colWidths[i++] = pw.FlexColumnWidth(isTicket ? 1.6 : 1.4);
    }
    
    if (config.showProductSubtotal) {
      headers.add('Total'); 
      colWidths[i++] = pw.FlexColumnWidth(isTicket ? 1.8 : 1.4);
    }

    final PdfColor headerBg = colors['header_bg']!;
    final PdfColor headerTxt = colors['header_txt']!;
    final double fontSize = isTicket ? 8 : (isCompact ? 8.5 : 10);
    final double headerFontSize = isTicket ? 7.5 : (isCompact ? 8.0 : 9.5);
    final double cellPaddingV = isTicket ? 4 : (isCompact ? 2.5 : 6);

    return pw.Table(
      columnWidths: colWidths,
      border: isCorporate ? pw.TableBorder.all(color: PdfColors.grey300, width: 0.5) : null,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: headerBg,
            borderRadius: (!isTicket && config.layoutTemplate == PdfLayoutTemplate.executiveModern)
                ? const pw.BorderRadius.all(pw.Radius.circular(4))
                : null,
          ),
          children: headers.map((h) => pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: isTicket ? 4 : (isCompact ? 4 : 7), horizontal: 4),
            alignment: (h == 'Descripción' || h == 'Unid.') ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
            child: pw.Text(h, style: pw.TextStyle(color: headerTxt, fontWeight: pw.FontWeight.bold, fontSize: headerFontSize)),
          )).toList(),
        ),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final cells = <pw.Widget>[];
          final bgColor = (idx % 2 != 0) ? const PdfColor.fromInt(0xFFF8F9FA) : PdfColors.white;

          // 1. Cantidad
          cells.add(pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV),
            child: pw.Text("${item.quantity}", style: pw.TextStyle(fontSize: fontSize)),
          ));

          // 2. Imagen o Avatar Simétrico con Iniciales
          if (config.showImages) {
            final img = imagesMap[item.id];
            final double imgDim = isTicket ? 24 : (isCatalog ? 42 : (isCompact ? 24 : 34));
            cells.add(pw.Container(
              height: imgDim,
              padding: const pw.EdgeInsets.all(2),
              alignment: pw.Alignment.center,
              child: img != null 
                  ? pw.Image(img, fit: pw.BoxFit.contain)
                  : PdfImageHelper.buildProductAvatar(
                      item.displayName,
                      bgColor: colors['avatar_bg'],
                      textColor: colors['avatar_txt'],
                    ),
            ));
          }

          // 3. Descripción
          pw.Widget descWidget;
          final hasDiscount = (item.originalUnitPrice - item.unitPriceApplied) > 0.01;
          
          if (item.bundleId != null) {
            descWidget = pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  margin: const pw.EdgeInsets.only(bottom: 1),
                  decoration: const pw.BoxDecoration(color: PdfColors.orange800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
                  child: pw.Text("PACK", style: pw.TextStyle(fontSize: 6, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Text(item.productName ?? "Paquete", style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              ],
            );
          } else {
            descWidget = pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(item.displayName, style: pw.TextStyle(fontSize: fontSize)),
                ),
                if (isCatalog && hasDiscount && !isTicket) ...[
                  pw.SizedBox(width: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: const pw.BoxDecoration(color: PdfColors.amber800, borderRadius: pw.BorderRadius.all(pw.Radius.circular(3))),
                    child: pw.Text("OFERTA", style: pw.TextStyle(fontSize: 6.5, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ],
            );
          }
          cells.add(pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: 4),
            alignment: pw.Alignment.centerLeft,
            child: descWidget,
          ));

          // 4. Unidad (solo en A4 para ahorrar espacio en Ticket)
          if (config.showProductUnit && !isTicket) {
            final String unitStr = item.salesUnit ?? "UNID";
            cells.add(pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: 4),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(unitStr.toUpperCase(), style: pw.TextStyle(fontSize: isCompact ? 7.5 : 8.5, color: PdfColors.grey700)),
            ));
          }

          // 5. Unitario (con descuento tachado si aplica)
          if (config.showProductUnitPrice) {
            cells.add(pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: 4),
              alignment: pw.Alignment.centerRight,
              child: config.showProductSavings && hasDiscount
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(currency.format(item.originalUnitPrice), style: pw.TextStyle(fontSize: fontSize - 1.5, color: PdfColors.grey600, decoration: pw.TextDecoration.lineThrough)),
                        pw.Text(currency.format(item.unitPriceApplied), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                      ],
                    )
                  : pw.Text(currency.format(item.unitPriceApplied), style: pw.TextStyle(fontSize: fontSize)),
            ));
          }

          // 6. Subtotal
          if (config.showProductSubtotal) {
            cells.add(pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV, horizontal: 4),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(currency.format(item.quantity * item.unitPriceApplied), style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
            ));
          }

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bgColor),
            children: cells,
          );
        }),
      ],
    );
  }

  /// Construye la sección específica de préstamos personales
  static pw.Widget _buildLoanSection(
    Map<String, dynamic>? saleData, PdfConfig config, NumberFormat currency,
    Map<String, PdfColor> colors, {required bool isTicket}
  ) {
    if (saleData == null) return pw.Container();
    final double capital = (saleData['monto_total'] ?? 0.0).toDouble();
    final double interes = (saleData['monto_interes'] ?? 0.0).toDouble();
    final double total = capital + interes;
    final double abonado = (saleData['monto_pagado'] ?? 0.0).toDouble();
    final double saldo = total - abonado > 0 ? total - abonado : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: colors['accent'],
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("RESUMEN DE PRÉSTAMO", style: pw.TextStyle(fontSize: isTicket ? 9 : 11, fontWeight: pw.FontWeight.bold, color: colors['primary'])),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          _buildPaymentRow("Capital Prestado:", currency.format(capital), isTicket: isTicket),
          if (interes > 0)
            _buildPaymentRow("Interés Acordado:", "+ ${currency.format(interes)}", isTicket: isTicket),
          _buildPaymentRow("Total a Devolver:", currency.format(total), isBold: true, isTicket: isTicket),
          _buildPaymentRow("Monto Abonado:", currency.format(abonado), isTicket: isTicket),
          _buildPaymentRow("Saldo Pendiente:", currency.format(saldo), isBold: true, valueColor: saldo > 0 ? colors['debt'] : colors['savings'], isTicket: isTicket),
        ],
      ),
    );
  }

  /// Construye los totales financieros con verdad contable estricta
  static pw.Widget _buildTotalsSection(
    SmartQuotationModel q, PdfConfig config, NumberFormat currency,
    Map<String, PdfColor> colors, Map<String, dynamic>? saleData,
    {required bool isTicket}
  ) {
    if (!config.showTotalGlobal && !config.showTransactionDetails) return pw.Container();

    final bool isSale = saleData != null;
    final double finalTotal = isSale ? (saleData['monto_total'] ?? 0.0).toDouble() : q.totalAmount;
    final double finalSavings = isSale ? (saleData['descuento_aplicado'] ?? 0.0).toDouble() : q.totalSavings;
    final double paidAmount = isSale ? (saleData['monto_pagado'] ?? 0.0).toDouble() : 0.0;
    final double debt = finalTotal - paidAmount > 0 ? finalTotal - paidAmount : 0.0;
    final bool showTransDetails = isSale && config.showTransactionDetails;

    // Caja de totales principales
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
                pw.Text("Ahorro / Descuento:", style: pw.TextStyle(fontSize: isTicket ? 8 : 10)),
                pw.Text("- ${currency.format(finalSavings)}", style: pw.TextStyle(fontSize: isTicket ? 8.5 : 10.5, fontWeight: pw.FontWeight.bold, color: colors['savings'])),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          ],
          if (config.showTotalGlobal) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("IMPORTE TOTAL:", style: pw.TextStyle(fontSize: isTicket ? 10 : 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(currency.format(finalTotal), style: pw.TextStyle(fontSize: isTicket ? 13 : 16, fontWeight: pw.FontWeight.bold, color: colors['primary'])),
              ],
            ),
            if (isSale && debt > 0.01) ...[
              pw.SizedBox(height: 4),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Monto Abonado:", style: pw.TextStyle(fontSize: isTicket ? 8 : 10)),
                  pw.Text(currency.format(paidAmount), style: pw.TextStyle(fontSize: isTicket ? 8.5 : 10.5)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("SALDO PENDIENTE:", style: pw.TextStyle(fontSize: isTicket ? 9 : 11, fontWeight: pw.FontWeight.bold, color: colors['debt'])),
                  pw.Text(currency.format(debt), style: pw.TextStyle(fontSize: isTicket ? 11 : 13, fontWeight: pw.FontWeight.bold, color: colors['debt'])),
                ],
              ),
            ]
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
                style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );

    // Detalle de pago si es venta
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
            pw.Text("DETALLE DE PAGO", style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            _buildPaymentRow("Método:", saleData['metodo_pago'].toString().toUpperCase(), isTicket: false),
            _buildPaymentRow("Estado:", debt <= 0.01 ? 'CANCELADO' : 'CON SALDO', isTicket: false),
            if (saleData['fecha_entrega'] != null)
              _buildPaymentRow("Entrega:", DateFormat('dd/MM/yyyy').format(DateTime.parse(saleData['fecha_entrega'])), isTicket: false),
          ],
        ),
      );
    }

    final mainRow = isTicket
        ? totalsBox
        : pw.Row(
            mainAxisAlignment: showTransDetails ? pw.MainAxisAlignment.spaceBetween : pw.MainAxisAlignment.end,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (transBox != null) transBox,
              totalsBox,
            ],
          );

    // Cronograma de cuotas si existen
    final List<dynamic>? cuotasRaw = isSale ? saleData['cuotas'] : null;
    if (config.showInstallments && cuotasRaw != null && cuotasRaw.isNotEmpty) {
      final cuotasWidget = pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("PLAN DE CUOTAS (${cuotasRaw.length} cuotas)", style: pw.TextStyle(fontSize: isTicket ? 8 : 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.Divider(color: PdfColors.grey300, thickness: 0.5),
            ...cuotasRaw.map((c) {
              final bool pagado = c['estado'] == 'pagado';
              final String date = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['fecha_vencimiento']));
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Cuota ${c['numero_cuota']}: ${currency.format(c['monto'])}", style: pw.TextStyle(fontSize: isTicket ? 7.5 : 9)),
                    pw.Text("Vence: $date", style: pw.TextStyle(fontSize: isTicket ? 7.5 : 9, color: PdfColors.grey700)),
                    pw.Text(pagado ? "PAGADO" : "PENDIENTE", style: pw.TextStyle(fontSize: isTicket ? 7.5 : 9, fontWeight: pw.FontWeight.bold, color: pagado ? PdfColors.green700 : PdfColors.orange700)),
                  ],
                ),
              );
            }),
          ],
        ),
      );

      return pw.Column(
        children: [
          mainRow,
          cuotasWidget,
        ],
      );
    }

    return mainRow;
  }

  static pw.Widget _buildPaymentRow(String label, String value, {bool isBold = false, PdfColor? valueColor, required bool isTicket}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: isTicket ? 7.5 : 9, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: isTicket ? 7.5 : 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: valueColor ?? PdfColors.black)),
        ],
      ),
    );
  }

  /// Construye el pie de página (cuentas bancarias Yape/Plin, notas de validez y agradecimiento)
  static pw.Widget _buildFooter(PdfConfig config, UserModel? user, {required bool isTicket}) {
    final bool hasPaymentAccounts = config.showPaymentAccounts && (user?.business?.paymentInfo?.isNotEmpty ?? false);
    final bool hasFooterNote = config.footerNote != null && config.footerNote!.trim().isNotEmpty;

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
                if (hasPaymentAccounts) ...[
                  pw.Text("Cuentas de Pago / Transferencias:", style: pw.TextStyle(fontSize: isTicket ? 7.5 : 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                  pw.Text(user!.business!.paymentInfo!, style: pw.TextStyle(fontSize: isTicket ? 7 : 8, color: PdfColors.grey700)),
                  if (hasFooterNote) pw.SizedBox(height: 3),
                ],
                if (hasFooterNote)
                  pw.Text("Condiciones: ${config.footerNote!}", style: pw.TextStyle(fontSize: isTicket ? 7 : 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800)),
              ],
            ),
          ),
        ],
        if (config.layoutTemplate == PdfLayoutTemplate.corporateFramed && !isTicket) ...[
          pw.SizedBox(height: 18),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 0.8, color: PdfColors.grey700),
                  pw.SizedBox(height: 3),
                  pw.Text("Firma y Sello Autorizado", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Container(width: 140, height: 0.8, color: PdfColors.grey700),
                  pw.SizedBox(height: 3),
                  pw.Text("Conformidad del Cliente", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
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
            pw.Text("Generado por MochilaLista", style: pw.TextStyle(fontSize: isTicket ? 7 : 8.5, color: PdfColors.grey600)),
            pw.Text("Gracias por su preferencia", style: pw.TextStyle(fontSize: isTicket ? 8 : 9.5, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}