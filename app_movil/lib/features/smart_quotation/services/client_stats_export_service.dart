import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class ClientStatsExportService {
  static final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  static final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final shortDateFmt = DateFormat('dd/MM/yyyy');

  static Future<File> exportToPdf({
    required ClientModel client,
    required List<SaleSummary> filteredSales,
    required String businessName,
    required String dateRangeText,
    required Map<String, dynamic> extraStats,
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
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.deepPurple900, width: 3))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("ESTADÍSTICAS DEL CLIENTE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
                    pw.SizedBox(height: 6),
                    pw.Text(client.fullName.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    if (client.phone.isNotEmpty) pw.Text("Teléfono: ${client.phone}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text("Período: $dateRangeText", style: const pw.TextStyle(fontSize: 12, color: PdfColors.deepPurple700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(color: PdfColors.deepPurple50, borderRadius: pw.BorderRadius.circular(6)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(businessName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
                      pw.Text("Emitido el", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(dateFmt.format(DateTime.now()), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple900)),
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
          double totalSpent = filteredSales.fold(0.0, (sum, s) => sum + s.trueTotal);
          double avgSpent = filteredSales.isNotEmpty ? totalSpent / filteredSales.length : 0.0;
          
          return [
            buildSectionTitle("Resumen de Compras", PdfColors.deepPurple800),
            pw.Row(
              children: [
                buildMetricCard("INVERSIÓN TOTAL", currencyFmt.format(totalSpent), PdfColors.deepPurple50, PdfColors.deepPurple900),
                buildMetricCard("FRECUENCIA", "${filteredSales.length} Ventas", PdfColors.teal50, PdfColors.teal900),
                buildMetricCard("PROMEDIO/VENTA", currencyFmt.format(avgSpent), PdfColors.orange50, PdfColors.orange900),
                buildMetricCard("DEUDA PENDIENTE", currencyFmt.format(client.totalDebt), PdfColors.red50, PdfColors.red900),
              ]
            ),
            
            if (extraStats['top_products'] != null && (extraStats['top_products'] as List).isNotEmpty) ...[
              buildSectionTitle("Productos Preferidos", PdfColors.indigo800),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (extraStats['top_products'] as List).take(4).map((p) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: PdfColors.indigo100)),
                  child: pw.Text(p.toString(), style: const pw.TextStyle(fontSize: 10, color: PdfColors.indigo900)),
                )).toList()
              )
            ],

            buildSectionTitle("Cronología de Compras", PdfColors.deepPurple800),
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple800),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
              data: [
                ['Fecha', 'Estado', 'Origen', 'Items', 'Total'],
                ...filteredSales.map((sale) {
                  String date = sale.date.isNotEmpty ? shortDateFmt.format(DateTime.tryParse(sale.date) ?? DateTime.now()) : "-";
                  String status = sale.status.toUpperCase();
                  String origin = sale.origenVenta == 'pos_rapido' ? 'Caja Rápida' : 
                                 sale.origenVenta == 'ai_scan' ? 'IA Escáner' : 'Cotización';
                  
                  return [
                    date,
                    status,
                    origin,
                    '${sale.itemsCount}',
                    currencyFmt.format(sale.trueTotal)
                  ];
                }),
              ],
            ),
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final String path = '${output.path}/Stats_${client.fullName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> exportToCsv({
    required ClientModel client,
    required List<SaleSummary> filteredSales,
    required String businessName,
    required String dateRangeText,
    required Map<String, dynamic> extraStats,
  }) async {
    final output = await getTemporaryDirectory();
    final String path = '${output.path}/Stats_${client.fullName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    
    final buffer = StringBuffer();
    
    buffer.writeln("=== ESTADÍSTICAS DEL CLIENTE - $businessName ===");
    buffer.writeln("Cliente: ${client.fullName}");
    buffer.writeln("Generado el: ${dateFmt.format(DateTime.now())}");
    buffer.writeln("Período: $dateRangeText");
    buffer.writeln("");
    
    double totalSpent = filteredSales.fold(0.0, (sum, s) => sum + s.trueTotal);
    
    buffer.writeln("--- RESUMEN ---");
    buffer.writeln("Inversión Total,${totalSpent.toStringAsFixed(2)}");
    buffer.writeln("Número de Compras,${filteredSales.length}");
    buffer.writeln("Deuda Pendiente,${client.totalDebt.toStringAsFixed(2)}");
    buffer.writeln("");

    if (extraStats['top_products'] != null && (extraStats['top_products'] as List).isNotEmpty) {
      buffer.writeln("--- PRODUCTOS PREFERIDOS ---");
      for (var p in extraStats['top_products']) {
        buffer.writeln(p.toString().replaceAll(',', ' '));
      }
      buffer.writeln("");
    }

    buffer.writeln("--- CRONOLOGÍA DE COMPRAS ---");
    buffer.writeln("ID,Fecha,Origen,Estado,Items,Monto Pagado,Total");
    for (var sale in filteredSales) {
      buffer.writeln("${sale.id},${sale.date},${sale.origenVenta},${sale.status},${sale.itemsCount},${sale.montoPagado},${sale.trueTotal}");
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}
