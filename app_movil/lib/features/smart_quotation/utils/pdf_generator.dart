import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http; 
import 'package:image/image.dart' as img; // Añadido para conversión de imagen B/N

import '../models/smart_quotation_model.dart';
import '../../../models/user_model.dart'; 
import '../models/pdf_config_model.dart'; 

class PdfGenerator {
  
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF1565C0); 
  static const PdfColor _accentColor = PdfColor.fromInt(0xFFE3F2FD);  
  static const PdfColor _textColor = PdfColor.fromInt(0xFF212121);    

  static Map<String, PdfColor> _getThemeColors(PdfTheme theme) {
    switch (theme) {
      case PdfTheme.modern: return {'primary': _primaryColor, 'accent': _accentColor, 'text': _textColor, 'header_bg': _primaryColor, 'header_txt': PdfColors.white, 'savings': PdfColors.green700};
      case PdfTheme.minimal: return {'primary': PdfColors.black, 'accent': PdfColors.grey100, 'text': PdfColors.black, 'header_bg': PdfColors.white, 'header_txt': PdfColors.black, 'savings': PdfColors.black};
      case PdfTheme.classic: return {'primary': PdfColors.black, 'accent': PdfColors.white, 'text': PdfColors.black, 'header_bg': PdfColors.grey200, 'header_txt': PdfColors.black, 'savings': PdfColors.black};
    }
  }

  // MÉTODO NUEVO: Procesar logo con versión _classic o conversión B/N al vuelo
  static Future<pw.ImageProvider?> _processLogo(String url, PdfTheme theme) async {
    try {
      String finalUrl = url;
      
      if (theme == PdfTheme.classic) {
        final int lastDot = url.lastIndexOf('.');
        if (lastDot != -1) {
          finalUrl = "${url.substring(0, lastDot)}_classic${url.substring(lastDot)}";
        }
      }

      var response = await http.get(Uri.parse(finalUrl)).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        if (theme == PdfTheme.classic) {
          final img.Image? decoded = img.decodeImage(response.bodyBytes);
          if (decoded != null) {
            final img.Image grayscale = img.grayscale(decoded);
            return pw.MemoryImage(Uint8List.fromList(img.encodePng(grayscale)));
          }
        }
        return pw.MemoryImage(response.bodyBytes);
      } else if (theme == PdfTheme.classic && finalUrl != url) {
        // Fallback a la imagen original si no encuentra la terminación _classic
        response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final img.Image? decoded = img.decodeImage(response.bodyBytes);
          if (decoded != null) {
            final img.Image grayscale = img.grayscale(decoded);
            return pw.MemoryImage(Uint8List.fromList(img.encodePng(grayscale)));
          }
          return pw.MemoryImage(response.bodyBytes);
        }
      }
    } catch (e) {
      // Manejo silencioso para no romper el PDF si falla la red
    }
    return null;
  }

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

    pw.ImageProvider? logoImage;
    if (config.showBusinessInfo && config.includeLogo && ownerInfo?.business?.logoUrl != null) {
      logoImage = await _processLogo(ownerInfo!.business!.logoUrl!, config.theme);
    }

    Map<int, pw.ImageProvider> productImages = {};
    if (config.showImages) {
      final itemsWithImages = quotation.items.where((i) => i.imageUrl != null && i.imageUrl!.isNotEmpty).toList();
      await Future.wait(itemsWithImages.map((item) async {
        try {
          final response = await http.get(Uri.parse(item.imageUrl!)).timeout(const Duration(seconds: 10)); 
          if (response.statusCode == 200) productImages[item.id] = pw.MemoryImage(response.bodyBytes);
        } catch (_) {}
      }));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            _buildHeader(quotation, ownerInfo, config, logoImage, dateFormat, colors, saleData),
            pw.SizedBox(height: 20),
            _buildDynamicTable(quotation.items, config, currency, productImages, colors),
            pw.SizedBox(height: 15),
            _buildTotalsSection(quotation, config, currency, colors, saleData),
            pw.Spacer(),
            _buildFooter(config),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    SmartQuotationModel q, UserModel? user, PdfConfig config, 
    pw.ImageProvider? logo, DateFormat fmt, Map<String, PdfColor> colors,
    Map<String, dynamic>? saleData
  ) {
    final bizName = user?.business?.commercialName ?? user?.fullName ?? "Mi Negocio";
    final bizRuc = user?.business?.ruc;
    final bizAddress = user?.business?.address;
    final bizPhone = user?.phone;

    final bool isSale = saleData != null;
    final bool isQuickSale = isSale && saleData['origen_venta'] == 'pos_rapido';
    
    final String docTitle = config.documentTitle ?? (isSale ? "COMPROBANTE DE VENTA" : "COTIZACIÓN");
    final String docNumber = isSale ? saleData['id'].toString().padLeft(6, '0') : q.id.toString().padLeft(6, '0');
    final String docDate = isSale && saleData['fecha_venta'] != null ? fmt.format(DateTime.parse(saleData['fecha_venta'])) : fmt.format(DateTime.parse(q.createdAt));
    
    final String defaultClient = isQuickSale ? "Venta de Mostrador" : "Cliente General";
    final String clientNameStr = isSale ? (saleData['cliente_nombre'] ?? defaultClient) : (q.clientName ?? defaultClient);
    
    final bool showExtraInfo = config.showInstitutionInfo;
    
    final String? note = isSale && saleData['notas'] != null && saleData['notas'].toString().isNotEmpty 
        ? saleData['notas'] 
        : (q.notas != null && q.notas!.isNotEmpty ? q.notas : null);

    final headerDetailsColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        if (config.showClientName)
          pw.Text(clientNameStr, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        
        if (showExtraInfo) ...[
          if (note != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text("Nota: $note", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic))
            ),
            
          if (!isQuickSale) ...[
            if (q.institutionName != null && q.institutionName!.isNotEmpty) 
              pw.Text(q.institutionName!, style: const pw.TextStyle(fontSize: 10)),
            if (q.gradeLevel != null && q.gradeLevel!.isNotEmpty) 
              pw.Text(q.gradeLevel!, style: const pw.TextStyle(fontSize: 10)),
          ]
        ]
      ]
    );

    if (config.theme == PdfTheme.modern) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                if (config.showBusinessInfo && config.includeLogo && logo != null)
                  pw.Container(width: 70, height: 70, margin: const pw.EdgeInsets.only(right: 15), child: pw.Image(logo, fit: pw.BoxFit.contain)),
                if (config.showBusinessInfo)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logo == null || !config.includeLogo)
                        pw.Text(bizName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: _primaryColor)),
                      pw.SizedBox(height: 4),
                      if (config.includeShopAddress && bizAddress != null) pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (config.includeOwnerPhone && bizPhone != null) pw.Text("Tel: $bizPhone", style: const pw.TextStyle(fontSize: 10)),
                      if (config.includeShopRuc && bizRuc != null) pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 10)),
                    ]
                  )
              ]
            )
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(docTitle, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
              pw.Text("N° #$docNumber", style: const pw.TextStyle(fontSize: 14)),
              pw.Text(docDate, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 10),
              if (config.showClientName || showExtraInfo)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(color: colors['accent'], borderRadius: pw.BorderRadius.circular(6)),
                  child: headerDetailsColumn,
                )
            ]
          )
        ]
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (config.showBusinessInfo && config.includeLogo && logo != null)
                pw.Container(height: 60, margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Image(logo)),
              if (config.showBusinessInfo) ...[
                pw.Text(bizName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                if (config.includeShopRuc && bizRuc != null) pw.Text("RUC: $bizRuc", style: const pw.TextStyle(fontSize: 11)),
                if (config.includeShopAddress && bizAddress != null) pw.Text(bizAddress, style: const pw.TextStyle(fontSize: 11)),
                if (config.includeOwnerPhone && bizPhone != null) pw.Text("Telf: $bizPhone", style: const pw.TextStyle(fontSize: 11)),
              ]
            ]
          )
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(docTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text("#$docNumber", style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 8),
            headerDetailsColumn,
          ]
        )
      ]
    );
  }

  static pw.Widget _buildDynamicTable(
    List<QuotationItem> items, PdfConfig config, NumberFormat currency,
    Map<int, pw.ImageProvider> imagesMap, Map<String, PdfColor> colors
  ) {
    final headers = <String>['Cant.'];
    final Map<int, pw.TableColumnWidth> colWidths = {0: const pw.FixedColumnWidth(40)};
    int i = 1;

    if (config.showImages) { 
      headers.add('Img'); 
      colWidths[i++] = const pw.FixedColumnWidth(45); 
    }
    
    headers.add('Descripción'); 
    colWidths[i++] = const pw.FlexColumnWidth(4);
    
    if (config.showProductUnit) {
      headers.add('Unid.'); 
      colWidths[i++] = const pw.FlexColumnWidth(1.2); 
    }

    if (config.showProductUnitPrice) {
      headers.add('Unitario'); 
      colWidths[i++] = const pw.FlexColumnWidth(1.4);
    }
    
    if (config.showProductSubtotal) {
      headers.add('Subtotal'); 
      colWidths[i++] = const pw.FlexColumnWidth(1.4);
    }

    PdfColor headerBg = colors['header_bg']!;
    PdfColor headerTxt = colors['header_txt']!;
    pw.Border? border; bool zebra = false;

    switch (config.theme) {
      case PdfTheme.modern: border = const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)); zebra = true; break;
      case PdfTheme.minimal: border = const pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1)); zebra = false; break;
      case PdfTheme.classic: border = pw.TableBorder.all(color: PdfColors.grey400, width: 0.5); zebra = false; break;
    }

    return pw.Table(
      columnWidths: colWidths, border: config.theme == PdfTheme.classic ? pw.TableBorder.all(color: PdfColors.grey600, width: 0.5) : null,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerBg),
          children: headers.map((h) => pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6), alignment: (h == 'Descripción' || h == 'Unid.') ? pw.Alignment.centerLeft : pw.Alignment.centerRight, child: pw.Text(h, style: pw.TextStyle(color: headerTxt, fontWeight: pw.FontWeight.bold, fontSize: 10)))).toList()
        ),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key; final item = entry.value;
          final cells = <pw.Widget>[];
          final bgColor = (zebra && idx % 2 != 0) ? PdfColors.grey50 : PdfColors.white;

          cells.add(pw.Container(alignment: pw.Alignment.center, padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text("${item.quantity}", style: const pw.TextStyle(fontSize: 11))));

          if (config.showImages) {
            final img = imagesMap[item.id];
            cells.add(pw.Container(height: 40, padding: const pw.EdgeInsets.all(2), alignment: pw.Alignment.center, child: img != null ? pw.Image(img, fit: pw.BoxFit.contain) : pw.Container(width: 20, height: 20, decoration: const pw.BoxDecoration(color: PdfColors.grey100))));
          }

          // 🔥 MODIFICADO: Uso directo de displayName en caso de no estar estructurado
          bool isStructured = item.productName != null && item.productName!.isNotEmpty;
          pw.Widget descWidget;
          
          if (isStructured) {
             final String combinedName = "${item.productName!} ${item.specificName ?? ''}".trim();
             descWidget = pw.Column(
               crossAxisAlignment: pw.CrossAxisAlignment.start,
               mainAxisAlignment: pw.MainAxisAlignment.center,
               children: [
                  if (item.brandName != null && item.brandName!.isNotEmpty && item.brandName != "null")
                     pw.Padding(
                       padding: const pw.EdgeInsets.only(bottom: 2),
                       child: pw.Text(item.brandName!.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
                     ),
                  pw.Text(combinedName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
               ]
             );
          } else {
             // 🔥 LEGADO ELIMINADO: Se usa displayName en lugar de productNameSnapshot
             descWidget = pw.Text(item.displayName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold));
          }
          
          cells.add(pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), alignment: pw.Alignment.centerLeft, child: descWidget));

          if (config.showProductUnit) {
            String unitStr = isStructured ? (item.salesUnit ?? "Unid") : "Unid";
            cells.add(pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(unitStr.toUpperCase(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))));
          }

          final hasDiscount = (item.originalUnitPrice - item.unitPriceApplied) > 0.01;

          if (config.showProductUnitPrice) {
            cells.add(pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), alignment: pw.Alignment.centerRight,
              child: config.showProductSavings && hasDiscount
                ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                    pw.Text(currency.format(item.originalUnitPrice), style: pw.TextStyle(fontSize: 9, color: config.theme == PdfTheme.classic ? PdfColors.black : PdfColors.red, decoration: pw.TextDecoration.lineThrough)),
                    pw.Text(currency.format(item.unitPriceApplied), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ])
                : pw.Text(currency.format(item.unitPriceApplied), style: const pw.TextStyle(fontSize: 11))
            ));
          }

          if (config.showProductSubtotal) {
            cells.add(pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8), alignment: pw.Alignment.centerRight, child: pw.Text(currency.format(item.quantity * item.unitPriceApplied), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))));
          }

          return pw.TableRow(decoration: config.theme != PdfTheme.classic ? pw.BoxDecoration(color: bgColor, border: border) : null, children: cells);
        }).toList()
      ]
    );
  }

  static pw.Widget _buildTotalsSection(SmartQuotationModel q, PdfConfig config, NumberFormat currency, Map<String, PdfColor> colors, Map<String, dynamic>? saleData) {
    if (!config.showTotalGlobal && !config.showTransactionDetails) return pw.Container();

    final bool isSale = saleData != null;
    final double finalTotal = isSale ? (saleData['monto_total'] ?? 0.0).toDouble() : q.totalAmount;
    final double finalSavings = isSale ? (saleData['descuento_aplicado'] ?? 0.0).toDouble() : q.totalSavings;
    
    final double paidAmount = isSale ? (saleData['monto_pagado'] ?? 0.0).toDouble() : 0.0;
    double debt = finalTotal - paidAmount;
    if (debt < 0) debt = 0;
    
    final bool showTransDetails = isSale && config.showTransactionDetails;

    String deliveryStatusStr = "";
    if (isSale) {
       if (saleData['estado_entrega'] == 'retenido_por_pago') {
          deliveryStatusStr = debt <= 0 ? 'RETENIDO (POR COORDINACIÓN)' : 'RETENIDO (POR DEUDA)';
       } else if (saleData['estado_entrega'] == 'pendiente_recojo') {
          deliveryStatusStr = 'ENVÍO / RECOJO PROGRAMADO';
       } else {
          deliveryStatusStr = 'ENTREGADO INMEDIATAMENTE';
       }
    }

    return pw.Row(
      mainAxisAlignment: showTransDetails ? pw.MainAxisAlignment.spaceBetween : pw.MainAxisAlignment.end,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        
        if (showTransDetails)
          pw.Container(
            width: 220, padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("DETALLE DE TRANSACCIÓN", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 6),
                _buildPaymentRow("Método:", saleData['metodo_pago'].toString().toUpperCase()),
                _buildPaymentRow("Estado Pago:", saleData['estado_pago'] == 'pagado' ? 'COMPLETO' : 'CRÉDITO'),
                _buildPaymentRow("Entrega:", deliveryStatusStr),
                if (saleData['fecha_entrega'] != null)
                   _buildPaymentRow("Fecha Entrega:", DateFormat('dd/MM/yyyy').format(DateTime.parse(saleData['fecha_entrega']))),
                
                pw.Divider(color: PdfColors.grey300),
                
                if (debt > 0) ...[
                  _buildPaymentRow("Abono Inicial:", currency.format(paidAmount)),
                  _buildPaymentRow("Deuda Restante:", currency.format(debt), isBold: true, valueColor: PdfColors.red700),
                ] else ...[
                  _buildPaymentRow("Abonado:", currency.format(paidAmount), isBold: true),
                ]
              ]
            )
          ),

        if (config.showTotalGlobal || config.showTotalSavings)
          pw.Container(
            width: 240, padding: const pw.EdgeInsets.all(12),
            decoration: config.theme == PdfTheme.classic ? pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)) : pw.BoxDecoration(color: colors['accent'], borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (config.showTotalSavings && finalSavings > 0.01) ...[
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text("Descuento Aplicado:", style: const pw.TextStyle(fontSize: 11)),
                    pw.Text("- ${currency.format(finalSavings)}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: colors['savings'])),
                  ]),
                  if (config.showTotalGlobal)
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Divider(color: PdfColors.grey400)),
                ],
                if (config.showTotalGlobal)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text("IMPORTE TOTAL:", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(currency.format(finalTotal), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: colors['primary'])),
                  ])
              ]
            )
          )
      ]
    );
  }

  static pw.Widget _buildPaymentRow(String label, String value, {bool isBold = false, PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: valueColor ?? PdfColors.black)),
        ]
      )
    );
  }

  static pw.Widget _buildFooter(PdfConfig config) {
    return pw.Column(children: [
      pw.Divider(color: PdfColors.grey400),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Generado por MochilaLista", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text("Gracias por su preferencia", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ]
      )
    ]);
  }
}