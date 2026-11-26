part of 'database_service.dart';

class _FinancesExportHelper {
  _FinancesExportHelper._();

  static int inferDefaultDaysForPlan(String? rawPlan) {
    final norm = (rawPlan ?? '').toUpperCase().trim();
    if (norm.isEmpty || norm == '-') return 0;
    if (norm == 'SERVICIO_MIGRACION' ||
        norm == 'HARDWARE_MIGRATION_FEE' ||
        norm == 'ABONO_PARCIAL' ||
        norm == 'RECARGA_IA_150' ||
        norm == 'PASE_ACTUALIZACION_ANUAL' ||
        norm == 'PASE_ANUAL_UPDATES' ||
        norm == 'PASE_UPDATES_12M' ||
        norm == 'BONO_IA_PERSONALIZADO' ||
        norm == 'PAGO_MANUAL') {
      return 0;
    }
    if (norm == 'EXTENSION_CORTESIA') return 7;
    if (norm == 'TRIAL' || norm == 'MENSUAL') return 30;
    if (norm == 'TRIMESTRAL') return 90;
    if (norm == 'SEMESTRAL') return 180;
    if (norm == 'ANUAL') return 365;
    if (norm.contains('PERPETU')) return 99999;
    return 0;
  }

  static int inferDefaultAiForPlan(String? rawPlan) {
    final norm = (rawPlan ?? '').toUpperCase().trim();
    if (norm.isEmpty ||
        norm == 'SERVICIO_MIGRACION' ||
        norm == 'HARDWARE_MIGRATION_FEE' ||
        norm == 'ABONO_PARCIAL' ||
        norm == 'EXTENSION_CORTESIA' ||
        norm == 'PAGO_MANUAL' ||
        norm == 'BONO_IA_PERSONALIZADO') {
      return 0;
    }
    return LicenseSigner.getCumulativeScansForPlan(norm);
  }
}

/// Repositorio de finanzas consolidadas, historial individual y exportaciones CSV RFC-4180.
mixin _FinancesExportRepositoryMixin on _DatabaseServiceBase {
  /// Obtiene la lista consolidada de cobros/transacciones financieras del entorno activo.
  Future<List<Map<String, dynamic>>> getConsolidatedFinances() async {
    final clients = await getClients();
    final List<Map<String, dynamic>> result = [];
    for (final c in clients) {
      final payments =
          (c['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      final codes = (c['generated_codes_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final codeByPaymentId = <String, Map<String, dynamic>>{};
      for (final code in codes) {
        final payId = code['payment_id']?.toString();
        if (payId != null && payId.isNotEmpty) {
          codeByPaymentId[payId] = code;
        }
      }

      for (final p in payments) {
        final paymentId = (p['id'] ?? 'PAY-${p['date']}').toString();
        final linkedCode = codeByPaymentId[paymentId];
        final plan = p['plan']?.toString() ?? '-';

        final daysAdded = (p['days_added'] as num?)?.toInt() ??
            (linkedCode?['days_added'] as num?)?.toInt() ??
            DatabaseService.inferDefaultDaysForPlan(plan);
        final aiCredits = (p['ai_extra_credits'] as num?)?.toInt() ??
            (linkedCode?['total_ai_credited'] as num?)?.toInt() ??
            (linkedCode?['ai_credits'] as num?)?.toInt() ??
            DatabaseService.inferDefaultAiForPlan(plan);

        result.add({
          'id': paymentId,
          'date': p['date'] ?? '',
          'amount': (p['amount'] as num?)?.toDouble() ?? 0.0,
          'plan': plan,
          'days_added': daysAdded,
          'ai_extra_credits': aiCredits,
          'method': p['method'] ?? '-',
          'reference': p['reference'] ?? '-',
          'receipt_number': p['receipt_number'] ?? '',
          'receipt_type': p['receipt_type'] ?? '',
          'receipt_bol_number': p['receipt_bol_number'] ?? '',
          'receipt_fac_number': p['receipt_fac_number'] ?? '',
          'receipt_issued_at': p['receipt_issued_at'] ?? '',
          'client_id': c['id'],
          'business_name': c['business_name'] ?? '',
          'owner_name': c['owner_name'] ?? '',
          'document_number': c['document_number'] ?? c['document_id'] ?? '',
          'phone': c['phone'] ?? '',
          'device_id': c['current_device_id'] ?? '',
          'next_followup_date': c['next_followup_date'] ?? '',
          'notes': p['notes'] ?? '',
          'updated_at': p['updated_at'] ?? '',
        });
      }
    }
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return result;
  }

  /// Exporta el libro contable consolidado a CSV con BOM UTF-8, hora Perú GMT-5 y escape RFC-4180.
  Future<String> exportFinancesToCsv() async {
    final finances = await getConsolidatedFinances();
    final buffer = StringBuffer();
    buffer.write(CsvCellEscaper.utf8Bom);
    buffer.writeln(
        'FECHA,ID_CLIENTE,NEGOCIO,TITULAR,RUC_DNI,TELEFONO,DEVICE_ID,MONTO_PEN,PLAN,MEDIO_PAGO,REFERENCIA,TIPO_COMPROBANTE,N_COMPROBANTE,NOTAS');
    for (final f in finances) {
      final rawDate = (f['date'] as String? ?? '').trim();
      final dateStr = rawDate.isNotEmpty
          ? PeruTimeHelper.formatLimaDateTime(rawDate, fallback: rawDate)
          : '';
      final recNum = (f['receipt_number'] as String? ?? '').trim();
      final recType = (f['receipt_type'] as String? ?? '').trim().toUpperCase();
      final tipoComp = recType.isNotEmpty
          ? recType
          : (recNum.startsWith('FAC')
              ? 'FAC'
              : (recNum.startsWith('BOL') ? 'BOL' : ''));

      buffer.writeln(
        CsvCellEscaper.encodeRow([
          dateStr,
          f['client_id'] ?? '',
          f['business_name'] ?? '',
          f['owner_name'] ?? '',
          f['document_number'] ?? '',
          f['phone'] ?? '',
          f['device_id'] ?? '',
          ((f['amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          f['plan'] ?? '',
          f['method'] ?? '',
          f['reference'] ?? '',
          tipoComp,
          recNum,
          f['notes'] ?? '',
        ]),
      );
    }
    return buffer.toString();
  }

  /// Obtiene el historial detallado de pagos, códigos y cambios de equipo de un cliente.
  Future<Map<String, dynamic>?> getClientHistory(String id) async {
    final client = await getClientById(id);
    if (client == null) return null;

    final payments =
        (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    final codes = (client['generated_codes_history'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final devices =
        (client['device_history'] as List? ?? []).cast<Map<String, dynamic>>();

    double totalPaid = 0.0;
    for (final p in payments) {
      totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'client': client,
      'total_paid': totalPaid,
      'payments': payments,
      'codes': codes,
      'device_history': devices,
      'hardware': devices,
    };
  }

  /// Exportación de Clientes a formato CSV con BOM UTF-8 para apertura directa en Excel de Windows.
  Future<String> exportClientsToCsv() async {
    final clients = await getClients();
    final buffer = StringBuffer();
    buffer.write(CsvCellEscaper.utf8Bom);
    buffer.writeln(
      'ID,Negocio,Propietario,RUC/DNI,Telefono,DeviceID ML-XXXX,Version Instalada,Tipo Licencia,Estado,Fecha Expiracion,Updates Hasta,Creditos IA Extra,Total Pagado (S/),Ultimo Codigo,Notas',
    );

    for (final c in clients) {
      final payments =
          (c['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      double totalPaid = 0.0;
      for (final p in payments) {
        totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
      }
      final codes = (c['generated_codes_history'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final lastCode = codes.isNotEmpty ? codes.last['token'] ?? '' : '';

      buffer.writeln(
        CsvCellEscaper.encodeRow([
          c['id'],
          c['business_name'],
          c['owner_name'],
          c['document_id'],
          c['phone'],
          c['current_device_id'],
          c['installed_version'],
          c['license_type'],
          c['license_status'],
          c['license_expires'],
          c['updates_until'],
          c['ai_extra_credits'],
          'S/ ${totalPaid.toStringAsFixed(2)}',
          lastCode,
          c['notes'],
        ]),
      );
    }
    return buffer.toString();
  }
}
