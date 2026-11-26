part of 'database_service.dart';

/// Repositorio de pagos manuales, edición/eliminación y emisión idempotente de boletas/facturas (`BOL`/`FAC`).
mixin _PaymentsReceiptsRepositoryMixin on _DatabaseServiceBase {
  /// Eliminar un pago o anular transacción del historial de un cliente.
  Future<Map<String, dynamic>?> deletePayment(
      String clientId, String paymentId) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments =
        (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    payments.removeWhere((p) => p['id'] == paymentId);
    client['payment_history'] = payments;
    client['total_paid'] = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );

    clients[index] = client;
    await saveClients(clients, reason: 'delete_payment_${clientId}_$paymentId');
    return client;
  }

  /// Editar un pago existente en el historial del cliente (Plan Maestro 18 - Fase 4).
  Future<Map<String, dynamic>?> updatePayment(
      String clientId, String paymentId, Map<String, dynamic> paymentData) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final pIndex = payments.indexWhere((p) => p['id'] == paymentId);
    if (pIndex == -1) return null;

    final oldPayment = payments[pIndex];

    if (paymentData.containsKey('amount')) {
      final rawAmt = paymentData['amount'];
      final num? parsedAmt =
          (rawAmt is num) ? rawAmt : num.tryParse(rawAmt.toString());
      if (parsedAmt == null || parsedAmt.isNaN || parsedAmt < 0) {
        throw ArgumentError(
            'El monto del pago debe ser un número válido mayor o igual a cero.');
      }
      oldPayment['amount'] = parsedAmt.toDouble();
    }

    if (paymentData.containsKey('date')) {
      final rawDate = (paymentData['date'] as String? ?? '').trim();
      if (rawDate.isNotEmpty) {
        try {
          DateTime.parse(rawDate);
          oldPayment['date'] = rawDate;
        } catch (_) {
          throw ArgumentError(
              'La fecha del pago no tiene un formato ISO válido (YYYY-MM-DD).');
        }
      }
    }

    if (paymentData.containsKey('plan')) {
      oldPayment['plan'] = paymentData['plan'];
    }
    if (paymentData.containsKey('concept')) {
      oldPayment['plan'] = paymentData['concept'];
    }

    if (paymentData.containsKey('method')) {
      oldPayment['method'] = paymentData['method'];
    }
    if (paymentData.containsKey('payment_method')) {
      oldPayment['method'] = paymentData['payment_method'];
    }
    if (paymentData.containsKey('reference')) {
      oldPayment['reference'] = paymentData['reference'];
    }
    if (paymentData.containsKey('notes')) {
      oldPayment['notes'] = paymentData['notes'];
    }

    oldPayment['id'] = paymentId;
    oldPayment['updated_at'] = DateTime.now().toUtc().toIso8601String();

    payments[pIndex] = oldPayment;
    client['payment_history'] = payments;

    final totalPaid = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );
    client['total_paid'] = totalPaid;

    clients[index] = client;
    await saveClients(clients, reason: 'update_payment_${clientId}_$paymentId');
    return client;
  }

  /// Agregar un pago manual al historial del cliente.
  Future<Map<String, dynamic>?> addManualPayment(
      String clientId, Map<String, dynamic> paymentData) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments =
        (client['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
    payments.add({
      'id': 'PAY-${DateTime.now().millisecondsSinceEpoch}',
      'date': paymentData['date'] ?? DateTime.now().toUtc().toIso8601String(),
      'amount': (paymentData['amount'] as num?)?.toDouble() ?? 0.0,
      'plan': paymentData['plan'] ?? 'PAGO_MANUAL',
      'method': paymentData['method'] ?? 'Efectivo',
      'reference': paymentData['reference'] ?? 'Registro Manual',
      if (paymentData['notes'] != null &&
          paymentData['notes'].toString().isNotEmpty)
        'notes': paymentData['notes'].toString(),
    });
    client['payment_history'] = payments;
    client['total_paid'] = payments.fold<double>(
      0.0,
      (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0),
    );

    clients[index] = client;
    await saveClients(clients, reason: 'add_manual_payment_$clientId');
    return client;
  }

  /// Alias de `addManualPayment`.
  Future<Map<String, dynamic>?> addPayment(
          String clientId, Map<String, dynamic> paymentData) =>
      addManualPayment(clientId, paymentData);

  /// Emite o recupera la boleta (`BOL-XXXX`) o factura (`FAC-XXXX`) oficial de forma atómica e idempotente.
  Future<Map<String, dynamic>?> issueOrGetPaymentReceipt({
    required String clientId,
    required String paymentId,
    required ConfigService configService,
    String? voucherType,
    String? customNote,
    String? invoiceRuc,
    String? invoiceBusinessName,
    String? invoiceFiscalAddress,
    bool? showIgvBreakdown,
  }) async {
    final clients = await getClients();
    final index = clients.indexWhere((c) => c['id'] == clientId);
    if (index == -1) return null;

    final client = clients[index];
    final payments = (client['payment_history'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    final pIndex = payments.indexWhere((p) => p['id'] == paymentId);
    if (pIndex == -1) return null;

    final payment = payments[pIndex];

    final legacyReceiptNum = payment['receipt_number'] as String?;
    if (legacyReceiptNum != null && legacyReceiptNum.trim().isNotEmpty) {
      if (legacyReceiptNum.startsWith('BOL-') &&
          payment['receipt_bol_number'] == null) {
        payment['receipt_bol_number'] = legacyReceiptNum;
      } else if (legacyReceiptNum.startsWith('FAC-') &&
          payment['receipt_fac_number'] == null) {
        payment['receipt_fac_number'] = legacyReceiptNum;
      }
    }

    final String requestedType =
        (voucherType ?? payment['receipt_type'] ?? 'BOL')
            .toString()
            .trim()
            .toUpperCase();
    final String vType = (requestedType == 'FAC') ? 'FAC' : 'BOL';

    final String? existingTypedCorrelative = (vType == 'FAC')
        ? (payment['receipt_fac_number'] as String?)
        : (payment['receipt_bol_number'] as String?);

    final bool alreadyIssuedForType = existingTypedCorrelative != null &&
        existingTypedCorrelative.trim().isNotEmpty;

    bool needsSave = false;

    if (!alreadyIssuedForType) {
      final prefix = '$vType-';
      int maxExisting = 0;
      for (final c in clients) {
        final pList = (c['payment_history'] as List? ?? []);
        for (final pItem in pList) {
          if (pItem is Map) {
            final rNum = pItem['receipt_number'] as String?;
            final rBol = pItem['receipt_bol_number'] as String?;
            final rFac = pItem['receipt_fac_number'] as String?;
            for (final cand in [rNum, rBol, rFac]) {
              if (cand != null && cand.trim().startsWith(prefix)) {
                final numPart = cand.trim().substring(prefix.length);
                final val = int.tryParse(numPart);
                if (val != null && val > maxExisting) {
                  maxExisting = val;
                }
              }
            }
          }
        }
      }

      final isSandbox = currentMode == 'sandbox';
      final configNum = await configService.consumeReceiptCorrelative(
        isSandbox: isSandbox,
        voucherType: vType,
      );
      final safeNum =
          (configNum <= maxExisting) ? (maxExisting + 1) : configNum;
      if (safeNum > configNum) {
        await configService.syncReceiptCorrelativeMin(
          isSandbox: isSandbox,
          voucherType: vType,
          nextValue: safeNum + 1,
        );
      }
      final formattedNum = '$vType-${safeNum.toString().padLeft(4, '0')}';
      if (vType == 'FAC') {
        payment['receipt_fac_number'] = formattedNum;
      } else {
        payment['receipt_bol_number'] = formattedNum;
      }
      payment['receipt_number'] = formattedNum;
      payment['receipt_type'] = vType;
      payment['receipt_issued_at'] ??= DateTime.now().toUtc().toIso8601String();
      needsSave = true;
    } else {
      if (payment['receipt_number'] != existingTypedCorrelative ||
          payment['receipt_type'] != vType) {
        payment['receipt_number'] = existingTypedCorrelative;
        payment['receipt_type'] = vType;
        needsSave = true;
      }
    }

    if (customNote != null &&
        customNote.trim() != (payment['receipt_custom_note'] ?? '')) {
      payment['receipt_custom_note'] = customNote.trim();
      needsSave = true;
    }
    if (invoiceRuc != null &&
        invoiceRuc.trim() != (payment['invoice_ruc'] ?? '')) {
      payment['invoice_ruc'] = invoiceRuc.trim();
      needsSave = true;
    }
    if (invoiceBusinessName != null &&
        invoiceBusinessName.trim() !=
            (payment['invoice_business_name'] ?? '')) {
      payment['invoice_business_name'] = invoiceBusinessName.trim();
      needsSave = true;
    }
    if (invoiceFiscalAddress != null &&
        invoiceFiscalAddress.trim() !=
            (payment['invoice_fiscal_address'] ?? '')) {
      payment['invoice_fiscal_address'] = invoiceFiscalAddress.trim();
      needsSave = true;
    }
    if (showIgvBreakdown != null &&
        showIgvBreakdown != payment['show_igv_breakdown']) {
      payment['show_igv_breakdown'] = showIgvBreakdown;
      needsSave = true;
    }

    if (needsSave) {
      payments[pIndex] = payment;
      client['payment_history'] = payments;
      clients[index] = client;
      await saveClients(clients,
          reason: 'issue_receipt_${payment['receipt_number']}_$paymentId');
    }

    return {
      'ok': true,
      'receipt_number': payment['receipt_number'],
      'receipt_type': payment['receipt_type'] ?? vType,
      'voucher_type': payment['receipt_type'] ?? vType,
      'receipt_bol_number': payment['receipt_bol_number'],
      'receipt_fac_number': payment['receipt_fac_number'],
      'receipt_issued_at': payment['receipt_issued_at'],
      'invoice_ruc': payment['invoice_ruc'],
      'invoice_business_name': payment['invoice_business_name'],
      'invoice_fiscal_address': payment['invoice_fiscal_address'],
      'show_igv_breakdown': payment['show_igv_breakdown'] ?? false,
      'already_issued': alreadyIssuedForType,
      'payment': payment,
      'client': {
        'id': client['id'],
        'business_name': client['business_name'] ?? '',
        'owner_name': client['owner_name'] ?? '',
        'document_number': client['document_id'] ??
            client['document_number'] ??
            client['ruc_dni'] ??
            '',
        'phone': client['phone'] ?? '',
        'current_device_id': client['current_device_id'] ?? '',
        'license_type': client['license_type'] ?? '',
        'license_status': client['license_status'] ?? '',
        'license_expires': client['license_expires'] ?? '',
      },
      'receipt_config': configService.receiptConfig,
    };
  }
}
