import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';

class AnalyticsExportService {
  static Future<File> exportToPdf(AnalyticsData data, String businessName) async {
    final pdf = pw.Document();
    final DateFormat df = DateFormat('dd/MM/yyyy');
    final String periodLabel = data.periodStartDate != null && data.periodEndDate != null
        ? "Periodo: ${df.format(data.periodStartDate!)} al ${df.format(data.periodEndDate!)}"
        : "Periodo Activo";
    
    // Función de ayuda para tablas
    pw.Widget buildSectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 20, bottom: 10),
        child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.indigo800)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 2))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Reporte de Estadísticas", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.SizedBox(height: 4),
                    pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  ],
                )
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount} - Generado por MochilaLista', 
                           style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
          );
        },
        build: (pw.Context context) {
          return [
            buildSectionTitle("Resumen Financiero"),
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              data: [
                ['Métrica', 'Valor'],
                ['Ventas Totales', AppCurrency.format(data.totalSales)],
                ['Ganancia Neta', AppCurrency.format(data.netProfit)],
                ['Margen de Ganancia', '${data.estimatedMarginPercentage.toStringAsFixed(1)}%'],
                ['Ticket Promedio', AppCurrency.format(data.averageTicket)],
                ['Transacciones', '${data.totalTransactions}'],
                ['Crecimiento', '${data.salesGrowthRate > 0 ? '+' : ''}${data.salesGrowthRate.toStringAsFixed(1)}%'],
                ['Valor de Inventario', AppCurrency.format(data.inventoryValue)],
                ['Proyección Próx. Periodo', AppCurrency.format(data.nextMonthPrediction)],
              ],
            ),
            
            pw.SizedBox(height: 10),
            buildSectionTitle("Top 5 Productos Más Vendidos"),
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
              data: [
                ['#', 'Producto', 'Unidades Vendidas'],
                ...data.topProducts.asMap().entries.map((e) => ['${e.key + 1}', e.value['nombre'], '${e.value['total_vendido']}']),
              ],
            ),

            buildSectionTitle("Mejores Clientes"),
            pw.TableHelper.fromTextArray(
              context: context,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
              data: [
                ['#', 'Cliente', 'Total Comprado'],
                ...data.topClients.asMap().entries.map((e) => ['${e.key + 1}', e.value['nombre_completo'], AppCurrency.format(e.value['total_comprado'])]),
              ],
            ),
            
            buildSectionTitle("Quiebres de Stock (Alertas)"),
            if (data.lowStockProducts.isEmpty) 
               pw.Text("Todo el inventario está por encima del stock mínimo.")
            else
               pw.TableHelper.fromTextArray(
                 context: context,
                 headerDecoration: const pw.BoxDecoration(color: PdfColors.red100),
                 data: [
                   ['Producto', 'Stock Actual', 'Mínimo Permitido'],
                   ...data.lowStockProducts.map((p) => [p['nombre'].toString(), p['stock_actual'].toString(), p['stock_alerta'].toString()]),
                 ],
               ),
               
            if (data.insights.isNotEmpty) ...[
              pw.Wrap(
                children: [
                  buildSectionTitle("Insights y Recomendaciones"),
                  ...data.insights.map((insight) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(insight.title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 4),
                        pw.Text(insight.description, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  )),
                ]
              )
            ]
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final String path = '${output.path}/Reporte_Estadisticas_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> exportToCsv(AnalyticsData data, String businessName) async {
    final output = await getTemporaryDirectory();
    final String path = '${output.path}/Reporte_Estadisticas_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    
    final buffer = StringBuffer();
    
    buffer.writeln("=== REPORTE DE ESTADISTICAS - $businessName ===");
    buffer.writeln("Generado el: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}");
    buffer.writeln("");
    
    buffer.writeln("--- RESUMEN FINANCIERO ---");
    buffer.writeln("Metrica,Valor");
    buffer.writeln("Ventas Totales,${data.totalSales}");
    buffer.writeln("Ganancia Neta,${data.netProfit}");
    buffer.writeln("Ticket Promedio,${data.averageTicket}");
    buffer.writeln("Transacciones Totales,${data.totalTransactions}");
    buffer.writeln("Crecimiento %,${data.salesGrowthRate.toStringAsFixed(2)}");
    buffer.writeln("Proyeccion Proximo Mes,${data.nextMonthPrediction}");
    buffer.writeln("Margen Estimado %,${data.estimatedMarginPercentage.toStringAsFixed(2)}");
    buffer.writeln("Valor de Inventario,${data.inventoryValue}");
    buffer.writeln("Productos sin ventas >90 dias,${data.deadStockCount}");
    buffer.writeln("");
    
    buffer.writeln("--- VENTAS MENSUALES ---");
    buffer.writeln("Mes,Total Ventas");
    for (var m in data.monthlySales) {
      buffer.writeln("${m['month']},${m['amount']}");
    }
    buffer.writeln("");
    
    buffer.writeln("--- TOP PRODUCTOS ---");
    buffer.writeln("Producto,Cantidad Vendida");
    for (var p in data.topProducts) {
      buffer.writeln("${p['nombre']},${p['total_vendido']}");
    }
    buffer.writeln("");
    
    buffer.writeln("--- TOP CLIENTES ---");
    buffer.writeln("Cliente,Total Comprado");
    for (var c in data.topClients) {
      buffer.writeln("${c['nombre_completo']},${c['total_comprado']}");
    }
    buffer.writeln("");
    
    buffer.writeln("--- VENTAS POR DIA DE LA SEMANA ---");
    buffer.writeln("Dia,Monto");
    for (var d in data.salesByDayOfWeek) {
      buffer.writeln("${d['name']},${d['amount']}");
    }
    buffer.writeln("");
    
    buffer.writeln("--- ALERTAS DE STOCK ---");
    buffer.writeln("Producto,Stock Actual,Stock Minimo");
    for (var p in data.lowStockProducts) {
      buffer.writeln("${p['nombre']},${p['stock_actual']},${p['stock_alerta']}");
    }

    await file.writeAsString(buffer.toString());
    return file;
  }
}
