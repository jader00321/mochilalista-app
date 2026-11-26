import 'package:excel/excel.dart';

import '../core/time_utils.dart';
import '../database_service.dart';
import 'excel_styles.dart';

/// Constructores de hojas de detalle (`Cartera CRM`, `Libro de Pagos`,
/// `Equipos y Licencias`, `Guia y Glosario`) en zona horaria `America/Lima`.
class ExcelSheetsBuilder {
  ExcelSheetsBuilder._();

  /// Hoja 2: Cartera CRM (18 Columnas exactas `A..R`).
  static int buildCrmSheet(Sheet sheet, List<Map<String, dynamic>> clients) {
    final headers = [
      'ID',
      'Nombre Comercial',
      'Propietario',
      'RUC / DNI',
      'Teléfono WhatsApp',
      'Hardware ID (ANDROID_ID)',
      'Plan Actual',
      'Estado de Licencia',
      'Fecha de Vencimiento',
      'Días Restantes',
      'Ventana Updates',
      'Versión APK Instalada',
      'Créditos IA Acumulados',
      'Total Pagado (PEN)',
      'N.° de Pagos',
      'Último Token Emitido',
      'Notas y Acuerdos',
      'Próximo Seguimiento',
    ];

    final headerStyle = ExcelCorporateStyles.headerStyle();
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    final now = DateTime.now();
    int row = 1;

    for (final client in clients) {
      final plan = (client['license_type'] as String? ?? 'TRIAL').toUpperCase();
      final isProspect = plan == 'PROSPECTO' ||
          (client['license_status'] as String? ?? '').toUpperCase() ==
              'PROSPECTO';
      final isPerpetual = plan.contains('PERPETU');
      final expStr = client['license_expires'] as String?;
      final expDate = expStr != null ? DateTime.tryParse(expStr) : null;

      String normalizedStatus = 'ACTIVA';
      int daysRemaining = 0;

      if (isProspect) {
        normalizedStatus = 'PROSPECTO';
        daysRemaining = 0;
      } else if (isPerpetual) {
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

      CellStyle statusStyle;
      switch (normalizedStatus) {
        case 'PROSPECTO':
          statusStyle = ExcelCorporateStyles.statusProspectStyle();
          break;
        case 'ACTIVA':
          statusStyle = ExcelCorporateStyles.statusActiveStyle();
          break;
        case 'POR_VENCER':
          statusStyle = ExcelCorporateStyles.statusExpiringStyle();
          break;
        case 'VENCIDA':
          statusStyle = ExcelCorporateStyles.statusExpiredStyle();
          break;
        case 'PERPETUA':
          statusStyle = ExcelCorporateStyles.statusPerpetualStyle();
          break;
        default:
          statusStyle = ExcelCorporateStyles.statusActiveStyle();
      }

      final payments =
          (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      double totalPaid = 0.0;
      for (final p in payments) {
        totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final tokens = (client['generated_codes_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final lastToken =
          tokens.isNotEmpty ? (tokens.last['token'] as String? ?? '') : '';

      final reportedBalance = (client['ai_reported_balance'] as num?)?.toInt();
      final extraCredits = (client['ai_extra_credits'] as num?)?.toInt() ?? 0;
      final aiCredits = reportedBalance != null
          ? (reportedBalance + extraCredits)
          : ((client['ai_accumulated_credits'] as num?)?.toInt() ??
              extraCredits);

      final hwId = client['current_device_id'] as String? ?? '';
      final model = (client['device_model'] as String?)?.trim() ?? '';
      final hwDisplay = model.isNotEmpty ? '$hwId ($model)' : hwId;

      final pendingBonus = (client['ai_pending_bonus'] as num?)?.toInt() ?? 0;
      var notes = client['notes'] as String? ?? '';
      if (pendingBonus > 0) {
        notes = notes.isNotEmpty
            ? '$notes | [Bono IA pendiente: +$pendingBonus]'
            : '[Bono IA pendiente: +$pendingBonus]';
      }

      final followup = (client['next_followup_date'] as String?)?.trim();

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
        ..value = TextCellValue(hwDisplay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
        ..value = TextCellValue(plan);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
        ..value = TextCellValue(normalizedStatus)
        ..cellStyle = statusStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        ..value = TextCellValue(
          expDate != null
              ? PeruTimeHelper.formatLimaDate(expDate, fallback: '-')
              : '-',
        );
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        ..value = IntCellValue(daysRemaining);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        ..value = TextCellValue(
          client['updates_until'] != null
              ? PeruTimeHelper.formatLimaDate(
                  client['updates_until'],
                  fallback: '-',
                )
              : '-',
        );
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
        ..value = TextCellValue(notes);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 17, rowIndex: row))
        ..value = TextCellValue(
          (followup != null && followup.isNotEmpty) ? followup : '-',
        );

      row++;
    }

    const colWidths = [
      12.0, 32.0, 26.0, 16.0, 18.0, 20.0, 18.0, 16.0, 18.0,
      14.0, 16.0, 16.0, 18.0, 18.0, 12.0, 40.0, 30.0, 20.0,
    ];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    return row;
  }

  /// Hoja 3: Libro de Pagos (14 Columnas exactas `A..N`).
  static int buildPaymentsSheet(
    Sheet sheet,
    List<Map<String, dynamic>> payments,
    List<Map<String, dynamic>> clients,
  ) {
    final headers = [
      'ID Transacción',
      'Fecha y Hora',
      'ID Cliente',
      'Nombre Comercial',
      'Titular',
      'Concepto / Plan',
      'Días Otorgados',
      'Créditos IA Acreditados',
      'Medio de Pago',
      'N.° Operación / Referencia',
      'Monto Cobrado (PEN)',
      'Tipo Comprobante',
      'N.° Comprobante',
      'Última Edición',
    ];

    final headerStyle = ExcelCorporateStyles.headerStyle();
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
      final bName = (client['business_name'] as String?) ??
          (p['business_name'] as String?) ??
          '-';
      final oName = (client['owner_name'] as String?) ??
          (p['owner_name'] as String?) ??
          '-';
      final plan = p['plan'] as String? ?? 'MENSUAL';
      final days = (p['days_added'] as num?)?.toInt() ??
          DatabaseService.inferDefaultDaysForPlan(plan);
      final ai = (p['ai_extra_credits'] as num?)?.toInt() ??
          DatabaseService.inferDefaultAiForPlan(plan);
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final dateStr = p['date'] as String? ?? '';
      final dateDisplay =
          PeruTimeHelper.formatLimaDateTime(dateStr, fallback: '-');

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue(p['id'] as String? ?? 'PAY-$row');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        ..value = TextCellValue(dateDisplay);
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

      final ref = p['reference'] as String? ?? '-';
      final receiptNum = p['receipt_number'] as String?;
      final refDisplay =
          (receiptNum != null && receiptNum.isNotEmpty) ? '$ref | $receiptNum' : ref;

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
        ..value = TextCellValue(p['method'] as String? ?? 'Yape');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
        ..value = TextCellValue(refDisplay);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
        ..value = DoubleCellValue(amount);

      final recNum = (p['receipt_number'] as String? ?? '').trim();
      final recType = (p['receipt_type'] as String? ?? '').trim().toUpperCase();
      final tipoComprobante = recType == 'FAC' || recNum.startsWith('FAC')
          ? 'Factura'
          : (recType == 'BOL' || recNum.startsWith('BOL')
              ? 'Boleta'
              : 'Sin emitir');
      final numComprobante = recNum.isNotEmpty ? recNum : '-';
      final updatedAt = (p['updated_at'] as String? ?? '').trim();
      final updatedDisplay =
          PeruTimeHelper.formatLimaDateTime(updatedAt, fallback: '-');

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
        ..value = TextCellValue(tipoComprobante);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row))
        ..value = TextCellValue(numComprobante);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: row))
        ..value = TextCellValue(updatedDisplay);

      row++;
    }

    final dataEndRow = row;
    if (payments.isNotEmpty) {
      final totalRow = row + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: totalRow))
        ..value = TextCellValue('TOTAL RECAUDADO (PEN):')
        ..cellStyle = ExcelCorporateStyles.boldLabelStyle();
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: totalRow))
        ..value = FormulaCellValue('SUM(K2:K$dataEndRow)')
        ..cellStyle = ExcelCorporateStyles.boldLabelStyle();
    }

    const colWidths = [
      18.0, 22.0, 14.0, 32.0, 26.0, 18.0, 14.0,
      18.0, 16.0, 24.0, 20.0, 18.0, 18.0, 22.0,
    ];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    return dataEndRow;
  }

  /// Hoja 4: Equipos y Licencias (9 Columnas exactas `A..I`).
  static void buildHardwareHistorySheet(
    Sheet sheet,
    List<Map<String, dynamic>> clients,
  ) {
    final headers = [
      'Fecha de Migración',
      'ID Cliente',
      'Nombre Comercial',
      'Hardware ID Anterior (ANDROID_ID)',
      'Nuevo Hardware ID (ANDROID_ID)',
      'Tarifa Técnica (S/)',
      'Medio de Pago',
      'Motivo de la Migración',
      'Último Nonce Criptográfico',
    ];

    final headerStyle = ExcelCorporateStyles.headerStyle();
    for (int col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
        ..value = TextCellValue(headers[col])
        ..cellStyle = headerStyle;
    }

    int row = 1;
    for (final client in clients) {
      final history =
          (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();
      final nonce = (client['next_nonce'] as num?)?.toInt() ?? 1;

      for (final item in history) {
        final fee = (item['fee_charged'] as num?)?.toDouble() ?? 40.0;
        final dateStr = item['migrated_at'] as String? ?? '';
        final scenario = item['scenario'] as String?;
        final reason = item['reason'] as String? ?? 'Cambio de teléfono';
        final fullReason = (scenario != null && scenario.isNotEmpty)
            ? '[$scenario] $reason'
            : reason;

        final model = (item['device_model'] as String?)?.trim();
        final newHw = item['new_device_id'] as String? ?? '';
        final newHwDisplay =
            (model != null && model.isNotEmpty) ? '$newHw ($model)' : newHw;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue(
            PeruTimeHelper.formatLimaDateTime(dateStr, fallback: '-'),
          );
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          ..value = TextCellValue(client['id'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          ..value = TextCellValue(client['business_name'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          ..value = TextCellValue(item['old_device_id'] as String? ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          ..value = TextCellValue(newHwDisplay);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          ..value = DoubleCellValue(fee);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          ..value =
              TextCellValue(item['payment_method'] as String? ?? 'Yape');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          ..value = TextCellValue(fullReason);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          ..value = IntCellValue(nonce);

        row++;
      }
    }

    const colWidths = [22.0, 14.0, 32.0, 24.0, 24.0, 18.0, 16.0, 30.0, 16.0];
    for (int i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }
  }

  /// Hoja 5: Guia y Glosario Ejecutivo y Legal.
  static void buildGuideAndGlossarySheet(Sheet sheet) {
    final titleStyle = ExcelCorporateStyles.titleStyle();
    final sectionStyle = ExcelCorporateStyles.sectionHeaderStyle();
    final boldLabelStyle = ExcelCorporateStyles.boldLabelStyle();

    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('GUÍA DE INTERPRETACIÓN, GLOSARIO Y MARCO LEGAL')
      ..cellStyle = titleStyle;

    final glossary = [
      [
        '1. ESTADOS DE LICENCIA COMERCIAL',
        [
          [
            'ACTIVA',
            'Licencia al día y en vigencia. El comerciante cuenta con acceso 100% libre a todas las funciones comerciales y de inventario.',
          ],
          [
            'POR_VENCER',
            'Faltan 7 días o menos para la fecha de expiración. Se recomienda enviar recordatorio amistoso vía WhatsApp para renovación sin fricción.',
          ],
          [
            'VENCIDA',
            'Licencia expirada con 1 a 7 días de retraso (Bloqueo Suave). Permite lectura y cobro pero restringe creación masiva y alertas.',
          ],
          [
            'BLOQUEO_ESTRICTO',
            'Más de 7 días de vencimiento. Requiere canje de código de activación para desbloquear el punto de venta.',
          ],
          [
            'PENDIENTE_MIGRACION',
            'Base de datos restaurada en un teléfono con ANDROID_ID diferente. Los datos están 100% a salvo en modo lectura; requiere token de migración para reactivar.',
          ],
          [
            'PERPETUA',
            'Licencia adquirida de por vida (PERPETUO_LIBERADO). No vence jamás y recibe 12 meses de updates de nuevas funciones.',
          ],
        ]
      ],
      [
        '2. REGLA ESTRICTA DE RENOVACIÓN ACUMULATIVA',
        [
          [
            'Cero Pérdida de Días',
            'Al renovar una licencia activa antes de su vencimiento, los días adquiridos se suman a la fecha de expiración existente, nunca desde hoy.',
          ],
          [
            'Cuota IA Acumulativa',
            'Los créditos para escaneo de listas y comprobantes con Inteligencia Artificial no se resetean mensualmente; se acumulan de por vida en la bolsa del cliente.',
          ],
        ]
      ],
      [
        '3. HARDWARE IDENTIFIER (ANDROID_ID) Y SEGURIDAD OFFLINE',
        [
          [
            'Código ML-XXXX',
            'Identificador unívoco de instalación física derivado de Settings.Secure.ANDROID_ID. No accede a IMEI ni números de teléfono, garantizando privacidad total.',
          ],
          [
            'Firma Asimétrica Ed25519',
            'Los códigos de licencia son tokens criptográficos firmados por el autor. Funcionan 100% offline sin requerir conexión a internet en la bodega o librería.',
          ],
        ]
      ],
      [
        '4. MARCO LEGAL Y DERECHOS DE AUTOR',
        [
          [
            'D.L. 822 (Perú)',
            'Software MochilaLista y Plataforma Administrativa protegidos por la Ley sobre el Derecho de Autor e INDECOPI Perú.',
          ],
          [
            'Ley N° 29733',
            'Cumplimiento estricto de la Ley de Protección de Datos Personales de la República del Perú. Cero telemetría invasiva.',
          ],
          [
            'Titularidad',
            'Julio Angello Vasquez Navarro — Autor y Desarrollador Titular.',
          ],
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
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .cellStyle = sectionStyle;
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
}
