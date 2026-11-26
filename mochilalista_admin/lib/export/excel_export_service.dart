import 'dart:math' as math;

import 'package:excel/excel.dart';

import '../config/config_service.dart';
import '../core/commercial_constants.dart';
import '../core/time_utils.dart';
import '../database_service.dart';
import 'excel_sheets_builder.dart';
import 'excel_styles.dart';

/// Motor Exportador a Microsoft Excel Profesional Multi-Hoja (`.xlsx`).
class ExcelExportService {
  final DatabaseService dbService;
  final ConfigService configService;

  static const String sheetResumen = 'Resumen Ejecutivo'; // 17 chars
  static const String sheetCrm = 'Cartera CRM'; // 11 chars
  static const String sheetPagos = 'Libro de Pagos'; // 14 chars
  static const String sheetEquipos = 'Equipos y Licencias'; // 19 chars
  static const String sheetGuia = 'Guia y Glosario'; // 15 chars

  ExcelExportService({
    required this.dbService,
    required this.configService,
  });

  /// Genera el Libro Maestro de 5 Hojas Oficiales del entorno activo.
  Future<List<int>> generateMasterWorkbook() async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheetResumen);

    final clients = await dbService.getClients();
    final payments = await dbService.getConsolidatedFinances();

    final lastRowCrm = ExcelSheetsBuilder.buildCrmSheet(
      excel[sheetCrm],
      clients,
    );
    final lastRowPayments = ExcelSheetsBuilder.buildPaymentsSheet(
      excel[sheetPagos],
      payments,
      clients,
    );
    ExcelSheetsBuilder.buildHardwareHistorySheet(
      excel[sheetEquipos],
      clients,
    );

    _buildExecutiveSummarySheet(
      excel[sheetResumen],
      clientsCount: clients.length,
      lastRowCrm: lastRowCrm,
      paymentsCount: payments.length,
      lastRowPayments: lastRowPayments,
    );

    ExcelSheetsBuilder.buildGuideAndGlossarySheet(excel[sheetGuia]);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    return excel.encode() ?? [];
  }

  /// Genera el Reporte Financiero Filtrado por Rango de Fechas en hora Lima (GMT-5).
  Future<List<int>> generateFinancesReport({
    String? fromDate,
    String? toDate,
  }) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Resumen Contable');

    final clients = await dbService.getClients();
    var payments = await dbService.getConsolidatedFinances();

    if ((fromDate != null && fromDate.trim().isNotEmpty) ||
        (toDate != null && toDate.trim().isNotEmpty)) {
      payments = payments.where((p) {
        return PeruTimeHelper.isWithinLimaDateRange(
          p['date'],
          fromDate: fromDate,
          toDate: toDate,
        );
      }).toList();
    }

    final lastRowPayments = ExcelSheetsBuilder.buildPaymentsSheet(
      excel[sheetPagos],
      payments,
      clients,
    );

    _buildFinancesSummarySheet(
      excel['Resumen Contable'],
      paymentsCount: payments.length,
      lastRowPayments: lastRowPayments,
      fromDate: fromDate,
      toDate: toDate,
    );

    ExcelSheetsBuilder.buildGuideAndGlossarySheet(excel[sheetGuia]);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    return excel.encode() ?? [];
  }

  void _buildExecutiveSummarySheet(
    Sheet sheet, {
    required int clientsCount,
    required int lastRowCrm,
    required int paymentsCount,
    required int lastRowPayments,
  }) {
    final headerStyle = ExcelCorporateStyles.headerStyle();
    final titleStyle = ExcelCorporateStyles.titleStyle();
    final metaStyle = ExcelCorporateStyles.metaStyle();
    final sectionStyle = ExcelCorporateStyles.sectionHeaderStyle();
    final boldLabelStyle = ExcelCorporateStyles.boldLabelStyle();

    final crmRangeEnd = math.max(2, lastRowCrm);
    final payRangeEnd = math.max(2, lastRowPayments);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('MOCHILALISTA POS — REPORTE EJECUTIVO MAESTRO')
      ..cellStyle = titleStyle;

    final author = configService.legalIdentity['author_full_name'] ??
        CommercialConstants.defaultAuthorName;
    final modeLabel = dbService.currentMode == 'prod'
        ? 'PRODUCCIÓN REAL'
        : 'MODO PRUEBAS (SANDBOX)';
    final nowStr =
        '${PeruTimeHelper.formatLimaDateTime(DateTime.now())} (GMT-5)';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value =
          TextCellValue('Titular: $author | Entorno: $modeLabel | Emisión: $nowStr')
      ..cellStyle = metaStyle;

    int r = 3;
    _writeSectionBanner(
        sheet, r++, '1. KPIs GENERALES DE CARTERA (CRM)', sectionStyle);
    _writeTableHeaders(
      sheet,
      r++,
      const ['Métrica de Cartera', 'Cantidad de Clientes', 'Participación %'],
      headerStyle,
    );

    final crmStartRow = r + 1;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Clientes Registrados')
      ..cellStyle = boldLabelStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTA('$sheetCrm'!A2:A$crmRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = DoubleCellValue(1.0);
    r++;

    for (final item in const [
      ['Clientes Activos (Al día)', 'ACTIVA'],
      ['Por Vencer (≤ 7 días)', 'POR_VENCER'],
      ['Vencidos / Bloqueo Suave', 'VENCIDA'],
      ['Licencias Perpetuas Liberadas', 'PERPETUA'],
    ]) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(item[0]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = FormulaCellValue(
            "COUNTIF('$sheetCrm'!H2:H$crmRangeEnd, \"${item[1]}\")");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = FormulaCellValue('IFERROR(B$r/B$crmStartRow, 0)');
      r++;
    }

    r++;
    _writeSectionBanner(
        sheet, r++, '2. RESUMEN FINANCIERO Y COBRANZAS', sectionStyle);
    _writeTableHeaders(
      sheet,
      r++,
      const ['Indicador Financiero', 'Valor Calculado', 'Unidad'],
      headerStyle,
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Recaudación Total Acumulada')
      ..cellStyle = boldLabelStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("SUM('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN (S/)');
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Transacciones Cobradas');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNT('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Operaciones');
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Ticket Promedio por Cobro');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value =
          FormulaCellValue("IFERROR(AVERAGE('$sheetPagos'!K2:K$payRangeEnd), 0)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN / Pago');
    r++;

    r++;
    _writeSectionBanner(sheet, r++, '3. DESGLOSE POR MEDIO DE PAGO', sectionStyle);
    _writeTableHeaders(
      sheet,
      r++,
      const ['Medio de Pago', 'N.° Cobros', 'Monto Total (S/)'],
      headerStyle,
    );
    r = _writePaymentMethodBreakdown(sheet, r, payRangeEnd);

    r++;
    _writeSectionBanner(sheet, r++, '4. DESGLOSE POR PLAN COMERCIAL', sectionStyle);
    _writeTableHeaders(
      sheet,
      r++,
      const ['Plan / Producto', 'Clientes Asignados', 'Tarifa Referencial'],
      headerStyle,
    );

    for (final p in CommercialConstants.masterExcelPlanOrder) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(p);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = FormulaCellValue("COUNTIF('$sheetCrm'!G2:G$crmRangeEnd, \"$p\")");

      if (p == 'BONO_IA_PERSONALIZADO' || p == 'ABONO_PARCIAL') {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
          ..value = TextCellValue('Variable');
      } else {
        final double price;
        if (p == 'SERVICIO_MIGRACION') {
          price = configService.getPlanPrice(
            'HARDWARE_MIGRATION_FEE',
            fallback: 40.0,
          );
        } else if (p == 'RECARGA_IA_150') {
          price = configService.getPlanPrice('RECARGA_IA_150', fallback: 20.0);
        } else if (p == 'PASE_ACTUALIZACION_ANUAL') {
          price = configService.getPlanPrice(
            'PASE_ACTUALIZACION_ANUAL',
            fallback: 150.0,
          );
        } else {
          price = configService.getPlanPrice(p, fallback: 0.0);
        }
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
          ..value = DoubleCellValue(price);
      }
      r++;
    }

    sheet.setColumnWidth(0, 36.0);
    sheet.setColumnWidth(1, 24.0);
    sheet.setColumnWidth(2, 20.0);
  }

  void _buildFinancesSummarySheet(
    Sheet sheet, {
    required int paymentsCount,
    required int lastRowPayments,
    String? fromDate,
    String? toDate,
  }) {
    final titleStyle = ExcelCorporateStyles.titleStyle();
    final metaStyle = ExcelCorporateStyles.metaStyle();
    final sectionStyle = ExcelCorporateStyles.sectionHeaderStyle();
    final headerStyle = ExcelCorporateStyles.headerStyle();
    final boldLabelStyle = ExcelCorporateStyles.boldLabelStyle();

    final payRangeEnd = math.max(2, lastRowPayments);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('MOCHILALISTA POS — REPORTE FINANCIERO Y CONTABLE')
      ..cellStyle = titleStyle;

    final filterText = (fromDate != null || toDate != null)
        ? 'Filtro: ${fromDate ?? "Inicio"} hasta ${toDate ?? "Hoy"}'
        : 'Periodo: Histórico Completo';
    final nowStr =
        '${PeruTimeHelper.formatLimaDateTime(DateTime.now())} (GMT-5)';

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('$filterText | Emisión: $nowStr')
      ..cellStyle = metaStyle;

    int r = 3;
    _writeSectionBanner(
        sheet, r++, 'RESUMEN DE COBRANZAS DEL PERIODO', sectionStyle);
    _writeTableHeaders(
      sheet,
      r++,
      const ['Indicador', 'Monto / Cantidad', 'Detalle'],
      headerStyle,
    );

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Recaudado en Periodo')
      ..cellStyle = boldLabelStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("SUM('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN (S/)');
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Transacciones Cobradas');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNT('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Cobros');
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Ticket Promedio del Periodo');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value =
          FormulaCellValue("IFERROR(AVERAGE('$sheetPagos'!K2:K$payRangeEnd), 0)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN / Operación');
    r++;

    r++;
    _writeSectionBanner(
      sheet,
      r++,
      'DESGLOSE POR MEDIO DE PAGO DEL PERIODO',
      sectionStyle,
    );
    _writeTableHeaders(
      sheet,
      r++,
      const ['Medio de Pago', 'N.° Cobros', 'Monto Total (S/)'],
      headerStyle,
    );
    _writePaymentMethodBreakdown(sheet, r, payRangeEnd);

    sheet.setColumnWidth(0, 36.0);
    sheet.setColumnWidth(1, 24.0);
    sheet.setColumnWidth(2, 20.0);
  }

  void _writeSectionBanner(
    Sheet sheet,
    int row,
    String title,
    CellStyle sectionStyle,
  ) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(title)
      ..cellStyle = sectionStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .cellStyle = sectionStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .cellStyle = sectionStyle;
  }

  void _writeTableHeaders(
    Sheet sheet,
    int row,
    List<String> titles,
    CellStyle headerStyle,
  ) {
    for (int c = 0; c < titles.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
        ..value = TextCellValue(titles[c])
        ..cellStyle = headerStyle;
    }
  }

  int _writePaymentMethodBreakdown(Sheet sheet, int startRow, int payRangeEnd) {
    int r = startRow;
    for (final pm in const ['Yape', 'Plin', 'BCP', 'BBVA', 'Efectivo']) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(pm);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = FormulaCellValue(
            "COUNTIF('$sheetPagos'!I2:I$payRangeEnd, \"$pm\")");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = FormulaCellValue(
            "SUMIF('$sheetPagos'!I2:I$payRangeEnd, \"$pm\", '$sheetPagos'!K2:K$payRangeEnd)");
      r++;
    }
    return r;
  }
}
