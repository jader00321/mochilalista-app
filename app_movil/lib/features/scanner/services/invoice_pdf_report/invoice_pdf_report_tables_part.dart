part of '../invoice_pdf_report_service.dart';

class _InvoicePdfTables {
  _InvoicePdfTables._();

  static pw.Widget buildExtractedItemsTable(List<dynamic> items) {
    double totalAcumulado = 0.0;

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: InvoicePdfReportService._primaryColor,
        ),
        children: [
          _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('DESCRIPCIÓN / PRODUCTO VINCULADO', isHeader: true),
          _buildTableCell(
            'COMPRA (UMP)',
            isHeader: true,
            align: pw.TextAlign.center,
          ),
          _buildTableCell(
            'COSTO UNIT.',
            isHeader: true,
            align: pw.TextAlign.right,
          ),
          _buildTableCell(
            'SUBTOTAL',
            isHeader: true,
            align: pw.TextAlign.right,
          ),
        ],
      ),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final double totalPago =
          num.tryParse(
            item['total_pago_lote']?.toString() ?? '0',
          )?.toDouble() ??
          0.0;
      final double cantidadUmp =
          num.tryParse(
            item['cantidad_ump_comprada']?.toString() ?? '1',
          )?.toDouble() ??
          1.0;
      final int unidadesLote =
          int.tryParse(item['unidades_por_lote']?.toString() ?? '1') ?? 1;
      final double costoUnitarioReal = (cantidadUmp > 0 && unidadesLote > 0)
          ? totalPago / (cantidadUmp * unidadesLote)
          : 0.0;
      final String ump = item['ump_compra'] ?? 'UND';
      final String desc = item['descripcion_detectada'] ?? 'Sin descripción';
      final String padre = item['producto_padre_estimado'] ?? '';
      final String variante = item['variante_detectada'] ?? '';
      final String marca = item['marca_detectada'] ?? '';

      totalAcumulado += totalPago;
      final bool isEven = i % 2 == 0;

      final metaList = <String>[];
      if (padre.isNotEmpty && padre != 'N/A') {
        metaList.add(padre);
      }
      if (variante.isNotEmpty && variante != 'N/A') {
        metaList.add(variante);
      }
      if (marca.isNotEmpty && marca != 'N/A') {
        metaList.add('[$marca]');
      }
      final String metaText = metaList.join(' - ');
      final String correlative = '#${(i + 1).toString().padLeft(2, '0')}';

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven
                ? PdfColors.white
                : InvoicePdfReportService._tableZebra,
          ),
          children: [
            _buildTableCell(
              correlative,
              align: pw.TextAlign.center,
              isBold: true,
            ),
            _buildProductWithSublinkCell(
              desc,
              metaText.isNotEmpty ? metaText : null,
            ),
            _buildTableCell(
              '${cantidadUmp.toStringAsFixed(cantidadUmp.truncateToDouble() == cantidadUmp ? 0 : 2)} $ump (x$unidadesLote)',
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              'S/ ${costoUnitarioReal.toStringAsFixed(3)}',
              align: pw.TextAlign.right,
              textColor: InvoicePdfReportService._accentOrange,
              isBold: true,
            ),
            _buildTableCell(
              AppCurrency.format(totalPago),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: InvoicePdfReportService._accentGreen,
            ),
          ],
        ),
      );
    }

    tableRows.add(
      _buildTotalRow(
        label: 'TOTAL AUDITADO (${items.length} ÍTEMS)',
        totalAcumulado: totalAcumulado,
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(
        color: InvoicePdfReportService._borderColor,
        width: 0.6,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(5.2),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(2.0),
        4: pw.FlexColumnWidth(2.2),
      },
      children: tableRows,
    );
  }

  static pw.Widget buildManualItemsTable(
    List<Map<String, dynamic>> presentations,
  ) {
    double totalAcumulado = 0.0;

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: InvoicePdfReportService._primaryColor,
        ),
        children: [
          _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('PRODUCTO / PRESENTACIÓN VINCULADA', isHeader: true),
          _buildTableCell(
            'CANTIDAD',
            isHeader: true,
            align: pw.TextAlign.center,
          ),
          _buildTableCell(
            'COSTO UNIT.',
            isHeader: true,
            align: pw.TextAlign.right,
          ),
          _buildTableCell(
            'SUBTOTAL',
            isHeader: true,
            align: pw.TextAlign.right,
          ),
        ],
      ),
    ];

    for (int i = 0; i < presentations.length; i++) {
      final pres = presentations[i];
      final pCosto = (pres['precio_costo'] as num?)?.toDouble() ?? 0.0;
      final stock = (pres['cantidad_stock'] as num?)?.toDouble() ?? 1.0;
      final subtotal = pCosto * stock;
      totalAcumulado += subtotal;
      final bool isEven = i % 2 == 0;
      final String correlative = '#${(i + 1).toString().padLeft(2, '0')}';
      final String prodName = pres['producto_nombre'] ?? 'Producto';
      final String presName = pres['presentacion_nombre'] ?? 'Presentación';

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven
                ? PdfColors.white
                : InvoicePdfReportService._tableZebra,
          ),
          children: [
            _buildTableCell(
              correlative,
              align: pw.TextAlign.center,
              isBold: true,
            ),
            _buildProductWithSublinkCell(prodName, presName),
            _buildTableCell(
              stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1),
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              AppCurrency.format(pCosto),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: InvoicePdfReportService._accentOrange,
            ),
            _buildTableCell(
              AppCurrency.format(subtotal),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: InvoicePdfReportService._accentGreen,
            ),
          ],
        ),
      );
    }

    tableRows.add(
      _buildTotalRow(
        label: 'TOTAL VINCULADO (${presentations.length} PRESENTACIONES)',
        totalAcumulado: totalAcumulado,
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(
        color: InvoicePdfReportService._borderColor,
        width: 0.6,
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(5.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FlexColumnWidth(2.2),
      },
      children: tableRows,
    );
  }

  static pw.TableRow _buildTotalRow({
    required String label,
    required double totalAcumulado,
  }) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(
        color: InvoicePdfReportService._primaryLight,
        border: pw.Border(
          top: pw.BorderSide(
            color: InvoicePdfReportService._primaryColor,
            width: 1.5,
          ),
          bottom: pw.BorderSide(
            color: InvoicePdfReportService._primaryColor,
            width: 1.5,
          ),
        ),
      ),
      children: [
        _buildTableCell(''),
        _buildTableCell(
          label,
          isBold: true,
          textColor: InvoicePdfReportService._primaryColor,
        ),
        _buildTableCell(''),
        _buildTableCell(''),
        _buildTableCell(
          AppCurrency.format(totalAcumulado),
          align: pw.TextAlign.right,
          isBold: true,
          textColor: InvoicePdfReportService._primaryColor,
        ),
      ],
    );
  }

  static pw.Widget _buildProductWithSublinkCell(
    String primaryText,
    String? subText, {
    bool isBold = true,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            primaryText,
            softWrap: true,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: InvoicePdfReportService._secondaryColor,
            ),
          ),
          if (subText != null && subText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              '> $subText',
              softWrap: true,
              style: const pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor? textColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
      child: pw.Text(
        text,
        textAlign: align,
        softWrap: true,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 8,
          fontWeight: isHeader || isBold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader
              ? PdfColors.white
              : (textColor ?? InvoicePdfReportService._secondaryColor),
          letterSpacing: isHeader ? 0.4 : 0,
        ),
      ),
    );
  }

  static pw.Widget buildEmptyTablePlaceholder() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: InvoicePdfReportService._tableZebra,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: InvoicePdfReportService._borderColor,
          width: 0.6,
        ),
      ),
      child: pw.Text(
        'Esta factura no contiene ítems de auditoría registrados.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }
}
