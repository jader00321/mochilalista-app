import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';

/// 📄 MOTOR DE GENERACIÓN DE REPORTES PDF PROFESIONALES (Facturas Escaneadas)
/// Diseña documentos ejecutivos con paginación automática (pw.MultiPage),
/// bloques de trazabilidad temporal completa, resumen financiero y tabla de auditoría cebrada.
class InvoicePdfReportService {
  // Paleta de colores corporativos
  static const PdfColor _primaryColor = PdfColor.fromInt(0xFF004D40); // Teal oscuro institucional
  static const PdfColor _primaryLight = PdfColor.fromInt(0xFFE0F2F1); // Teal suave fondo
  static const PdfColor _secondaryColor = PdfColor.fromInt(0xFF1E293B); // Slate oscuro texto
  static const PdfColor _accentGreen = PdfColor.fromInt(0xFF15803D); // Verde estado completado
  static const PdfColor _accentOrange = PdfColor.fromInt(0xFFC2410C); // Naranja revisión
  static const PdfColor _accentBlue = PdfColor.fromInt(0xFF1D4ED8); // Azul procesando
  static const PdfColor _tableZebra = PdfColor.fromInt(0xFFF8FAFC); // Cebrado suave
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFCBD5E1); // Borde gris claro

  /// Genera los bytes del documento PDF y lo guarda en la carpeta pública Downloads
  static Future<File> generateAndSavePdfReport({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) async {
    final pdfBytes = await generatePdfBytes(
      invoice: invoice,
      providerName: providerName,
      providerRuc: providerRuc,
      currentUser: currentUser,
      linkedPresentations: linkedPresentations,
    );

    final provSanitized = InvoiceFileService.sanitizeFileName(providerName ?? 'PROVEEDOR');
    final dateSuffix = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'Factura_${invoice.displayId}_Reporte_${provSanitized}_$dateSuffix.pdf';

    return await InvoiceFileService.saveBytesToDownloads(
      bytes: pdfBytes,
      fileName: fileName,
    );
  }

  /// Alias amigable para buildExecutivePdf
  static Future<Uint8List> buildExecutivePdf({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) => generatePdfBytes(
    invoice: invoice,
    providerName: providerName,
    providerRuc: providerRuc,
    currentUser: currentUser,
    linkedPresentations: linkedPresentations,
  );

  /// Construye la estructura completa del PDF y retorna los bytes generados
  static Future<Uint8List> generatePdfBytes({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    UserModel? currentUser,
    List<Map<String, dynamic>> linkedPresentations = const [],
  }) async {
    final pdf = pw.Document(
      title: 'Factura #${invoice.displayId} - Reporte de Auditoría',
      author: 'MochilaLista App',
    );

    final now = DateTime.now();
    final pdfCreationTimeStr = DateFormat('dd/MM/yyyy, hh:mm:ss a').format(now);
    final scanDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(invoice.fechaCarga.toLocal());
    final emissionDateStr = invoice.fechaEmision != null
        ? DateFormat('dd/MM/yyyy').format(invoice.fechaEmision!)
        : 'No especificada en comprobante';

    // Obtener ítems extraídos del JSON
    List<dynamic> rawItems = [];
    if (invoice.datosCrudosIaJson != null && invoice.datosCrudosIaJson!['items'] != null) {
      rawItems = invoice.datosCrudosIaJson!['items'];
    }

    final bool isManualInvoice = rawItems.isEmpty && linkedPresentations.isNotEmpty;
    final int totalItemsCount = isManualInvoice
        ? linkedPresentations.length
        : (invoice.cantidadItemsExtraidos ?? rawItems.length);

    // Calcular suma total acumulada de ítems para comprobación
    double totalCalculado = 0.0;
    if (!isManualInvoice) {
      for (var it in rawItems) {
        final pago = num.tryParse(it['total_pago_lote']?.toString() ?? '0')?.toDouble() ?? 0.0;
        totalCalculado += pago;
      }
    } else {
      for (var pres in linkedPresentations) {
        final pCosto = (pres['precio_costo'] as num?)?.toDouble() ?? 0.0;
        final stock = (pres['cantidad_stock'] as num?)?.toDouble() ?? 1.0;
        totalCalculado += (pCosto * stock);
      }
    }

    final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _borderColor, width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Factura #${invoice.displayId} - Auditoría de Extracción',
                    style: pw.TextStyle(color: _secondaryColor, fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    providerName ?? 'Sin proveedor',
                    style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'MochilaLista App - Reporte de Auditoría Digital - Local-First Security',
                  style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: pw.TextStyle(color: _secondaryColor, fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. ENCABEZADO INSTITUCIONAL Y TÍTULO DEL DOCUMENTO
            _buildDocumentHeader(
              invoice: invoice,
              currentUser: currentUser,
            ),
            pw.SizedBox(height: 14),

            // 2. BLOQUE DE TRAZABILIDAD TEMPORAL Y METADATOS
            _buildMetadataBlock(
              invoice: invoice,
              providerName: providerName,
              providerRuc: providerRuc,
              pdfCreationTimeStr: pdfCreationTimeStr,
              scanDateStr: scanDateStr,
              emissionDateStr: emissionDateStr,
              isManualInvoice: isManualInvoice,
            ),
            pw.SizedBox(height: 14),

            // 3. TARJETAS DE RESUMEN FINANCIERO Y KPIS
            _buildFinancialSummaryCards(
              invoice: invoice,
              totalItemsCount: totalItemsCount,
              totalCalculado: totalCalculado,
              currencyFmt: currencyFmt,
            ),
            pw.SizedBox(height: 16),

            // 4. TÍTULO DE LA SECCIÓN DE AUDITORÍA
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 4,
                      height: 14,
                      decoration: pw.BoxDecoration(
                        color: _primaryColor,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'AUDITORÍA DE PRODUCTOS EXTRAÍDOS',
                      style: pw.TextStyle(
                        color: _secondaryColor,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: _primaryLight,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: _primaryColor, width: 0.6),
                  ),
                  child: pw.Text(
                    '$totalItemsCount productos auditados',
                    style: pw.TextStyle(
                      color: _primaryColor,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // 5. TABLA COMPLETA DE AUDITORÍA (CON SOFTWRAP Y FILAS CEBRADAS)
            if (isManualInvoice)
              _buildManualItemsTable(linkedPresentations, currencyFmt)
            else if (rawItems.isNotEmpty)
              _buildExtractedItemsTable(rawItems, currencyFmt)
            else
              _buildEmptyTablePlaceholder(),

            pw.SizedBox(height: 14),

            // 6. NOTA TÉCNICA DE AUDITORÍA
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFF1F5F9),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _borderColor, width: 0.6),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('NOTA: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
                  pw.Expanded(
                    child: pw.Text(
                      'Este reporte digital fue generado automáticamente por MochilaLista a partir del comprobante físico escaneado con IA. Los costos unitarios reales incluyen la distribución exacta del precio por unidad de empaque y volumen de lote.',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // ==========================================
  // COMPONENTES MODULARES DEL PDF
  // ==========================================

  static pw.Widget _buildDocumentHeader({
    required InvoiceModel invoice,
    UserModel? currentUser,
  }) {
    final String businessName = currentUser?.business?.commercialName.trim().isNotEmpty == true
        ? currentUser!.business!.commercialName
        : 'MOCHILALISTA GESTIÓN COMERCIAL';

    PdfColor statusBg;
    PdfColor statusFg;
    final String statusUpper = invoice.estado.toUpperCase();

    switch (invoice.estado.toLowerCase()) {
      case 'completado':
        statusBg = const PdfColor.fromInt(0xFFDCFCE7);
        statusFg = _accentGreen;
        break;
      case 'revision':
        statusBg = const PdfColor.fromInt(0xFFFFEDD5);
        statusFg = _accentOrange;
        break;
      default:
        statusBg = const PdfColor.fromInt(0xFFDBEAFE);
        statusFg = _accentBlue;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryColor, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                businessName.toUpperCase(),
                style: pw.TextStyle(
                  color: _primaryColor,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'REPORTE DE FACTURA ESCANEADA',
                style: pw.TextStyle(
                  color: _secondaryColor,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Auditoría y conciliación financiera de comprobante de compra',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'FACTURA #${invoice.displayId}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: pw.BoxDecoration(
                  color: statusBg,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: statusFg, width: 0.8),
                ),
                child: pw.Text(
                  statusUpper,
                  style: pw.TextStyle(
                    color: statusFg,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetadataBlock({
    required InvoiceModel invoice,
    String? providerName,
    String? providerRuc,
    required String pdfCreationTimeStr,
    required String scanDateStr,
    required String emissionDateStr,
    required bool isManualInvoice,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _tableZebra,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Columna 1: Proveedor y Modalidad
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaField(
                  label: 'PROVEEDOR VINCULADO',
                  value: providerName?.trim().isNotEmpty == true ? providerName! : 'Sin proveedor asignado',
                  isBold: true,
                  valueColor: _primaryColor,
                ),
                if (providerRuc != null && providerRuc.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  _buildMetaField(label: 'RUC PROVEEDOR', value: providerRuc),
                ],
                pw.SizedBox(height: 6),
                _buildMetaField(
                  label: 'TIPO DE COMPROBANTE',
                  value: isManualInvoice ? 'Registro Manual en Sistema' : 'Escaneado con Inteligencia Artificial (IA)',
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          // Columna 2: Trazabilidad Temporal
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaField(
                  label: 'FECHA DE EMISIÓN (FÍSICA)',
                  value: emissionDateStr,
                  isBold: true,
                ),
                pw.SizedBox(height: 4),
                _buildMetaField(
                  label: 'FECHA DE ESCANEO CON IA',
                  value: scanDateStr,
                ),
                pw.SizedBox(height: 4),
                _buildMetaField(
                  label: 'GENERACIÓN DE ESTE REPORTE',
                  value: pdfCreationTimeStr,
                  valueColor: PdfColors.grey700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetaField({
    required String label,
    required String value,
    bool isBold = false,
    PdfColor? valueColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColors.grey600,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? _secondaryColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFinancialSummaryCards({
    required InvoiceModel invoice,
    required int totalItemsCount,
    required double totalCalculado,
    required NumberFormat currencyFmt,
  }) {
    final double montoTotal = invoice.montoTotalFactura ?? totalCalculado;

    return pw.Row(
      children: [
        // Tarjeta 1: Total Facturado
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _primaryLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _primaryColor, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MONTO TOTAL FACTURADO',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  currencyFmt.format(montoTotal),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Monto fiscal consignado en comprobante',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),

        // Tarjeta 2: Ítems Extraídos
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _tableZebra,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _borderColor, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TOTAL ÍTEMS',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '$totalItemsCount',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Lotes detectados',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),

        // Tarjeta 3: Subtotal Auditoría
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: pw.BoxDecoration(
              color: _tableZebra,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _borderColor, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SUMA CALCULADA',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  currencyFmt.format(totalCalculado),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _secondaryColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Suma de ítems extraídos',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TABLA DE AUDITORÍA CON PAGINACIÓN LIMPIA
  // ==========================================

  static pw.Widget _buildExtractedItemsTable(
    List<dynamic> items,
    NumberFormat currencyFmt,
  ) {
    double totalAcumulado = 0.0;

    final tableRows = <pw.TableRow>[
      // Cabecera de la tabla
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _primaryColor),
        children: [
          _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('DESCRIPCIÓN / PRODUCTO VINCULADO', isHeader: true),
          _buildTableCell('COMPRA (UMP)', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('COSTO UNIT.', isHeader: true, align: pw.TextAlign.right),
          _buildTableCell('SUBTOTAL', isHeader: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final double totalPago = num.tryParse(item['total_pago_lote']?.toString() ?? '0')?.toDouble() ?? 0.0;
      final double cantidadUmp = num.tryParse(item['cantidad_ump_comprada']?.toString() ?? '1')?.toDouble() ?? 1.0;
      final int unidadesLote = int.tryParse(item['unidades_por_lote']?.toString() ?? '1') ?? 1;
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

      // Construir detalles auxiliares de producto si existen
      final metaList = <String>[];
      if (padre.isNotEmpty && padre != 'N/A') metaList.add(padre);
      if (variante.isNotEmpty && variante != 'N/A') metaList.add(variante);
      if (marca.isNotEmpty && marca != 'N/A') metaList.add('[$marca]');
      final String metaText = metaList.join(' - ');

      final String correlative = '#${(i + 1).toString().padLeft(2, '0')}';

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.white : _tableZebra,
          ),
          children: [
            _buildTableCell(correlative, align: pw.TextAlign.center, isBold: true),
            _buildProductWithSublinkCell(desc, metaText.isNotEmpty ? metaText : null),
            _buildTableCell(
              '${cantidadUmp.toStringAsFixed(cantidadUmp.truncateToDouble() == cantidadUmp ? 0 : 2)} $ump (x$unidadesLote)',
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              'S/ ${costoUnitarioReal.toStringAsFixed(3)}',
              align: pw.TextAlign.right,
              textColor: _accentOrange,
              isBold: true,
            ),
            _buildTableCell(
              currencyFmt.format(totalPago),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: _accentGreen,
            ),
          ],
        ),
      );
    }

    // Fila final de totales
    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: _primaryLight,
          border: pw.Border(
            top: pw.BorderSide(color: _primaryColor, width: 1.5),
            bottom: pw.BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
        children: [
          _buildTableCell(''),
          _buildTableCell('TOTAL AUDITADO (${items.length} ÍTEMS)', isBold: true, textColor: _primaryColor),
          _buildTableCell(''),
          _buildTableCell(''),
          _buildTableCell(
            currencyFmt.format(totalAcumulado),
            align: pw.TextAlign.right,
            isBold: true,
            textColor: _primaryColor,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(28), // #
        1: pw.FlexColumnWidth(5.2), // Descripción / Producto Vinculado
        2: pw.FlexColumnWidth(2.2), // Compra (UMP)
        3: pw.FlexColumnWidth(2.0), // Costo Unit.
        4: pw.FlexColumnWidth(2.2), // Subtotal
      },
      children: tableRows,
    );
  }

  static pw.Widget _buildManualItemsTable(
    List<Map<String, dynamic>> presentations,
    NumberFormat currencyFmt,
  ) {
    double totalAcumulado = 0.0;

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _primaryColor),
        children: [
          _buildTableCell('#', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('PRODUCTO / PRESENTACIÓN VINCULADA', isHeader: true),
          _buildTableCell('CANTIDAD', isHeader: true, align: pw.TextAlign.center),
          _buildTableCell('COSTO UNIT.', isHeader: true, align: pw.TextAlign.right),
          _buildTableCell('SUBTOTAL', isHeader: true, align: pw.TextAlign.right),
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
            color: isEven ? PdfColors.white : _tableZebra,
          ),
          children: [
            _buildTableCell(correlative, align: pw.TextAlign.center, isBold: true),
            _buildProductWithSublinkCell(prodName, presName),
            _buildTableCell(
              stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 1),
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              currencyFmt.format(pCosto),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: _accentOrange,
            ),
            _buildTableCell(
              currencyFmt.format(subtotal),
              align: pw.TextAlign.right,
              isBold: true,
              textColor: _accentGreen,
            ),
          ],
        ),
      );
    }

    tableRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(
          color: _primaryLight,
          border: pw.Border(
            top: pw.BorderSide(color: _primaryColor, width: 1.5),
            bottom: pw.BorderSide(color: _primaryColor, width: 1.5),
          ),
        ),
        children: [
          _buildTableCell(''),
          _buildTableCell('TOTAL VINCULADO (${presentations.length} PRESENTACIONES)', isBold: true, textColor: _primaryColor),
          _buildTableCell(''),
          _buildTableCell(''),
          _buildTableCell(
            currencyFmt.format(totalAcumulado),
            align: pw.TextAlign.right,
            isBold: true,
            textColor: _primaryColor,
          ),
        ],
      ),
    );

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(28), // #
        1: pw.FlexColumnWidth(5.2), // Producto / Presentación
        2: pw.FlexColumnWidth(1.8), // Cantidad
        3: pw.FlexColumnWidth(2.2), // Costo Unit.
        4: pw.FlexColumnWidth(2.2), // Subtotal
      },
      children: tableRows,
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
              color: _secondaryColor,
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
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (textColor ?? _secondaryColor),
          letterSpacing: isHeader ? 0.4 : 0,
        ),
      ),
    );
  }

  static pw.Widget _buildEmptyTablePlaceholder() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _tableZebra,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor, width: 0.6),
      ),
      child: pw.Text(
        'Esta factura no contiene ítems de auditoría registrados.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }
}
