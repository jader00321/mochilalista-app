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
            border: pw.Border.all(color: textColor.withAlpha(50), width: 1)
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 10, color: textColor.withAlpha(200))),
              pw.SizedBox(height: 4),
              pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor)),
            ]
          )
        )
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue900, width: 3))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(reportTitle, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 6),
                    pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text("Período: $dateRangeText", style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Emitido el", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(dateFmt.format(DateTime.now()), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
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
          // If stats is missing, recalculate from the sales list provided
          double totalIncome = stats?.totalIngresos ?? sales.fold(0.0, (sum, s) => sum + s.totalAmount);
          double avgTicket = sales.isNotEmpty ? totalIncome / sales.length : 0.0;
          int totalItems = stats?.totalProductosVendidos ?? sales.length; // Not perfectly accurate without items details, but fallback
          
          return [
            buildSectionTitle("Resumen de Desempeño", PdfColors.blue800),
            pw.Row(
              children: [
                buildMetricCard(scope == ExportHistoryScope.loansOnly ? "TOTAL PRESTADO" : "INGRESOS TOTALES", currencyFmt.format(totalIncome), PdfColors.blue50, PdfColors.blue900),
                buildMetricCard(scope == ExportHistoryScope.loansOnly ? "N° PRÉSTAMOS" : "N° DE VENTAS", "${sales.length}", PdfColors.teal50, PdfColors.teal900),
                buildMetricCard("TICKET PROMEDIO", currencyFmt.format(avgTicket), PdfColors.purple50, PdfColors.purple900),
                if (scope != ExportHistoryScope.loansOnly)
                  buildMetricCard("PRODS. VENDIDOS", "$totalItems", PdfColors.orange50, PdfColors.orange900),
              ]
            ),
            
            pw.SizedBox(height: 10),
            if (stats != null && scope != ExportHistoryScope.specificPaymentMethod) ...[
              pw.Row(
                children: [
                  buildMetricCard("VENTAS EFECTIVO", currencyFmt.format(stats.totalEfectivo), PdfColors.green50, PdfColors.green900),
                  buildMetricCard("VENTAS TRANSF.", currencyFmt.format(stats.totalTransferencia), PdfColors.indigo50, PdfColors.indigo900),
                  buildMetricCard("POR COBRAR", currencyFmt.format(stats.totalDeuda), PdfColors.red50, PdfColors.red900),
                  buildMetricCard("BILLETERA DIGITAL", currencyFmt.format(stats.totalDigital), PdfColors.pink50, PdfColors.pink900),
                ]
              )
            ],

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

    final output = await getTemporaryDirectory();
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
      double total = list.fold(0.0, (sum, s) => sum + s.totalAmount);
      widgets.add(buildTitle("Transacciones: $method (Total: ${currencyFmt.format(total)})", PdfColors.blueGrey800));
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
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
      data: [
        ['N°', 'Fecha', 'Cliente', 'Origen', 'Método', 'Total'],
        ...sales.map((sale) {
          String client = sale.clientName ?? "Cliente de Mostrador";
          String date = sale.saleDate.isNotEmpty ? shortDateFmt.format(DateTime.tryParse(sale.saleDate) ?? DateTime.now()) : "-";
          String origin = sale.origenVenta == 'pos_rapido' ? 'Caja Rápida' : 
                         sale.origenVenta == 'ai_scan' ? 'IA Escáner' : 
                         sale.origenVenta == 'prestamo_personal' ? 'Préstamo' : 'Cotización';
          
          return [
            '#${sale.displayId}', 
            date, 
            client.length > 25 ? '${client.substring(0, 22)}...' : client, 
            origin,
            sale.paymentMethod.toUpperCase(),
            currencyFmt.format(sale.totalAmount)
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
  }) async {
    final output = await getTemporaryDirectory();
    final String path = '${output.path}/Historial_Ventas_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    
    final buffer = StringBuffer();
    
    buffer.writeln("=== $reportTitle - $businessName ===");
    buffer.writeln("Generado el: ${dateFmt.format(DateTime.now())}");
    buffer.writeln("Período: $dateRangeText");
    buffer.writeln("");
    
    if (stats != null && scope != ExportHistoryScope.specificPaymentMethod) {
      buffer.writeln("--- RESUMEN DE MÉTODOS DE PAGO Y DEUDA ---");
      buffer.writeln("Métrica,Total");
      buffer.writeln("Efectivo,${stats.totalEfectivo}");
      buffer.writeln("Transferencia,${stats.totalTransferencia}");
      buffer.writeln("Yape/Plin,${stats.totalDigital}");
      buffer.writeln("Por Cobrar (Deuda Pendiente),${stats.totalDeuda}");
      buffer.writeln("");
    }

    if (scope == ExportHistoryScope.loansOnly) {
      buffer.writeln("--- DETALLE DE PRÉSTAMOS ---");
      buffer.writeln("ID Préstamo,Fecha,Cliente,Origen,Método de Pago,Estado Entrega,Total");
    } else {
      buffer.writeln("--- DETALLE DE VENTAS ---");
      buffer.writeln("ID Venta,Fecha,Cliente,Origen,Método de Pago,Estado Entrega,Total");
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
          buffer.writeln("${sale.displayId},${sale.saleDate},$client,${sale.origenVenta},${sale.paymentMethod},${sale.deliveryStatus},${sale.totalAmount}");
        }
      });
    } else {
      if (scope == ExportHistoryScope.loansOnly) {
        buffer.writeln("\n===== HISTORIAL COMPLETO DE PRÉSTAMOS =====");
        buffer.writeln("ID,Fecha Préstamo,Cliente,Origen,Metodo Pago,Estado Entrega,Total");
      } else {
        buffer.writeln("\n===== HISTORIAL COMPLETO DE VENTAS =====");
        buffer.writeln("ID,Fecha Venta,Cliente,Origen Venta,Metodo Pago,Estado Entrega,Total");
      }
      for (var sale in sales) {
        String client = (sale.clientName != null && sale.clientName!.isNotEmpty) 
                      ? sale.clientName!.replaceAll(',', ' ') 
                      : 'Anónimo';
        buffer.writeln("${sale.displayId},${sale.saleDate},$client,${sale.origenVenta},${sale.paymentMethod},${sale.deliveryStatus},${sale.totalAmount}");
      }
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}
