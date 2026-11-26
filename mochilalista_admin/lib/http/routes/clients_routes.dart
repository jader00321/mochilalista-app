import 'dart:convert';
import 'dart:io';

import '../../core/semver_utils.dart';
import '../http_context.dart';

/// Sub-router para Dashboard financiero y Cartera CRM de clientes (`/api/dashboard`, `/api/clients/*`).
class ClientsRoutes {
  ClientsRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/dashboard' && method == 'GET') {
      await _handleDashboard(ctx);
      return true;
    }

    if ((path == '/api/clients/export-csv' || path == '/api/clients/export') &&
        method == 'GET') {
      final csvData = await ctx.dbService.exportClientsToCsv();
      ctx.request.response.headers.contentType =
          ContentType('text', 'csv', charset: 'utf-8');
      ctx.request.response.headers.add(
        'Content-Disposition',
        'attachment; filename="clientes_mochilalista_${ctx.dbService.currentMode}_${DateTime.now().toIso8601String().substring(0, 10)}.csv"',
      );
      ctx.request.response.write(csvData);
      await ctx.request.response.close();
      return true;
    }

    if (path == '/api/clients') {
      if (method == 'GET') {
        await ctx.sendJson(await ctx.dbService.getClients());
        return true;
      } else if (method == 'POST') {
        final data = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        try {
          final newClient = await ctx.dbService.createClient(data);
          await ctx.sendJson(newClient, statusCode: HttpStatus.created);
        } catch (e) {
          await ctx.sendJson({'error': e.toString()},
              statusCode: HttpStatus.badRequest);
        }
        return true;
      }
    }

    if (path.startsWith('/api/clients/') &&
        path.endsWith('/history') &&
        method == 'GET') {
      final segments = path.split('/');
      if (segments.length == 5) {
        final clientId = segments[3];
        final history = await ctx.dbService.getClientHistory(clientId);
        if (history == null) {
          await ctx.sendJson({'error': 'Cliente no encontrado: $clientId'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(history);
        }
        return true;
      }
    }

    if (path.startsWith('/api/clients/') &&
        path.endsWith('/migrate-device') &&
        method == 'POST') {
      final segments = path.split('/');
      if (segments.length == 5) {
        await _handleMigrateDevice(ctx, segments[3]);
        return true;
      }
    }

    if (path.startsWith('/api/clients/') &&
        path.endsWith('/mark-updated') &&
        method == 'POST') {
      final segments = path.split('/');
      if (segments.length == 5) {
        final clientId = segments[3];
        final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        final versionName =
            (body['version_name'] as String? ?? '9.34.0').trim();
        final bool force = body['force'] == true;

        final updated = await ctx.dbService.markClientUpdated(
          clientId,
          versionName,
          force: force,
        );
        if (updated == null) {
          await ctx.sendJson({'error': 'Cliente no encontrado'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson({
            ...updated,
            'force_applied': force,
            'previous_installed_version': updated['previous_installed_version'],
          });
        }
        return true;
      }
    }

    final paymentsMatch = RegExp(r'^/api/clients/([^/]+)/payments(?:/([^/]+))?$')
        .firstMatch(path);
    if (paymentsMatch != null) {
      await _handlePayments(
        ctx,
        clientId: paymentsMatch.group(1)!,
        paymentId: paymentsMatch.group(2),
      );
      return true;
    }

    final receiptMatch =
        RegExp(r'^/api/clients/([^/]+)/payments/([^/]+)/receipt$')
            .firstMatch(path);
    if (receiptMatch != null && method == 'POST') {
      await _handlePaymentReceipt(
        ctx,
        clientId: receiptMatch.group(1)!,
        paymentId: receiptMatch.group(2)!,
      );
      return true;
    }

    final syncReportedMatch =
        RegExp(r'^/api/clients/([^/]+)/sync-reported$').firstMatch(path);
    if (syncReportedMatch != null && method == 'POST') {
      await _handleSyncReported(ctx, syncReportedMatch.group(1)!);
      return true;
    }

    final devHistoryMatch =
        RegExp(r'^/api/clients/([^/]+)/device-history/(\d+)$')
            .firstMatch(path);
    if (devHistoryMatch != null && method == 'PUT') {
      await _handleDeviceHistoryReason(
        ctx,
        clientId: devHistoryMatch.group(1)!,
        historyIndex: int.parse(devHistoryMatch.group(2)!),
      );
      return true;
    }

    final clientSingleMatch =
        RegExp(r'^/api/clients/([^/]+)$').firstMatch(path);
    if (clientSingleMatch != null) {
      final clientId = clientSingleMatch.group(1)!;
      if (method == 'GET') {
        final client = await ctx.dbService.getClientById(clientId);
        if (client == null) {
          await ctx.sendJson({'error': 'Cliente no encontrado'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(client);
        }
        return true;
      } else if (method == 'PUT') {
        final updates =
            jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        try {
          final updated = await ctx.dbService.updateClient(clientId, updates);
          if (updated == null) {
            await ctx.sendJson({'error': 'Cliente no encontrado'},
                statusCode: HttpStatus.notFound);
          } else {
            await ctx.sendJson(updated);
          }
        } catch (e) {
          await ctx.sendJson({'error': e.toString()},
              statusCode: HttpStatus.badRequest);
        }
        return true;
      } else if (method == 'DELETE') {
        final ok = await ctx.dbService.deleteClient(clientId);
        if (!ok) {
          await ctx.sendJson({'error': 'Cliente no encontrado'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(
              {'ok': true, 'message': 'Cliente eliminado con éxito.'});
        }
        return true;
      }
    }

    return false;
  }

  static Future<void> _handleDashboard(AdminHttpContext ctx) async {
    final clients = await ctx.dbService.getClients();
    final releases = await ctx.dbService.getReleases();
    final now = DateTime.now();

    double totalRevenueAccumulated = 0.0;
    double totalRevenueMonth = 0.0;
    int activeCount = 0;
    int expiringSoonCount = 0;
    int expiredCount = 0;
    int perpetualCount = 0;
    int prospectCount = 0;
    int outdatedAppCount = 0;
    final List<Map<String, dynamic>> urgentActions = [];

    String? latestVersion;
    for (final r in releases) {
      final vn = r['version_name'] as String? ?? '';
      if (vn.trim().isNotEmpty) {
        if (latestVersion == null ||
            SemVerUtils.compare(vn, latestVersion) > 0) {
          latestVersion = vn.trim();
        }
      }
    }

    final hasPublishedReleases = releases.isNotEmpty &&
        latestVersion != null &&
        latestVersion.isNotEmpty;

    for (final c in clients) {
      final payments =
          (c['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final p in payments) {
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        totalRevenueAccumulated += amount;
        final pDate = DateTime.tryParse(p['date'] ?? '');
        if (pDate != null &&
            pDate.year == now.year &&
            pDate.month == now.month) {
          totalRevenueMonth += amount;
        }
      }

      final plan = (c['license_type'] as String? ?? 'TRIAL').toUpperCase();
      final status = (c['license_status'] as String? ?? '').toUpperCase();
      final isProspect = plan == 'PROSPECTO' || status == 'PROSPECTO';
      final isPerpetual = plan == 'PERPETUO_LIBERADO' || plan == 'PERPETUO';
      final expStr = c['license_expires'] as String?;
      final expDate = expStr != null ? DateTime.tryParse(expStr) : null;

      if (isProspect) {
        prospectCount++;
      } else if (isPerpetual) {
        perpetualCount++;
        activeCount++;
      } else if (expDate != null) {
        final diffDays = expDate.difference(now).inDays;
        if (diffDays < 0) {
          expiredCount++;
        } else if (diffDays <= 7) {
          expiringSoonCount++;
          activeCount++;
          urgentActions.add({
            'client_id': c['id'],
            'business_name': c['business_name'],
            'owner_name': c['owner_name'],
            'phone': c['phone'],
            'days_left': diffDays,
            'expires_date': expDate.toIso8601String(),
            'current_device_id': c['current_device_id'],
          });
        } else {
          activeCount++;
        }
      }

      final clientVer = (c['installed_version'] as String? ?? '').trim();
      if (!isProspect &&
          hasPublishedReleases &&
          clientVer.isNotEmpty &&
          SemVerUtils.compare(clientVer, latestVersion) < 0) {
        outdatedAppCount++;
      }
    }

    urgentActions.sort(
        (a, b) => (a['days_left'] as int).compareTo(b['days_left'] as int));

    await ctx.sendJson({
      'totalRevenueMonth': totalRevenueMonth,
      'totalRevenueAccumulated': totalRevenueAccumulated,
      'totalActiveClients': activeCount,
      'prospectClients': prospectCount,
      'expiringSoonClients': expiringSoonCount,
      'expiredClients': expiredCount,
      'perpetualClients': perpetualCount,
      'outdatedAppClients': outdatedAppCount,
      'latestAppVersion': latestVersion ?? '0.0.0',
      'urgentActions': urgentActions,
      'currentMode': ctx.dbService.currentMode,
    });
  }

  static Future<void> _handleMigrateDevice(
    AdminHttpContext ctx,
    String clientId,
  ) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final newDeviceId =
        (body['new_device_id'] as String? ?? '').trim().toUpperCase();
    final feeMode = (body['fee_mode'] as String? ?? 'STANDARD').toUpperCase();
    double feeAmount = (body['fee_amount'] as num?)?.toDouble() ??
        (body['fee'] as num?)?.toDouble() ??
        ctx.configService.migrationFee;
    if (feeMode == 'FREE') {
      feeAmount = 0.0;
    }
    final paymentMethod = body['payment_method'] as String? ?? 'Yape';
    final reason = body['reason'] as String?;
    final emitImmediately =
        body['emit_immediately'] == true || body['emitImmediately'] == true;
    final migrationScenario = (body['migration_scenario'] as String? ??
            body['scenario'] as String? ??
            'RESTORED_BACKUP')
        .toUpperCase();
    final newDeviceModel = (body['device_model'] as String? ??
            body['new_device_model'] as String?)
        ?.trim();

    if (newDeviceId.isEmpty) {
      await ctx.sendJson({'error': 'El nuevo DeviceID es obligatorio.'},
          statusCode: HttpStatus.badRequest);
      return;
    }

    final updated = await ctx.dbService.migrateDevice(
      clientId: clientId,
      newDeviceId: newDeviceId,
      feeAmount: feeAmount,
      paymentMethod: paymentMethod,
      reason: reason,
      emitImmediately: emitImmediately,
      signer: ctx.signer,
      migrationScenario: migrationScenario,
      newDeviceModel: newDeviceModel,
    );

    if (updated == null) {
      await ctx.sendJson({'error': 'Cliente no encontrado'},
          statusCode: HttpStatus.notFound);
    } else {
      await ctx.sendJson(updated);
    }
  }

  static Future<void> _handlePayments(
    AdminHttpContext ctx, {
    required String clientId,
    required String? paymentId,
  }) async {
    final method = ctx.method;
    if (paymentId == null && method == 'POST') {
      final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
      final updated = await ctx.dbService.addManualPayment(clientId, body);
      if (updated == null) {
        await ctx.sendJson({'error': 'Cliente no encontrado'},
            statusCode: HttpStatus.notFound);
      } else {
        await ctx.sendJson(updated);
      }
      return;
    } else if (paymentId != null && method == 'PUT') {
      try {
        final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
        final updated =
            await ctx.dbService.updatePayment(clientId, paymentId, body);
        if (updated == null) {
          await ctx.sendJson({'error': 'Pago o cliente no encontrado'},
              statusCode: HttpStatus.notFound);
        } else {
          await ctx.sendJson(updated);
        }
      } catch (e) {
        final msg = (e is ArgumentError) ? e.message.toString() : e.toString();
        await ctx.sendJson({'error': msg}, statusCode: HttpStatus.badRequest);
      }
      return;
    } else if (paymentId != null && method == 'DELETE') {
      final updated = await ctx.dbService.deletePayment(clientId, paymentId);
      if (updated == null) {
        await ctx.sendJson({'error': 'Pago o cliente no encontrado'},
            statusCode: HttpStatus.notFound);
      } else {
        await ctx.sendJson(updated);
      }
      return;
    }

    await ctx.sendJson(
      {'error': 'Método no soportado para pagos: $method'},
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  static Future<void> _handlePaymentReceipt(
    AdminHttpContext ctx, {
    required String clientId,
    required String paymentId,
  }) async {
    final bodyStr = await ctx.readBody();
    Map<String, dynamic> body = {};
    if (bodyStr.isNotEmpty) {
      try {
        body = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    try {
      final receiptData = await ctx.dbService.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        customNote: body['custom_note'] as String?,
        voucherType: body['voucher_type'] as String?,
        invoiceRuc: body['invoice_ruc'] as String?,
        invoiceBusinessName: body['invoice_business_name'] as String?,
        invoiceFiscalAddress: body['invoice_fiscal_address'] as String?,
        showIgvBreakdown: body['show_igv_breakdown'] as bool?,
        configService: ctx.configService,
      );

      if (receiptData == null) {
        await ctx.sendJson({'error': 'Cliente o pago no encontrado'},
            statusCode: HttpStatus.notFound);
      } else {
        await ctx.sendJson(receiptData);
      }
    } catch (e) {
      await ctx.sendJson({'error': e.toString()},
          statusCode: HttpStatus.badRequest);
    }
  }

  static Future<void> _handleSyncReported(
    AdminHttpContext ctx,
    String clientId,
  ) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    try {
      final updated = await ctx.dbService.syncClientReportedState(
        clientId: clientId,
        deviceId: body['device_id'] as String?,
        installedVersion: body['installed_version'] as String?,
        aiReportedBalance: (body['ai_reported_balance'] as num?)?.toInt(),
        trialDaysRemaining: (body['trial_days_remaining'] as num?)?.toInt(),
        expirationDate: body['expiration_date'] as String?,
        deviceModel: body['device_model'] as String?,
        notes: body['notes'] as String?,
      );
      if (updated == null) {
        await ctx.sendJson({'error': 'Cliente no encontrado: $clientId'},
            statusCode: HttpStatus.notFound);
      } else {
        await ctx.sendJson(updated);
      }
    } catch (e) {
      await ctx.sendJson({'error': e.toString()},
          statusCode: HttpStatus.badRequest);
    }
  }

  static Future<void> _handleDeviceHistoryReason(
    AdminHttpContext ctx, {
    required String clientId,
    required int historyIndex,
  }) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final reason = (body['reason'] as String? ?? '').trim();

    try {
      final updated = await ctx.dbService.updateDeviceHistoryReason(
        clientId: clientId,
        historyIndex: historyIndex,
        reason: reason,
      );
      if (updated == null) {
        await ctx.sendJson(
          {'error': 'Cliente o registro de migración no encontrado'},
          statusCode: HttpStatus.notFound,
        );
      } else {
        await ctx.sendJson({
          'ok': true,
          'message': 'Motivo de migración actualizado exitosamente',
          'client': updated,
        });
      }
    } catch (e) {
      await ctx.sendJson({'error': e.toString()},
          statusCode: HttpStatus.badRequest);
    }
  }
}
