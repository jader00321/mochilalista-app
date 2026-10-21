import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

enum ExportHistoryScope {
  currentView,
  fullPeriod,
  fullHistory,
  archivedOnly,
  byPaymentMethodGrouped,
  specificPaymentMethod,
  loansOnly,
}

class HistoryExportService {
  static final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  static final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final shortDateFmt = DateFormat('dd/MM/yyyy');

  static Future<File> exportToPdf({
    required List<SaleModel> sales,
    required SalesStatsModel? stats,
    required String businessName,
    required String dateRangeText,
    String reportTitle = "REPORTE GLOBAL DE VENTAS",
    ExportHistoryScope scope = ExportHistoryScope.currentView,
    Directory? outputDirectory,
  }) async {
    final pdf = pw.Document();
    
    pw.Widget buildSectionTitle(String title, PdfColor color) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 24, bottom: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: color)),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, width: 60, color: color),
          ]
        )
      );
    }

    pw.Widget buildMetricCard(String label, String value, PdfColor bgColor, PdfColor textColor) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            color: bgColor,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: textColor.withAlpha(0.2), width: 1)
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 10, color: textColor.withAlpha(0.8))),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: textColor)),
            ]
          )
        )
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 3))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(reportTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 5),
                    pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 3),
                    pw.Text("Período: $dateRangeText", style: const pw.TextStyle(fontSize: 11, color: PdfColors.blue700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Emitido el", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(dateFmt.format(DateTime.now()), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ]
                  )
                )
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))),
            child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount} | Generado por MochilaLista', 
                           style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
          );
        },
        build: (pw.Context context) {
          // Exactitud matemática: excluir anuladas de ingresos y deudas activas
          final activeSales = sales.where((s) => !s.isArchived).toList();
          final double totalAmount = activeSales.fold(0.0, (sum, s) => sum + s.totalAmount);
          final double totalCollected = activeSales.fold(0.0, (sum, s) => sum + s.totalPaid);
          final double totalDebt = activeSales.fold(0.0, (sum, s) => sum + s.pendingDebt);
          final int opCount = scope == ExportHistoryScope.archivedOnly ? sales.length : activeSales.length;

          return [
            buildSectionTitle("Resumen de Desempeño Financiero", PdfColors.blue800),
            pw.Row(
              children: [
                buildMetricCard(
                  scope == ExportHistoryScope.loansOnly ? "TOTAL PRESTADO" : "TOTAL FACTURADO", 
                  currencyFmt.format(totalAmount), 
                  PdfColors.blue50, 
                  PdfColors.blue900
                ),
                buildMetricCard(
                  "TOTAL COBRADO", 
                  currencyFmt.format(totalCollected), 
                  PdfColors.green50, 
                  PdfColors.green900
                ),
                buildMetricCard(
                  "POR COBRAR", 
                  currencyFmt.format(totalDebt), 
                  PdfColors.red50, 
                  PdfColors.red900
                ),
                buildMetricCard(
                  "OPERACIONES", 
                  "$opCount", 
                  PdfColors.purple50, 
                  PdfColors.purple900
                ),
              ]
            ),
            
            if (scope == ExportHistoryScope.byPaymentMethodGrouped) ...[
              ..._buildGroupedTables(context, sales, buildSectionTitle),
            ] else ...[
              buildSectionTitle("Detalle de Transacciones", PdfColors.blue800),
              _buildSalesTable(context, sales),
            ],
          ];
        },
      ),
    );

    final output = outputDirectory ?? await getTemporaryDirectory();
    final String path = '${output.path}/Historial_Ventas_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static List<pw.Widget> _buildGroupedTables(pw.Context context, List<SaleModel> sales, pw.Widget Function(String, PdfColor) buildTitle) {
    final Map<String, List<SaleModel>> grouped = {};
    for (var s in sales) {
      final method = s.paymentMethod.isEmpty ? "SIN MÉTODO" : s.paymentMethod.toUpperCase();
      grouped.putIfAbsent(method, () => []).add(s);
    }

    List<pw.Widget> widgets = [];
    grouped.forEach((method, list) {
      double total = list.where((s) => !s.isArchived).fold(0.0, (sum, s) => sum + s.totalAmount);
      widgets.add(buildTitle("Método: $method (Total Facturado: ${currencyFmt.format(total)})", PdfColors.blueGrey800));
      widgets.add(_buildSalesTable(context, list));
    });

    return widgets;
  }

  static pw.Widget _buildSalesTable(pw.Context context, List<SaleModel> sales) {
    if (sales.isEmpty) {
      return pw.Center(child: pw.Text("No hay transacciones para mostrar.", style: const pw.TextStyle(color: PdfColors.grey)));
    }
    return pw.TableHelper.fromTextArray(
      context: context,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
      data: [
        ['#ID', 'Fecha', 'Cliente', 'Origen', 'Método', 'Total', 'Cobrado', 'Deuda'],
        ...sales.map((sale) {
          String client = sale.clientName ?? "Cliente de Mostrador";
          String date = sale.saleDate.isNotEmpty ? shortDateFmt.format(DateTime.tryParse(sale.saleDate) ?? DateTime.now()) : "-";
          String origin = sale.isLoan ? 'Préstamo' : 
                         sale.isQuickSale ? 'Caja Rápida' : 
                         sale.isQuotationSale ? 'Cotización' : 'Venta';
          
          String debtCol;
          if (sale.isArchived) {
            debtCol = 'ANULADO';
          } else if (sale.pendingDebt > 0.01) {
            debtCol = currencyFmt.format(sale.pendingDebt);
          } else {
            debtCol = 'PAGADO';
          }

          return [
            '#${sale.displayId}', 
            date, 
            client.length > 20 ? '${client.substring(0, 18)}...' : client, 
            origin,
            sale.paymentMethod.toUpperCase(),
            currencyFmt.format(sale.totalAmount),
            currencyFmt.format(sale.totalPaid),
            debtCol,
          ];
        }),
      ],
    );
  }

  static Future<File> exportToCsv({
    required List<SaleModel> sales,
    required SalesStatsModel? stats,
    required String businessName,
    required String dateRangeText,
    String reportTitle = "REPORTE GLOBAL DE VENTAS",
    ExportHistoryScope scope = ExportHistoryScope.currentView,
    Directory? outputDirectory,
  }) async {
    final output = outputDirectory ?? await getTemporaryDirectory();
    final String path = '${output.path}/Historial_Ventas_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    
    final buffer = StringBuffer();
    
    buffer.writeln("=== $reportTitle - $businessName ===");
    buffer.writeln("Generado el: ${dateFmt.format(DateTime.now())}");
    buffer.writeln("Período: $dateRangeText");
    buffer.writeln("");
    
    // Exactitud contable en resumen
    final activeSales = sales.where((s) => !s.isArchived).toList();
    final double totalAmount = activeSales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final double totalCollected = activeSales.fold(0.0, (sum, s) => sum + s.totalPaid);
    final double totalDebt = activeSales.fold(0.0, (sum, s) => sum + s.pendingDebt);

    buffer.writeln("--- TOTALES CONSOLIDADOS ---");
    buffer.writeln("Métrica,Monto (S/)");
    buffer.writeln("Total Exigible / Facturado,${totalAmount.toStringAsFixed(2)}");
    buffer.writeln("Total Cobrado / Ingreso Caja,${totalCollected.toStringAsFixed(2)}");
    buffer.writeln("Por Cobrar (Deuda Activa),${totalDebt.toStringAsFixed(2)}");
    buffer.writeln("Cantidad de Operaciones,${activeSales.length}");
    buffer.writeln("");

    if (scope == ExportHistoryScope.loansOnly) {
      buffer.writeln("--- DETALLE DE PRÉSTAMOS ---");
      buffer.writeln("ID Préstamo,Fecha,Cliente,Origen,Método de Pago,Importe Total,Monto Cobrado,Deuda Pendiente,Estado Financiero,Motivo");
    } else {
      buffer.writeln("--- DETALLE DE VENTAS ---");
      buffer.writeln("ID Venta,Fecha,Cliente,Origen,Método de Pago,Estado Entrega,Importe Total,Monto Cobrado,Deuda Pendiente,Estado Financiero");
    }
    
    if (scope == ExportHistoryScope.byPaymentMethodGrouped) {
      final Map<String, List<SaleModel>> grouped = {};
      for (var s in sales) {
        final method = s.paymentMethod.isEmpty ? "SIN MÉTODO" : s.paymentMethod.toUpperCase();
        grouped.putIfAbsent(method, () => []).add(s);
      }
      
      grouped.forEach((method, list) {
        buffer.writeln("");
        buffer.writeln(">>> GRUPO: $method <<<");
        for (var sale in list) {
          String client = sale.clientName ?? "Cliente de Mostrador";
          client = client.replaceAll(',', ' ');
          final statusStr = sale.isArchived 
              ? 'ANULADO' 
              : (sale.isFullyPaid ? 'PAGADO' : (sale.isPartialPayment ? 'PARCIAL' : 'PENDIENTE'));
          
          if (sale.isLoan) {
            final noteClean = sale.notes?.replaceAll('"', "'").replaceAll('\n', ' ') ?? '';
            buffer.writeln("${sale.displayId},${sale.saleDate},$client,Préstamo Personal,${sale.paymentMethod},${sale.totalAmount},${sale.totalPaid},${sale.pendingDebt},$statusStr,\"$noteClean\"");
          } else {
            buffer.writeln("${sale.displayId},${sale.saleDate},$client,${sale.origenVenta},${sale.paymentMethod},${sale.deliveryStatus},${sale.totalAmount},${sale.totalPaid},${sale.pendingDebt},$statusStr");
          }
        }
      });
    } else {
      for (var sale in sales) {
        String client = (sale.clientName != null && sale.clientName!.isNotEmpty) 
                      ? sale.clientName!.replaceAll(',', ' ') 
                      : 'Anónimo';
        final statusStr = sale.isArchived 
            ? 'ANULADO' 
            : (sale.isFullyPaid ? 'PAGADO' : (sale.isPartialPayment ? 'PARCIAL' : 'PENDIENTE'));
        
        if (sale.isLoan) {
          final noteClean = sale.notes?.replaceAll('"', "'").replaceAll('\n', ' ') ?? '';
          buffer.writeln("${sale.displayId},${sale.saleDate},$client,Préstamo Personal,${sale.paymentMethod},${sale.totalAmount},${sale.totalPaid},${sale.pendingDebt},$statusStr,\"$noteClean\"");
        } else {
          buffer.writeln("${sale.displayId},${sale.saleDate},$client,${sale.origenVenta},${sale.paymentMethod},${sale.deliveryStatus},${sale.totalAmount},${sale.totalPaid},${sale.pendingDebt},$statusStr");
        }
      }
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}
