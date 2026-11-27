part of '../pdf_generator.dart';

/// Construye la tabla dinámica de productos adaptada para A4 o Ticket 80mm.
pw.Widget _buildPdfDynamicTable(
  List<QuotationItem> items,
  PdfConfig config,
  Map<int, pw.ImageProvider> imagesMap,
  Map<String, PdfColor> colors, {
  required bool isTicket,
}) {
  final bool isCompact =
      config.layoutTemplate == PdfLayoutTemplate.compactWholesale;
  final bool isCatalog =
      config.layoutTemplate == PdfLayoutTemplate.commercialCatalog;
  final bool isCorporate =
      config.layoutTemplate == PdfLayoutTemplate.corporateFramed;

  final headers = <String>['Cant.'];
  final Map<int, pw.TableColumnWidth> colWidths = {
    0: pw.FixedColumnWidth(isTicket ? 24 : (isCompact ? 32 : 38)),
  };
  int i = 1;

  if (config.showImages) {
    headers.add('Foto');
    colWidths[i++] = pw.FixedColumnWidth(
      isTicket ? 24 : (isCatalog ? 48 : (isCompact ? 30 : 40)),
    );
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
    border: isCorporate
        ? pw.TableBorder.all(color: PdfColors.grey300, width: 0.5)
        : null,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: headerBg,
          borderRadius:
              (!isTicket &&
                  config.layoutTemplate == PdfLayoutTemplate.executiveModern)
              ? const pw.BorderRadius.all(pw.Radius.circular(4))
              : null,
        ),
        children: headers
            .map(
              (h) => pw.Container(
                padding: pw.EdgeInsets.symmetric(
                  vertical: isTicket ? 4 : (isCompact ? 4 : 7),
                  horizontal: 4,
                ),
                alignment: (h == 'Descripción' || h == 'Unid.')
                    ? pw.Alignment.centerLeft
                    : pw.Alignment.centerRight,
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    color: headerTxt,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: headerFontSize,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      ...items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final cells = <pw.Widget>[];
        final bgColor = (idx % 2 != 0)
            ? const PdfColor.fromInt(0xFFF8F9FA)
            : PdfColors.white;

        // 1. Cantidad
        cells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: pw.EdgeInsets.symmetric(vertical: cellPaddingV),
            child: pw.Text(
              "${item.quantity}",
              style: pw.TextStyle(fontSize: fontSize),
            ),
          ),
        );

        // 2. Imagen o Avatar Simétrico con Iniciales
        if (config.showImages) {
          final img = imagesMap[item.id];
          final double imgDim = isTicket
              ? 24
              : (isCatalog ? 42 : (isCompact ? 24 : 34));
          cells.add(
            pw.Container(
              height: imgDim,
              padding: const pw.EdgeInsets.all(2),
              alignment: pw.Alignment.center,
              child: img != null
                  ? pw.Image(img, fit: pw.BoxFit.contain)
                  : PdfImageHelper.buildProductAvatar(
                      item.displayNameClean,
                      bgColor: colors['avatar_bg'],
                      textColor: colors['avatar_txt'],
                    ),
            ),
          );
        }

        // 3. Descripción
        pw.Widget descWidget;
        final hasDiscount =
            (item.originalUnitPrice - item.unitPriceApplied) > 0.01;

        if (item.bundleId != null) {
          descWidget = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 1,
                ),
                margin: const pw.EdgeInsets.only(bottom: 1),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.orange800,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  "PACK",
                  style: pw.TextStyle(
                    fontSize: 6,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                item.productName ?? "Paquete",
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          );
        } else {
          descWidget = pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  item.displayNameClean,
                  style: pw.TextStyle(fontSize: fontSize),
                ),
              ),
              if (isCatalog && hasDiscount && !isTicket) ...[
                pw.SizedBox(width: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber800,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    "OFERTA",
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        }
        cells.add(
          pw.Container(
            padding: pw.EdgeInsets.symmetric(
              vertical: cellPaddingV,
              horizontal: 4,
            ),
            alignment: pw.Alignment.centerLeft,
            child: descWidget,
          ),
        );

        // 4. Unidad (solo en A4)
        if (config.showProductUnit && !isTicket) {
          final String unitStr = item.salesUnit ?? "UNID";
          cells.add(
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                vertical: cellPaddingV,
                horizontal: 4,
              ),
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                unitStr.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: isCompact ? 7.5 : 8.5,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          );
        }

        // 5. Unitario (con descuento tachado si aplica)
        if (config.showProductUnitPrice) {
          cells.add(
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                vertical: cellPaddingV,
                horizontal: 4,
              ),
              alignment: pw.Alignment.centerRight,
              child: config.showProductSavings && hasDiscount
                  ? pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          AppCurrency.format(item.originalUnitPrice),
                          style: pw.TextStyle(
                            fontSize: fontSize - 1.5,
                            color: PdfColors.grey600,
                            decoration: pw.TextDecoration.lineThrough,
                          ),
                        ),
                        pw.Text(
                          AppCurrency.format(item.unitPriceApplied),
                          style: pw.TextStyle(
                            fontSize: fontSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : pw.Text(
                      AppCurrency.format(item.unitPriceApplied),
                      style: pw.TextStyle(fontSize: fontSize),
                    ),
            ),
          );
        }

        // 6. Subtotal
        if (config.showProductSubtotal) {
          cells.add(
            pw.Container(
              padding: pw.EdgeInsets.symmetric(
                vertical: cellPaddingV,
                horizontal: 4,
              ),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                AppCurrency.format(item.quantity * item.unitPriceApplied),
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bgColor),
          children: cells,
        );
      }),
    ],
  );
}
