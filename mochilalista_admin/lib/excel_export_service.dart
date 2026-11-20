import 'dart:math' as math;
import 'package:excel/excel.dart';
import 'database_service.dart';
import 'config_service.dart';

/// Motor Exportador a Microsoft Excel Profesional Multi-Hoja (.xlsx)
/// (Plan Maestro 09 - Pilar 4)
/// Genera libros de cálculo empresariales con 5 hojas oficiales (≤ 31 caracteres),
/// fórmulas dinámicas nativas (FormulaCellValue), estilos corporativos y protección #DIV/0!.
class ExcelExportService {
  final DatabaseService dbService;
  final ConfigService configService;

  // Nombres canónicos de las 5 hojas oficiales (límite estricto ≤ 31 caracteres)
  static const String sheetResumen = 'Resumen Ejecutivo'; // 17 chars
  static const String sheetCrm = 'Cartera CRM'; // 11 chars
  static const String sheetPagos = 'Libro de Pagos'; // 14 chars
  static const String sheetEquipos = 'Equipos y Licencias'; // 19 chars
  static const String sheetGuia = 'Guia y Glosario'; // 15 chars

  ExcelExportService({
    required this.dbService,
    required this.configService,
  });

  /// Genera el Libro Maestro de 5 Hojas Oficiales con el 100% de los datos del entorno activo
  Future<List<int>> generateMasterWorkbook() async {
    final excel = Excel.createExcel();

    // Renombrar Sheet1 por defecto a 'Resumen Ejecutivo' para garantizar orden exacto
    excel.rename('Sheet1', sheetResumen);

    final clients = await dbService.getClients();
    final payments = await dbService.getConsolidatedFinances();

    // 1. Hoja 2: Cartera CRM
    final lastRowCrm = _buildCrmSheet(excel[sheetCrm], clients);

    // 2. Hoja 3: Libro de Pagos
    final lastRowPayments = _buildPaymentsSheet(excel[sheetPagos], payments, clients);

    // 3. Hoja 4: Equipos y Licencias
    _buildHardwareHistorySheet(excel[sheetEquipos], clients);

    // 4. Hoja 1: Resumen Ejecutivo (utiliza los rangos exactos de CRM y Pagos)
    _buildExecutiveSummarySheet(
      excel[sheetResumen],
      clientsCount: clients.length,
      lastRowCrm: lastRowCrm,
      paymentsCount: payments.length,
      lastRowPayments: lastRowPayments,
    );

    // 5. Hoja 5: Guia y Glosario
    _buildGuideAndGlossarySheet(excel[sheetGuia]);

    // Eliminar Sheet1 si por alguna razón persistiera
    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    return bytes ?? [];
  }

  /// Genera el Reporte Financiero Filtrado por Rango de Fechas
  Future<List<int>> generateFinancesReport({String? fromDate, String? toDate}) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Resumen Contable');

    final clients = await dbService.getClients();
    var payments = await dbService.getConsolidatedFinances();

    DateTime? from;
    DateTime? to;
    if (fromDate != null && fromDate.isNotEmpty) {
      from = DateTime.tryParse(fromDate);
    }
    if (toDate != null && toDate.isNotEmpty) {
      to = DateTime.tryParse(toDate);
    }

    if (from != null || to != null) {
      payments = payments.where((p) {
        final pDateStr = p['date'] as String?;
        if (pDateStr == null) return false;
        final pDate = DateTime.tryParse(pDateStr);
        if (pDate == null) return false;
        if (from != null && pDate.isBefore(from)) return false;
        if (to != null && pDate.isAfter(to.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
    }

    // Hoja Pagos
    final lastRowPayments = _buildPaymentsSheet(excel[sheetPagos], payments, clients);

    // Hoja Resumen Contable
    _buildFinancesSummarySheet(
      excel['Resumen Contable'],
      paymentsCount: payments.length,
      lastRowPayments: lastRowPayments,
      fromDate: fromDate,
      toDate: toDate,
    );

    // Hoja Guía
    _buildGuideAndGlossarySheet(excel[sheetGuia]);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    return bytes ?? [];
  }

  // =========================================================================
  // CONSTRUCTORES DE HOJAS INDIVIDUALES
  // =========================================================================

  /// Hoja 1: Resumen Ejecutivo
  void _buildExecutiveSummarySheet(
    Sheet sheet, {
    required int clientsCount,
    required int lastRowCrm,
    required int paymentsCount,
    required int lastRowPayments,
  }) {
    final headerStyle = _headerStyle();
    final titleStyle = _titleStyle();
    final metaStyle = _metaStyle();
    final sectionStyle = _sectionHeaderStyle();
    final boldLabelStyle = _boldLabelStyle();

    // Rango seguro: mínimo fila 2 para evitar errores de sintaxis en hojas vacías
    final crmRangeEnd = math.max(2, lastRowCrm);
    final payRangeEnd = math.max(2, lastRowPayments);

    // Título y Metadatos
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('MOCHILALISTA POS — REPORTE EJECUTIVO MAESTRO')
      ..cellStyle = titleStyle;

    final author = configService.legalIdentity['author_full_name'] ?? 'Julio Angello Vasquez Navarro';
    final modeLabel = dbService.currentMode == 'prod' ? 'PRODUCCIÓN REAL' : 'MODO PRUEBAS (SANDBOX)';
    final nowStr = DateTime.now().toLocal().toString().split('.').first;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('Titular: $author | Entorno: $modeLabel | Emisión: $nowStr')
      ..cellStyle = metaStyle;

    // -------------------------------------------------------------
    // Sección 1: KPIs Generales de Cartera (CRM)
    // -------------------------------------------------------------
    int r = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('1. KPIs GENERALES DE CARTERA (CRM)')
      ..cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = sectionStyle;
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Métrica de Cartera')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = TextCellValue('Cantidad de Clientes')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Participación %')
      ..cellStyle = headerStyle;
    r++;

    final crmStartRow = r + 1; // Para fórmula de participación

    // Total Clientes
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Clientes Registrados')
      ..cellStyle = boldLabelStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTA('$sheetCrm'!A2:A$crmRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = DoubleCellValue(1.0);
    r++;

    // Activos
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Clientes Activos (Al día)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTIF('$sheetCrm'!H2:H$crmRangeEnd, \"ACTIVA\")");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = FormulaCellValue('IFERROR(B$r/B$crmStartRow, 0)');
    r++;

    // Por Vencer
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Por Vencer (≤ 7 días)');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTIF('$sheetCrm'!H2:H$crmRangeEnd, \"POR_VENCER\")");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = FormulaCellValue('IFERROR(B$r/B$crmStartRow, 0)');
    r++;

    // Vencidos
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Vencidos / Bloqueo Suave');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTIF('$sheetCrm'!H2:H$crmRangeEnd, \"VENCIDA\")");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = FormulaCellValue('IFERROR(B$r/B$crmStartRow, 0)');
    r++;

    // Perpetuos
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Licencias Perpetuas Liberadas');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNTIF('$sheetCrm'!H2:H$crmRangeEnd, \"PERPETUA\")");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = FormulaCellValue('IFERROR(B$r/B$crmStartRow, 0)');
    r++;

    // -------------------------------------------------------------
    // Sección 2: Resumen Financiero y Recaudación
    // -------------------------------------------------------------
    r++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('2. RESUMEN FINANCIERO Y COBRANZAS')
      ..cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = sectionStyle;
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Indicador Financiero')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = TextCellValue('Valor Calculado')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Unidad')
      ..cellStyle = headerStyle;
    r++;

    // Total Cobrado
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Recaudación Total Acumulada')
      ..cellStyle = boldLabelStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("SUM('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN (S/)');
    r++;

    // N.° Pagos
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Total Transacciones Cobradas');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("COUNT('$sheetPagos'!K2:K$payRangeEnd)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Operaciones');
    r++;

    // Ticket Promedio
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Ticket Promedio por Cobro');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = FormulaCellValue("IFERROR(AVERAGE('$sheetPagos'!K2:K$payRangeEnd), 0)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN / Pago');
    r++;

    // -------------------------------------------------------------
    // Sección 3: Desglose por Medio de Pago
    // -------------------------------------------------------------
    r++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('3. DESGLOSE POR MEDIO DE PAGO')
      ..cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = sectionStyle;
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Medio de Pago')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = TextCellValue('N.° Cobros')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Monto Total (S/)')
      ..cellStyle = headerStyle;
    r++;

    final paymentMethods = ['Yape', 'Plin', 'BCP', 'BBVA', 'Efectivo'];
    for (final pm in paymentMethods) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(pm);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = FormulaCellValue("COUNTIF('$sheetPagos'!I2:I$payRangeEnd, \"$pm\")");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = FormulaCellValue("SUMIF('$sheetPagos'!I2:I$payRangeEnd, \"$pm\", '$sheetPagos'!K2:K$payRangeEnd)");
      r++;
    }

    // -------------------------------------------------------------
    // Sección 4: Desglose por Plan Comercial
    // -------------------------------------------------------------
    r++;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('4. DESGLOSE POR PLAN COMERCIAL')
      ..cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = sectionStyle;
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Plan / Producto')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = TextCellValue('Clientes Asignados')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Tarifa Referencial')
      ..cellStyle = headerStyle;
    r++;

    final plans = [
      'TRIAL',
      'MENSUAL',
      'TRIMESTRAL',
      'SEMESTRAL',
      'ANUAL',
      'PERPETUO_LIBERADO',
      'PASE_ACTUALIZACION_ANUAL',
    ];
    for (final p in plans) {
      final price = configService.getPlanPrice(p);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(p);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = FormulaCellValue("COUNTIF('$sheetCrm'!G2:G$crmRangeEnd, \"$p\")");
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = DoubleCellValue(price);
      r++;
    }

    // Auto-ajuste de anchos de columna
    sheet.setColumnWidth(0, 36.0);
    sheet.setColumnWidth(1, 24.0);
    sheet.setColumnWidth(2, 20.0);
  }

  /// Hoja 2: Cartera CRM (17 Columnas exactas A..Q)
  int _buildCrmSheet(Sheet sheet, List<Map<String, dynamic>> clients) {
    final headers = [
      'ID', // A
      'Nombre Comercial', // B
      'Propietario', // C
      'RUC / DNI', // D
      'Teléfono WhatsApp', // E
      'Hardware ID (ANDROID_ID)', // F
      'Plan Actual', // G
      'Estado de Licencia', // H (ACTIVA, POR_VENCER, VENCIDA, PERPETUA)
      'Fecha de Vencimiento', // I
      'Días Restantes', // J
      'Ventana Updates', // K
      'Versión APK Instalada', // L
      'Créditos IA Acumulados', // M
      'Total Pagado (PEN)', // N
      'N.° de Pagos', // O
      'Último Token Emitido', // P
      'Notas y Acuerdos', // Q
    ];

    final headerStyle = _headerStyle();
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    final now = DateTime.now();
    int row = 1;

    for (final client in clients) {
      final plan = (client['license_type'] as String? ?? 'TRIAL').toUpperCase();
      final isPerpetual = plan.contains('PERPETU');
      final expStr = client['license_expires'] as String?;
      final expDate = expStr != null ? DateTime.tryParse(expStr) : null;

      String normalizedStatus = 'ACTIVA';
      int daysRemaining = 0;

      if (isPerpetual) {
        normalizedStatus = 'PERPETUA';
        daysRemaining = 99999;
      } else if (expDate != null) {
        daysRemaining = expDate.difference(now).inDays;
        if (expDate.isBefore(now)) {
          normalizedStatus = 'VENCIDA';
        } else if (daysRemaining <= 7) {
          normalizedStatus = 'POR_VENCER';
        } else {
          normalizedStatus = 'ACTIVA';
        }
      }

      // Estilo semántico según estado
      CellStyle statusStyle;
      switch (normalizedStatus) {
        case 'ACTIVA':
          statusStyle = _statusActiveStyle();
          break;
        case 'POR_VENCER':
          statusStyle = _statusExpiringStyle();
          break;
        case 'VENCIDA':
          statusStyle = _statusExpiredStyle();
          break;
        case 'PERPETUA':
          statusStyle = _statusPerpetualStyle();
          break;
        default:
          statusStyle = _statusActiveStyle();
      }

      // Historial de pagos
      final payments = (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      double totalPaid = 0.0;
      for (final p in payments) {
        totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Tokens
      final tokens = (client['generated_codes_history'] as List? ?? []).cast<Map<String, dynamic>>();
      final lastToken = tokens.isNotEmpty ? (tokens.last['token'] as String? ?? '') : '';

      final aiCredits = (client['ai_accumulated_credits'] as num?)?.toInt() ??
          (client['ai_extra_credits'] as num?)?.toInt() ??
          0;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(client['id'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = TextCellValue(client['business_name'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = TextCellValue(client['owner_name'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        ..value = TextCellValue(client['document_id'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        ..value = TextCellValue(client['phone'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        ..value = TextCellValue(client['current_device_id'] as String? ?? '');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        ..value = TextCellValue(plan);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        ..value = TextCellValue(normalizedStatus)
        ..cellStyle = statusStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        ..value = TextCellValue(expDate != null ? expDate.toLocal().toString().split(' ').first : '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        ..value = IntCellValue(daysRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        ..value = TextCellValue(client['updates_until'] != null ? (client['updates_until'] as String).split('T').first : '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        ..value = TextCellValue(client['installed_version'] as String? ?? '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
        ..value = IntCellValue(aiCredits);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row))
        ..value = DoubleCellValue(totalPaid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 14, rowIndex: row))
        ..value = IntCellValue(payments.length);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 15, rowIndex: row))
        ..value = TextCellValue(lastToken);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 16, rowIndex: row))
        ..value = TextCellValue(client['notes'] as String? ?? '');

      row++;
    }

    // Anchos de columna precalculados
    final colWidths = [12.0, 32.0, 26.0, 16.0, 18.0, 20.0, 18.0, 16.0, 18.0, 14.0, 16.0, 16.0, 18.0, 18.0, 12.0, 40.0, 30.0];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    return row; // Última fila ocupada (1-indexed para Excel)
  }

  /// Hoja 3: Libro de Pagos (11 Columnas exactas A..K)
  int _buildPaymentsSheet(
    Sheet sheet,
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> clients,
  ) {
    final headers = [
      'ID Transacción', // A
      'Fecha y Hora', // B
      'ID Cliente', // C
      'Nombre Comercial', // D
      'Titular', // E
      'Concepto / Plan', // F
      'Días Otorgados', // G
      'Créditos IA Acreditados', // H
      'Medio de Pago', // I
      'N.° Operación / Referencia', // J
      'Monto Cobrado (PEN)', // K
    ];

    final headerStyle = _headerStyle();
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    final clientMap = {for (final c in clients) (c['id'] as String? ?? ''): c};
    int row = 1;

    for (final p in payments) {
      final cid = p['client_id'] as String? ?? '';
      final client = clientMap[cid] ?? {};
      final bName = (client['business_name'] as String?) ?? (p['business_name'] as String?) ?? '-';
      final oName = (client['owner_name'] as String?) ?? (p['owner_name'] as String?) ?? '-';
      final plan = p['plan'] as String? ?? 'MENSUAL';
      final days = (p['days_added'] as num?)?.toInt() ?? configService.getPlanDays(plan, fallback: 30);
      final ai = (p['ai_extra_credits'] as num?)?.toInt() ?? configService.getPlanAiCredits(plan, fallback: 0);
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final dateStr = p['date'] as String? ?? '';

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(p['id'] as String? ?? 'PAY-$row');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = TextCellValue(dateStr.isNotEmpty ? dateStr.replaceFirst('T', ' ').split('.').first : '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        ..value = TextCellValue(cid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        ..value = TextCellValue(bName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        ..value = TextCellValue(oName);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        ..value = TextCellValue(plan);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        ..value = IntCellValue(days);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        ..value = IntCellValue(ai);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        ..value = TextCellValue(p['method'] as String? ?? 'Yape');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        ..value = TextCellValue(p['reference'] as String? ?? '-');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        ..value = DoubleCellValue(amount);

      row++;
    }

    final dataEndRow = row; // Fila final de datos reales (sin incluir el total)

    // Fila final de resumen / total recaudado (solo si hay transacciones)
    if (payments.isNotEmpty) {
      final totalRow = row + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRow))
        ..value = TextCellValue('TOTAL RECAUDADO (PEN):')
        ..cellStyle = _boldLabelStyle();
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: totalRow))
        ..value = FormulaCellValue('SUM(K2:K$dataEndRow)')
        ..cellStyle = _boldLabelStyle();
    }

    final colWidths = [18.0, 22.0, 14.0, 32.0, 26.0, 18.0, 14.0, 18.0, 16.0, 24.0, 20.0];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    return dataEndRow;
  }

  /// Hoja 4: Equipos y Licencias (9 Columnas A..I)
  void _buildHardwareHistorySheet(Sheet sheet, List<Map<String, dynamic>> clients) {
    final headers = [
      'Fecha de Migración', // A
      'ID Cliente', // B
      'Nombre Comercial', // C
      'Hardware ID Anterior (ANDROID_ID)', // D
      'Nuevo Hardware ID (ANDROID_ID)', // E
      'Tarifa Técnica (S/)', // F
      'Medio de Pago', // G
      'Motivo de la Migración', // H
      'Último Nonce Criptográfico', // I
    ];

    final headerStyle = _headerStyle();
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    int row = 1;
    for (final client in clients) {
      final history = (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
      final nonce = (client['next_nonce'] as num?)?.toInt() ?? 1;

      for (final item in history) {
        final fee = (item['fee_charged'] as num?)?.toDouble() ?? 40.0;
        final dateStr = item['migrated_at'] as String? ?? '';

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue(dateStr.isNotEmpty ? dateStr.replaceFirst('T', ' ').split('.').first : '-');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          ..value = TextCellValue(client['id'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          ..value = TextCellValue(client['business_name'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          ..value = TextCellValue(item['old_device_id'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          ..value = TextCellValue(item['new_device_id'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          ..value = DoubleCellValue(fee);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          ..value = TextCellValue(item['payment_method'] as String? ?? 'Yape');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          ..value = TextCellValue(item['reason'] as String? ?? 'Cambio de teléfono');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          ..value = IntCellValue(nonce);

        row++;
      }
    }

    final colWidths = [22.0, 14.0, 32.0, 24.0, 24.0, 18.0, 16.0, 30.0, 16.0];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }
  }

  /// Hoja 5: Guia y Glosario Ejecutivo y Legal
  void _buildGuideAndGlossarySheet(Sheet sheet) {
    final titleStyle = _titleStyle();
    final sectionStyle = _sectionHeaderStyle();
    final boldLabelStyle = _boldLabelStyle();

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('GUÍA DE INTERPRETACIÓN, GLOSARIO Y MARCO LEGAL')
      ..cellStyle = titleStyle;

    final glossary = [
      [
        '1. ESTADOS DE LICENCIA COMERCIAL',
        [
          ['ACTIVA', 'Licencia al día y en vigencia. El comerciante cuenta con acceso 100% libre a todas las funciones comerciales y de inventario.'],
          ['POR_VENCER', 'Faltan 7 días o menos para la fecha de expiración. Se recomienda enviar recordatorio amistoso vía WhatsApp para renovación sin fricción.'],
          ['VENCIDA', 'Licencia expirada con 1 a 7 días de retraso (Bloqueo Suave). Permite lectura y cobro pero restringe creación masiva y alertas.'],
          ['BLOQUEO_ESTRICTO', 'Más de 7 días de vencimiento. Requiere canje de código de activación para desbloquear el punto de venta.'],
          ['PENDIENTE_MIGRACION', 'Base de datos restaurada en un teléfono con ANDROID_ID diferente. Los datos están 100% a salvo en modo lectura; requiere token de migración para reactivar.'],
          ['PERPETUA', 'Licencia adquirida de por vida (PERPETUO_LIBERADO). No vence jamás y recibe 12 meses de updates de nuevas funciones.'],
        ]
      ],
      [
        '2. REGLA ESTRICTA DE RENOVACIÓN ACUMULATIVA',
        [
          ['Cero Pérdida de Días', 'Al renovar una licencia activa antes de su vencimiento, los días adquiridos se suman a la fecha de expiración existente, nunca desde hoy.'],
          ['Cuota IA Acumulativa', 'Los créditos para escaneo de listas y comprobantes con Inteligencia Artificial no se resetean mensualmente; se acumulan de por vida en la bolsa del cliente.'],
        ]
      ],
      [
        '3. HARDWARE IDENTIFIER (ANDROID_ID) Y SEGURIDAD OFFLINE',
        [
          ['Código ML-XXXX', 'Identificador unívoco de instalación física derivado de Settings.Secure.ANDROID_ID. No accede a IMEI ni números de teléfono, garantizando privacidad total.'],
          ['Firma Asimétrica Ed25519', 'Los códigos de licencia son tokens criptográficos firmados por el autor. Funcionan 100% offline sin requerir conexión a internet en la bodega o librería.'],
        ]
      ],
      [
        '4. MARCO LEGAL Y DERECHOS DE AUTOR',
        [
          ['D.L. 822 (Perú)', 'Software MochilaLista y Plataforma Administrativa protegidos por la Ley sobre el Derecho de Autor e INDECOPI Perú.'],
          ['Ley N° 29733', 'Cumplimiento estricto de la Ley de Protección de Datos Personales de la República del Perú. Cero telemetría invasiva.'],
          ['Titularidad', 'Julio Angello Vasquez Navarro — Autor y Desarrollador Titular.'],
        ]
      ]
    ];

    int row = 2;
    for (final section in glossary) {
      final secTitle = section[0] as String;
      final items = section[1] as List<List<String>>;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(secTitle)
        ..cellStyle = sectionStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).cellStyle = sectionStyle;
      row++;

      for (final item in items) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue(item[0])
          ..cellStyle = boldLabelStyle;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          ..value = TextCellValue(item[1]);
        row++;
      }
      row++;
    }

    sheet.setColumnWidth(0, 32.0);
    sheet.setColumnWidth(1, 80.0);
  }

  /// Hoja Resumen Contable para Reporte Financiero Filtrado
  void _buildFinancesSummarySheet(
    Sheet sheet, {
    required int paymentsCount,
    required int lastRowPayments,
    String? fromDate,
    String? toDate,
  }) {
    final titleStyle = _titleStyle();
    final metaStyle = _metaStyle();
    final sectionStyle = _sectionHeaderStyle();
    final headerStyle = _headerStyle();
    final boldLabelStyle = _boldLabelStyle();

    final payRangeEnd = math.max(2, lastRowPayments);

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('MOCHILALISTA POS — REPORTE FINANCIERO Y CONTABLE')
      ..cellStyle = titleStyle;

    final filterText = (fromDate != null || toDate != null)
        ? 'Filtro: ${fromDate ?? "Inicio"} hasta ${toDate ?? "Hoy"}'
        : 'Periodo: Histórico Completo';
    final nowStr = DateTime.now().toLocal().toString().split('.').first;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('$filterText | Emisión: $nowStr')
      ..cellStyle = metaStyle;

    int r = 3;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('RESUMEN DE COBRANZAS DEL PERIODO')
      ..cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r)).cellStyle = sectionStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r)).cellStyle = sectionStyle;
    r++;

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue('Indicador')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = TextCellValue('Monto / Cantidad')
      ..cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('Detalle')
      ..cellStyle = headerStyle;
    r++;

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
      ..value = FormulaCellValue("IFERROR(AVERAGE('$sheetPagos'!K2:K$payRangeEnd), 0)");
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = TextCellValue('PEN / Operación');
    r++;

    sheet.setColumnWidth(0, 36.0);
    sheet.setColumnWidth(1, 24.0);
    sheet.setColumnWidth(2, 20.0);
  }

  // =========================================================================
  // ESTILOS CORPORATIVOS REUTILIZABLES
  // =========================================================================

  CellStyle _titleStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF1E3A8A'), // Navy
      bold: true,
      fontSize: 14,
    );
  }

  CellStyle _metaStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF475569'), // Slate
      italic: true,
      fontSize: 10,
    );
  }

  CellStyle _sectionHeaderStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF0F766E'), // Teal
      bold: true,
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
    );
  }

  CellStyle _headerStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('FF1E3A8A'), // Navy
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );
  }

  CellStyle _boldLabelStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('FF0F172A'),
    );
  }

  CellStyle _statusActiveStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF166534'), // Green 800
      backgroundColorHex: ExcelColor.fromHexString('FFDCFCE7'), // Green 100
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellStyle _statusExpiringStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF854D0E'), // Amber 800
      backgroundColorHex: ExcelColor.fromHexString('FFFEF3C7'), // Amber 100
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellStyle _statusExpiredStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF991B1B'), // Red 800
      backgroundColorHex: ExcelColor.fromHexString('FFFEE2E2'), // Red 100
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  CellStyle _statusPerpetualStyle() {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('FF581C87'), // Purple 800
      backgroundColorHex: ExcelColor.fromHexString('FFF3E8FF'), // Purple 100
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }
}
