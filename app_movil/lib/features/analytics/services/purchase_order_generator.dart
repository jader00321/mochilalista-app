import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';

class PurchaseOrderGenerator {
  static Future<File> exportToPdf(List<SmartRestockItem> items, String businessName) async {
    final pdf = pw.Document();
    
    // Calcular el total general fuera del build para evitar sumas duplicadas (bug de pdf generation)
    double grandTotal = 0;
    for (var item in items) {
      grandTotal += item.orderQty * item.cost;
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("ORDEN DE COMPRA SUGERIDA", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(businessName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Text("Fecha de Emisión: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 16),
            ]
          );
        },
        build: (context) {
          final tableHeaders = [
            'Producto',
            'Marca',
            'Stock / ROP',
            'Velocidad',
            'Cant. Pedir',
            'Costo U.',
            'Total'
          ];
          
          final tableData = items.map((item) {
            final double rowTotal = item.orderQty * item.cost;
            final String title = item.presentationName != 'Unidad' && item.presentationName.isNotEmpty
                  ? "${item.productName} - ${item.presentationName}"
                  : item.productName;
                  
            return [
              title,
              item.brandName,
              "${item.currentStock} / ${item.rop}",
              item.velocityDisplay,
              item.orderQty.toString(),
              AppCurrency.format(item.cost),
              AppCurrency.format(rowTotal)
            ];
          }).toList();
          
          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Resumen Ejecutivo", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  pw.SizedBox(height: 4),
                  pw.Text("Esta orden sugiere el reabastecimiento de ${items.length} productos críticos cuyo stock actual está en o por debajo de su punto de reorden (ROP). La inversión total proyectada es de ${AppCurrency.format(grandTotal)}.", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text("Detalle de Reabastecimiento", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: tableHeaders,
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellHeight: 28,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2),
                6: const pw.FlexColumnWidth(2),
              },
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.blue200)
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Total de Inversión Sugerida", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(AppCurrency.format(grandTotal), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    ]
                  )
                )
              ]
            ),
            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Text("Notas:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.Text("• ROP (Punto de Reorden): Nivel mínimo de inventario en el cual se debe reabastecer.\n• Vel. (u/d): Velocidad de venta promedio en unidades por día.\n• Sugerido: Cantidad óptima a ordenar calculada por el algoritmo inteligente.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text("Este documento fue generado automáticamente por el Motor Inteligente de Abastecimiento.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            )
          ];
        }
      )
    );
    
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Orden_Compra_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
