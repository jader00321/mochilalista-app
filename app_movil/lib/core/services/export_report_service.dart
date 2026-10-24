import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';

enum ExportScope { currentView, pendingOnly, soldOnly, full }

class ExportReportService {
  Future<void> generateAndShareWorkbenchPdf({
    required ExportScope scope,
    required String timeFilterLabel,
    required DateTimeRange range,
    required int inProcessCount,
    required int readyCount,
    required int alertCount,
    required double totalSales,
    required List<SmartQuotationModel> inProcessList,
    required List<SmartQuotationModel> readyAndPacksList,
    required List<SmartQuotationModel> soldList,
    int? activeTabIndex,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final rangeFormat = DateFormat('dd/MM/yyyy');

    final now = DateTime.now();
    final generatedAt = dateFormat.format(now);
    final rangeStr = "${rangeFormat.format(range.start)} - ${rangeFormat.format(range.end)}";

    List<SmartQuotationModel> allQuotes = [];
    List<pw.Widget> kpis = [];
    String reportTitle = "Reporte de Cotizaciones";

    if (scope == ExportScope.currentView) {
      if (activeTabIndex == 0) {
        allQuotes = [...inProcessList];
        reportTitle = "Cotizaciones En Revisión";
      } else if (activeTabIndex == 1) {
        allQuotes = [...readyAndPacksList];
        reportTitle = "Cotizaciones Preparadas";
      } else if (activeTabIndex == 2) {
        allQuotes = [...soldList];
        reportTitle = "Cotizaciones Vendidas";
      } else {
        allQuotes = [...soldList, ...readyAndPacksList, ...inProcessList];
      }
      kpis = [
        _buildKpiBox("En Revisión", "$inProcessCount", PdfColors.orange700),
        _buildKpiBox("Preparadas", "$readyCount", PdfColors.teal700),
        _buildKpiBox("Alertas", "$alertCount", PdfColors.red700),
        _buildKpiBox("Acumulado", AppCurrency.format(totalSales), PdfColors.blue700),
      ];
    } else if (scope == ExportScope.pendingOnly) {
      reportTitle = "Cotizaciones Pendientes";
      allQuotes = [...readyAndPacksList, ...inProcessList];
      double proj = allQuotes.fold(0.0, (s, q) => s + q.totalAmount);
      kpis = [
        _buildKpiBox("En Revisión", "${inProcessList.length}", PdfColors.orange700),
        _buildKpiBox("Preparadas", "${readyAndPacksList.length}", PdfColors.teal700),
        _buildKpiBox("Total Pend.", "${allQuotes.length}", PdfColors.purple700),
        _buildKpiBox("Proyectado", AppCurrency.format(proj), PdfColors.blue700),
      ];
    } else if (scope == ExportScope.soldOnly) {
      reportTitle = "Ventas Realizadas";
      allQuotes = [...soldList];
      double totalInc = soldList.fold(0.0, (s, q) => s + q.totalAmount);
      int itemsSold = soldList.fold(0, (s, q) => s + q.items.fold(0, (si, i) => si + i.quantity));
      double avg = soldList.isEmpty ? 0 : totalInc / soldList.length;
      kpis = [
        _buildKpiBox("Ventas", "${soldList.length}", PdfColors.green700),
        _buildKpiBox("Ingresos", AppCurrency.format(totalInc), PdfColors.amber700),
        _buildKpiBox("Prods Vend.", "$itemsSold", PdfColors.purple700),
        _buildKpiBox("Ticket Prom.", AppCurrency.format(avg), PdfColors.blue700),
      ];
    } else if (scope == ExportScope.full) {
      reportTitle = "Reporte Completo";
      allQuotes = [...soldList, ...readyAndPacksList, ...inProcessList];
      double totalInc = soldList.fold(0.0, (s, q) => s + q.totalAmount);
      double proj = readyAndPacksList.fold(0.0, (s, q) => s + q.totalAmount) + inProcessList.fold(0.0, (s, q) => s + q.totalAmount);
      kpis = [
        _buildKpiBox("Total Cotiz.", "${allQuotes.length}", PdfColors.blueGrey700),
        _buildKpiBox("Proyectado", AppCurrency.format(proj), PdfColors.orange700),
        _buildKpiBox("Ventas", "${soldList.length}", PdfColors.green700),
        _buildKpiBox("Ingresos", AppCurrency.format(totalInc), PdfColors.amber700),
      ];
    }

    allQuotes.sort((a, b) {
      final timeA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA); // Más recientes primero
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabecera
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(reportTitle, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 4),
                    pw.Text('Mochila Lista 2.0', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Filtro: $timeFilterLabel', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Periodo: $rangeStr', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                    pw.Text('Generado: $generatedAt', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // Tarjetas KPI
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: kpis,
            ),

            pw.SizedBox(height: 30),
            pw.Text('Detalle de Movimientos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.SizedBox(height: 12),

            // Tabla de cotizaciones
            if (allQuotes.isEmpty)
              pw.Center(child: pw.Text("No hay registros en este periodo.", style: const pw.TextStyle(color: PdfColors.grey)))
            else
              pw.TableHelper.fromTextArray(
                context: context,
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.0),
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headerHeight: 30,
                cellHeight: 25,
                cellAlignments: {
                  0: pw.Alignment.centerLeft, // Cliente
                  1: pw.Alignment.center,     // Items
                  2: pw.Alignment.center,     // Tipo
                  3: pw.Alignment.center,     // Estado
                  4: pw.Alignment.centerRight, // Total
                  5: pw.Alignment.centerRight, // Fecha
                },
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                data: [
                  ['Cliente', 'Items', 'Tipo', 'Estado', 'Total', 'Fecha'],
                  ...allQuotes.map((q) {
                    final date = DateTime.tryParse(q.createdAt);
                    return [
                      q.clientName ?? "Sin Cliente",
                      q.itemCount.toString(),
                      q.type == 'ai_scan' ? 'IA' : (q.type == 'pack' ? 'Pack' : 'Manual'),
                      _mapStatusToEs(q.status),
                      AppCurrency.format(q.totalAmount),
                      date != null ? DateFormat('dd/MM HH:mm').format(date) : '-',
                    ];
                  }),
                ],
              ),
          ];
        },
      ),
    );

    // Guardar y compartir
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Reporte_MochilaLista.pdf");
    await file.writeAsBytes(await pdf.save());

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Cotizaciones - $timeFilterLabel');
  }

  Future<void> generateAndShareWorkbenchCsv({
    required ExportScope scope,
    required String timeFilterLabel,
    required DateTimeRange range,
    required List<SmartQuotationModel> inProcessList,
    required List<SmartQuotationModel> readyAndPacksList,
    required List<SmartQuotationModel> soldList,
    int? activeTabIndex,
  }) async {
    List<SmartQuotationModel> allQuotes = [];
    String reportTitle = "REPORTE DE COTIZACIONES";
    
    if (scope == ExportScope.currentView) {
      if (activeTabIndex == 0) {
        allQuotes = [...inProcessList];
        reportTitle = "COTIZACIONES EN REVISIÓN";
      } else if (activeTabIndex == 1) {
        allQuotes = [...readyAndPacksList];
        reportTitle = "COTIZACIONES PREPARADAS";
      } else if (activeTabIndex == 2) {
        allQuotes = [...soldList];
        reportTitle = "COTIZACIONES VENDIDAS";
      } else {
        allQuotes = [...soldList, ...readyAndPacksList, ...inProcessList];
      }
    } else if (scope == ExportScope.full) {
      allQuotes = [...soldList, ...readyAndPacksList, ...inProcessList];
      reportTitle = "REPORTE COMPLETO DE COTIZACIONES";
    } else if (scope == ExportScope.pendingOnly) {
      allQuotes = [...readyAndPacksList, ...inProcessList];
      reportTitle = "COTIZACIONES PENDIENTES";
    } else if (scope == ExportScope.soldOnly) {
      allQuotes = [...soldList];
      reportTitle = "VENTAS REALIZADAS";
    }

    allQuotes.sort((a, b) {
      final timeA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA);
    });

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Reporte_MochilaLista.csv");
    final buffer = StringBuffer();
    
    buffer.writeln("=== $reportTitle - MochilaLista ===");
    buffer.writeln("Filtro: $timeFilterLabel");
    buffer.writeln("Periodo: ${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}");
    buffer.writeln("");
    
    buffer.writeln("ID,Cliente,Tipo,Estado,Items,Total,Fecha");
    for (var q in allQuotes) {
      final date = DateTime.tryParse(q.createdAt);
      final dateStr = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : '-';
      final typeStr = q.type == 'ai_scan' ? 'IA' : (q.type == 'pack' ? 'Pack' : 'Manual');
      buffer.writeln("${q.id},\"${q.clientName ?? 'Sin Cliente'}\",$typeStr,${_mapStatusToEs(q.status)},${q.itemCount},\"${AppCurrency.format(q.totalAmount)}\",$dateStr");
    }

    await file.writeAsString(buffer.toString());
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: 'Reporte CSV de Cotizaciones - $timeFilterLabel');
  }

  pw.Widget _buildKpiBox(String title, String value, PdfColor color) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: color, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 4),
          pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  String _mapStatusToEs(String status) {
    switch (status) {
      case 'DRAFT': return 'Borrador';
      case 'PENDING': return 'Pendiente';
      case 'READY': return 'Listo';
      case 'SOLD': return 'Vendido';
      case 'ARCHIVED': return 'Archivado';
      default: return status;
    }
  }
}
