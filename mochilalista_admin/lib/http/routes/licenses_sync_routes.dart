import 'dart:convert';
import 'dart:io';

import '../../commercial_config_sync_service.dart';
import '../../database_service.dart';
import '../../license_signer.dart';
import '../http_context.dart';

/// Sub-router para emisión de licencias Ed25519 (`ML9`), Inspector Tri-Protocolo
/// (`ML9`/`MLS1`/`MLC1`) y sincronización offline `/api/sync/*`.
class LicensesSyncRoutes {
  LicensesSyncRoutes._();

  static Future<bool> handle(AdminHttpContext ctx) async {
    final path = ctx.path;
    final method = ctx.method;

    if (path == '/api/licenses/generate' && method == 'POST') {
      await _handleGenerateLicense(ctx);
      return true;
    }

    if (path == '/api/licenses/inspect' && method == 'POST') {
      await _handleInspectToken(ctx);
      return true;
    }

    if (path == '/api/sync/parse' && method == 'POST') {
      await _handleSyncParse(ctx);
      return true;
    }

    if (path == '/api/sync/apply' && method == 'POST') {
      await _handleSyncApply(ctx);
      return true;
    }

    return false;
  }

  static Future<void> _handleGenerateLicense(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;

    final clientId = body['client_id'] as String? ?? '';
    final client = await ctx.dbService.getClientById(clientId);
    if (client == null) {
      await ctx.sendJson({'error': 'Cliente no encontrado'},
          statusCode: HttpStatus.notFound);
      return;
    }

    final plan = (body['plan'] as String? ?? 'MENSUAL').toUpperCase().trim();
    final normPlan = LicenseSigner.normalizePlanSlug(plan);
    final deviceId =
        (client['current_device_id'] as String? ?? '').trim().toUpperCase();
    final nonce = (client['next_nonce'] as num?)?.toInt() ?? 1;

    final customDays = (body['custom_days'] as num?)?.toInt();
    final defaultDays = ctx.configService.getPlanDays(normPlan, fallback: 30);
    int daysToAdd = customDays ?? defaultDays;
    final defaultPrice = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? 0.0
        : ctx.configService.getPlanPrice(normPlan, fallback: 35.0);
    final paymentAmount = (body['payment_amount'] as num?)?.toDouble() ??
        (body['amount'] as num?)?.toDouble() ??
        defaultPrice;
    final paymentMethod = body['payment_method'] as String? ?? 'Yape';
    final paymentRef = (body['payment_ref'] as String?) ??
        (body['payment_reference'] as String?) ??
        'Pago registrado';
    final aiExtra = (body['custom_ai_bonus'] as num?)?.toInt() ??
        (body['ai_extra_credits'] as num?)?.toInt() ??
        (body['custom_ai_amount'] as num?)?.toInt() ??
        0;
    final computationMode = body['computation_mode'] as String? ?? 'cumulative';
    final resetFromToday =
        computationMode == 'from_today' || body['reset_from_today'] == true;
    final customExactExpStr = (body['custom_exact_expiration'] as String?) ??
        (body['custom_exact_date'] as String?);
    final customExactExp =
        customExactExpStr != null && customExactExpStr.isNotEmpty
            ? DateTime.tryParse(customExactExpStr)
            : null;

    if (normPlan == 'BONO_IA_PERSONALIZADO') {
      daysToAdd = 0;
      if (aiExtra <= 0) {
        await ctx.sendJson(
          {
            'error':
                'Para la modalidad Bono / Recarga IA Personalizada debes especificar una cantidad de escaneos IA mayor a 0.'
          },
          statusCode: HttpStatus.badRequest,
        );
        return;
      }
    } else if (customDays == null) {
      daysToAdd = ctx.configService.getPlanDays(normPlan, fallback: 30);
    }

    DateTime? updatesUntil;
    if (normPlan == 'PERPETUO_LIBERADO' ||
        normPlan == 'PASE_ACTUALIZACION_ANUAL') {
      final curUp = client['updates_until'] != null
          ? DateTime.tryParse(client['updates_until'])
          : null;
      final now = DateTime.now();
      final baseUp = (curUp != null && curUp.isAfter(now)) ? curUp : now;
      updatesUntil = baseUp.add(const Duration(days: 365));
    }

    final tokenClaimC =
        normPlan == 'RECARGA_IA_150' ? (aiExtra > 0 ? aiExtra : 150) : aiExtra;

    final token = await ctx.signer.generateLicenseToken(
      deviceFingerprint: deviceId,
      plan: normPlan,
      daysToAdd: daysToAdd,
      nonce: nonce,
      updatesUntil: updatesUntil,
      aiExtraCredits: tokenClaimC,
      businessTag: client['business_name'] as String?,
    );

    final updatedClient = await ctx.dbService.recordCodeEmission(
      clientId: clientId,
      token: token,
      plan: normPlan,
      daysToAdd: daysToAdd,
      paymentAmount: paymentAmount,
      paymentMethod: paymentMethod,
      paymentRef: paymentRef,
      updatesUntil: updatesUntil,
      aiExtraCredits: aiExtra,
      customExactExpiration: customExactExp,
      resetFromToday: resetFromToday,
    );

    final baseAi = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? 0
        : ctx.configService.getPlanAiCredits(normPlan,
            fallback: LicenseSigner.getCumulativeScansForPlan(normPlan));
    final totalCredited = baseAi + aiExtra;
    final lastCode =
        (updatedClient?['generated_codes_history'] as List?)?.isNotEmpty == true
            ? (updatedClient!['generated_codes_history'] as List).last
                as Map<String, dynamic>?
            : null;

    await ctx.sendJson({
      'token': token,
      'plan': normPlan,
      'device_id': deviceId,
      'nonce': nonce,
      'days_added': daysToAdd,
      'plan_base_ai_scans': baseAi,
      'bonus_ai_scans': aiExtra,
      'total_ai_scans_credited': totalCredited,
      'token_claim_c': tokenClaimC,
      'ai_extra_credits': aiExtra,
      'payment_id': lastCode?['payment_id'],
      'amount_paid': lastCode?['amount_paid'] ?? 0.0,
      'client': updatedClient,
    });
  }

  static Future<void> _handleInspectToken(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final token = (body['token'] as String? ?? '').trim();

    if (CommercialConfigSyncService.looksLikeMlc1Input(token)) {
      final mlc1Service =
          ctx.commercialSyncService ?? CommercialConfigSyncService();
      if (!ctx.signer.isLoaded) {
        try {
          await ctx.signer.loadMasterKey();
        } catch (_) {}
      }

      final verifyRes = ctx.signer.isLoaded
          ? await mlc1Service.verifySignedToken(token, signer: ctx.signer)
          : {
              'valid': false,
              'status': 'MISSING_PUBLIC_KEY',
              'error':
                  'No se pudo cargar la clave pública Ed25519 para verificar la ficha MLC1.',
            };

      if (verifyRes['valid'] == true) {
        final payload = Map<String, dynamic>.from(verifyRes['payload'] as Map);
        final comparison = mlc1Service.buildCurrentConfigComparison(
          payload,
          ctx.configService.config,
          localRevision: ctx.configService.commercialSyncRevision,
        );
        await ctx.sendJson({
          'ok': true,
          'input_kind': 'COMMERCIAL_CONFIG',
          'token_kind': 'MLC1',
          'valid': true,
          'isValid': true,
          'status': verifyRes['status'] ?? 'VALID',
          'error': null,
          'domain_separated': true,
          'domain_message_prefix': CommercialConfigSyncService.tokenPrefix,
          'revision': verifyRes['revision'],
          'schema_version': verifyRes['schema_version'],
          'issued_at': verifyRes['issued_at'],
          'issued_at_unix': verifyRes['issued_at_unix'],
          'issued_at_lima': verifyRes['issued_at_lima'],
          'payload_bytes': verifyRes['payload_bytes'],
          'token_bytes': verifyRes['token_bytes'],
          'max_payload_bytes': CommercialConfigSyncService.maxPayloadBytes,
          'clean_token': verifyRes['clean_token'],
          'payload': payload,
          'summary': verifyRes['summary'],
          'current_config_comparison': comparison,
        });
      } else {
        final diagPayload = mlc1Service.tryDecodePayloadDiagnostic(token);
        final diagSummary = diagPayload != null
            ? mlc1Service.buildDiagnosticSummaryFromMap(diagPayload)
            : null;
        await ctx.sendJson({
          'ok': false,
          'input_kind': 'COMMERCIAL_CONFIG',
          'token_kind': 'MLC1',
          'valid': false,
          'isValid': false,
          'status': verifyRes['status'] ?? 'INVALID_SIGNATURE',
          'error': verifyRes['error'] ??
              'Ficha comercial MLC1 inválida o adulterada.',
          'domain_separated': true,
          'domain_message_prefix': CommercialConfigSyncService.tokenPrefix,
          'security_alert':
              'FIRMA ED25519 INVÁLIDA O FICHA ALTERADA — No compartir ni aplicar; regenera una ficha oficial desde Configuración',
          'diagnostic_only': true,
          'payload': null,
          'diagnostic_payload': diagPayload,
          'diagnostic_summary': diagSummary,
        });
      }
      return;
    }

    if (token.contains('MLS1-') ||
        token.contains('MLSYNC_V1') ||
        token.contains('"format": "MLSYNC_V1"') ||
        token.contains('"format":"MLSYNC_V1"')) {
      final syncResult = ctx.syncService.parseRawInput(token);
      if (syncResult.valid && syncResult.payload != null) {
        final clients = await ctx.dbService.getClients();
        final analysis =
            ctx.syncService.analyzeForClients(syncResult.payload!, clients);
        await ctx.sendJson({
          'ok': true,
          'input_kind': 'CLIENT_SYNC',
          'valid': true,
          'isValid': true,
          'token': syncResult.token,
          'payload': syncResult.payload,
          'matched_client': analysis['matched_client'],
          'match_type': analysis['match_type'],
          'migration_rescue': analysis['migration_rescue'],
          'changes': analysis['changes'],
          'is_older_than_last_sync': analysis['is_older_than_last_sync'],
          'analysis': analysis,
        });
      } else {
        await ctx.sendJson({
          'ok': false,
          'input_kind': 'CLIENT_SYNC',
          'valid': false,
          'isValid': false,
          'error_code': syncResult.errorCode,
          'error': syncResult.errorMessage,
        });
      }
      return;
    }

    final result = await ctx.signer.inspectToken(token);
    result['input_kind'] = 'LICENSE_TOKEN';

    if (result['isValid'] == true && result['deviceId'] != null) {
      final clients = await ctx.dbService.getClients();
      final targetDev = result['deviceId'].toString().toUpperCase();
      try {
        final matched = clients.firstWhere((c) =>
            (c['current_device_id'] as String).toUpperCase() == targetDev);
        result['matching_client'] = {
          'id': matched['id'],
          'business_name': matched['business_name'],
          'owner_name': matched['owner_name'],
          'phone': matched['phone'],
          'installed_version': matched['installed_version'],
          'license_type': matched['license_type'],
          'license_status': matched['license_status'],
          'next_nonce': matched['next_nonce'] ?? 1,
          'ultimo_nonce': matched['ultimo_nonce'],
          'last_sync_at': matched['last_sync_at'],
          'license_expires': matched['license_expires'],
          'ai_reported_balance': matched['ai_reported_balance'],
          'ai_credits_used_total': matched['ai_credits_used_total'],
          'document_id': matched['document_id'] ?? matched['document_number'],
        };
      } catch (_) {
        result['matching_client'] = null;
      }
    }

    await ctx.sendJson(result);
  }

  static Future<void> _handleSyncParse(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final rawInput = (body['raw_input'] as String? ?? '').trim();
    final expectedClientId = (body['expected_client_id'] as String?)?.trim();

    final parseResult = ctx.syncService.parseRawInput(rawInput);
    if (!parseResult.valid || parseResult.payload == null) {
      await ctx.sendJson(
        {
          'ok': false,
          'error_code': parseResult.errorCode ?? 'PARSE_ERROR',
          'error': parseResult.errorMessage ?? 'Entrada inválida',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    final clients = await ctx.dbService.getClients();
    final analysis = ctx.syncService.analyzeForClients(
      parseResult.payload!,
      clients,
      expectedClientId: expectedClientId,
    );

    await ctx.sendJson({
      'ok': true,
      'valid': true,
      'isValid': true,
      'token': parseResult.token,
      'payload': parseResult.payload,
      'match_type': analysis['match_type'],
      'matched_client': analysis['matched_client'],
      'migration_rescue': analysis['migration_rescue'],
      'changes': analysis['changes'],
      'is_older_than_last_sync': analysis['is_older_than_last_sync'],
      'analysis': analysis,
    });
  }

  static Future<void> _handleSyncApply(AdminHttpContext ctx) async {
    final body = jsonDecode(await ctx.readBody()) as Map<String, dynamic>;
    final clientId = (body['client_id'] as String? ?? '').trim();
    final rawInput = (body['raw_input'] as String? ?? '').trim();
    final forceOlder = body['force_older'] == true;

    if (clientId.isEmpty || rawInput.isEmpty) {
      await ctx.sendJson(
        {
          'ok': false,
          'error_code': 'MISSING_FIELDS',
          'error':
              'Se requiere client_id y raw_input (ficha .mlsync o token MLS1-...).',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    final parseResult = ctx.syncService.parseRawInput(rawInput);
    if (!parseResult.valid || parseResult.payload == null) {
      await ctx.sendJson(
        {
          'ok': false,
          'error_code': parseResult.errorCode ?? 'INVALID_TOKEN',
          'error': parseResult.errorMessage ?? 'Token inválido',
        },
        statusCode: HttpStatus.badRequest,
      );
      return;
    }

    try {
      final updated = await ctx.dbService.applyClientSyncSnapshot(
        clientId,
        parseResult.payload!,
        forceOlder: forceOlder,
      );

      if (updated == null) {
        await ctx.sendJson(
          {'ok': false, 'error': 'Cliente no encontrado.'},
          statusCode: HttpStatus.notFound,
        );
      } else {
        await ctx.sendJson({
          'ok': true,
          'client': updated,
          'message': 'Sincronización aplicada exitosamente.',
        });
      }
    } on StaleSyncException catch (e) {
      await ctx.sendJson(
        {
          'ok': false,
          'error_code': 'STALE_SYNC',
          'error': e.message,
          'sync_timestamp': e.syncTimestamp.toIso8601String(),
          'last_sync_at': e.lastSyncAt.toIso8601String(),
        },
        statusCode: HttpStatus.conflict,
      );
    }
  }
}
