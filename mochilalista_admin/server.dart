import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'lib/license_signer.dart';
import 'lib/database_service.dart';
import 'lib/config_service.dart';
import 'lib/excel_export_service.dart';
import 'lib/vault_crypto_service.dart';
import 'lib/vault_storage_service.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final dbService = DatabaseService();
  await dbService.init();

  final configService = ConfigService();
  await configService.init();
  print(
      '⚙️ [ConfigService] Configuración de propietario cargada: data/owner_config.json');

  final excelService = ExcelExportService(
    dbService: dbService,
    configService: configService,
  );

  final signer = LicenseSigner();
  try {
    await signer.loadMasterKey();
    print('🔑 [LicenseSigner] Clave maestra Ed25519 cargada exitosamente.');
  } catch (e) {
    print('⚠️ [LicenseSigner] $e');
  }

  // Inicializar Servicio de Bóveda y Persistencia Fuera del Repositorio
  final vaultStorage = VaultStorageService(
    dbService: dbService,
    configService: configService,
    signer: signer,
  );
  await vaultStorage.initialize();
  final health = await vaultStorage.checkStorageHealth();
  if (health['recovery_available'] == true) {
    print('⚠️ [VaultStorage] ATENCIÓN: Modo Asistencia de Recuperación Activo.');
    print('⚠️ [VaultStorage] Espejo disponible en ${health['mirror']['mirror_dir']} para restaurar datos locales.');
  } else {
    print('🛡️ [VaultStorage] Bóveda Cifrada Activa. Espejo en: ${health['mirror']['mirror_dir']}');
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('================================================================');
  print('🚀 MOCHILALISTA ADMIN — Servidor Local de Licencias y Versiones');
  print('👤 Autor y Titular: Julio Angello Vasquez Navarro');
  print('🌐 Acceso Local: http://localhost:$port');
  print('📁 Entorno Activo: ${dbService.currentMode.toUpperCase()}');
  print('📁 Base de Datos: ${Directory('data').absolute.path}');
  print('================================================================');

  await for (HttpRequest request in server) {
    handleRequest(request, dbService, signer, configService, excelService, vaultStorage);
  }
}

Future<String> _readRequestBody(HttpRequest request) async {
  final bytes =
      await request.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
  return utf8.decode(bytes, allowMalformed: true);
}

Future<void> handleRequest(
  HttpRequest request,
  DatabaseService dbService,
  LicenseSigner signer,
  ConfigService configService,
  ExcelExportService excelService,
  VaultStorageService vaultStorage,
) async {
  final path = request.uri.path;
  final method = request.method;

  // Habilitar CORS para peticiones locales
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers
      .add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  request.response.headers.add(
      'Access-Control-Allow-Headers', 'Content-Type, X-App-Mode, X-File-Name, X-Vault-Session-Token');

  if (method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
    return;
  }

  // Sincronizar modo si viene en cabecera
  final headerMode = request.headers.value('X-App-Mode');
  if (headerMode != null && (headerMode == 'sandbox' || headerMode == 'prod')) {
    if (dbService.currentMode != headerMode) {
      dbService.setMode(headerMode);
    }
  }

  try {
    // Endpoints REST de la API
    if (path.startsWith('/api/')) {
      await _handleApiRoute(request, path, method, dbService, signer,
          configService, excelService, vaultStorage);
      return;
    }

    // Servir archivos estáticos de la interfaz web (web/)
    await _handleStaticFile(request, path);
  } catch (e, stack) {
    print('Error procesando $method $path: $e\n$stack');
    try {
      if (e is VaultAuthException) {
        request.response.statusCode = HttpStatus.unauthorized;
      } else if (e is VaultIntegrityException || e is VaultFormatException) {
        request.response.statusCode = HttpStatus.badRequest;
      } else {
        request.response.statusCode = HttpStatus.internalServerError;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    } catch (_) {}
  }
}

Future<void> _handleApiRoute(
  HttpRequest request,
  String path,
  String method,
  DatabaseService dbService,
  LicenseSigner signer,
  ConfigService configService,
  ExcelExportService excelService,
  VaultStorageService vaultStorage,
) async {
  request.response.headers.contentType = ContentType.json;

  // =================== MIDDLEWARE DE BLOQUEO PIN REAL (HTTP 423 LOCKED) ===================
  if (vaultStorage.isPinEnabled()) {
    final isExempt = path == '/api/vault/health' ||
        path == '/api/vault/pin/status' ||
        path == '/api/vault/pin/verify' ||
        path == '/api/vault/pin/recover' ||
        path == '/api/vault/pin/lock';

    if (!isExempt) {
      final token = request.headers.value('X-Vault-Session-Token') ??
          request.cookies
              .cast<Cookie?>()
              .firstWhere((c) => c?.name == 'vault_session_token', orElse: () => null)
              ?.value;

      if (!vaultStorage.isSessionValid(token)) {
        request.response.statusCode = 423; // Locked
        request.response.write(jsonEncode({
          'error': 'Session is locked. Enter PIN or recovery factor.',
          'locked': true,
        }));
        await request.response.close();
        return;
      }
    }
  }

  // =================== CONTROL DE BÓVEDA Y SEGURIDAD (/api/vault/*) ===================
  if (path == '/api/vault/health' && method == 'GET') {
    final health = await vaultStorage.checkStorageHealth();
    request.response.write(jsonEncode(health));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/sync-mirror' && method == 'POST') {
    await vaultStorage.syncMirror();
    request.response.write(jsonEncode({
      'ok': true,
      'message': 'Espejo cifrado sincronizado exitosamente.',
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/set-cloud-path' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final cloudPath = body['cloud_path'] as String?;
    await vaultStorage.setCloudSyncPath(cloudPath);
    request.response.write(jsonEncode({
      'ok': true,
      'cloud_path': cloudPath,
      'message': cloudPath != null && cloudPath.isNotEmpty
          ? 'Ruta de sincronización de nube local configurada exitosamente.'
          : 'Sincronización de nube local desactivada.',
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/recover-from-mirror' && method == 'POST') {
    VaultUnlockCredential? cred;
    final bodyStr = await _readRequestBody(request);
    if (bodyStr.trim().isNotEmpty) {
      try {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final typeStr = body['credential_type'] as String?;
        final secret = body['secret'] as String?;
        if (typeStr != null) {
          switch (typeStr) {
            case 'dpapi':
              cred = VaultUnlockCredential.dpapi();
              break;
            case 'mlkey':
              if (secret != null) cred = VaultUnlockCredential.mlKey(secret);
              break;
            case 'rescue_code':
              if (secret != null) cred = VaultUnlockCredential.rescueCode(secret);
              break;
            case 'qr_key':
              if (secret != null) cred = VaultUnlockCredential.qrKey(secret);
              break;
            case 'pin':
              if (secret != null) cred = VaultUnlockCredential.pin(secret);
              break;
          }
        }
      } catch (_) {}
    }
    final importResult = await vaultStorage.recoverFromMirror(credential: cred);
    request.response.write(jsonEncode({
      'ok': true,
      'message': 'Bóveda recuperada exitosamente desde el espejo local.',
      'manifest': importResult.internalManifest,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/export' && method == 'POST') {
    bool includeMasterKey = true;
    final bodyStr = await _readRequestBody(request);
    if (bodyStr.trim().isNotEmpty) {
      try {
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        if (body.containsKey('include_master_key')) {
          includeMasterKey = body['include_master_key'] == true;
        }
      } catch (_) {}
    }
    final vaultJson = await vaultStorage.exportPortableVault(includeMasterKey: includeMasterKey);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final filename = 'mochilalista_vault_$timestamp.mlvault';
    request.response.headers.add('Content-Disposition', 'attachment; filename="$filename"');
    request.response.write(jsonEncode({
      'ok': true,
      'filename': filename,
      'vault_json': vaultJson,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/inspect' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final vaultJson = body['vault_json'] as String? ?? '';
    final metadata = vaultStorage.inspectVault(vaultJson);
    request.response.write(jsonEncode({
      'ok': true,
      'metadata': metadata,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/import' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final vaultJson = body['vault_json'] as String? ?? '';
    final typeStr = body['credential_type'] as String? ?? 'dpapi';
    final secret = body['secret'] as String?;
    final rewrap = body['rewrap_dpapi'] as bool? ?? true;

    VaultUnlockCredential cred;
    switch (typeStr) {
      case 'mlkey':
        if (secret == null) throw VaultAuthException('Se requiere el archivo .mlkey.');
        cred = VaultUnlockCredential.mlKey(secret);
        break;
      case 'rescue_code':
        if (secret == null) throw VaultAuthException('Se requiere el Código de Rescate.');
        cred = VaultUnlockCredential.rescueCode(secret);
        break;
      case 'qr_key':
        if (secret == null) throw VaultAuthException('Se requiere la clave QR.');
        cred = VaultUnlockCredential.qrKey(secret);
        break;
      case 'pin':
        if (secret == null) throw VaultAuthException('Se requiere el PIN.');
        cred = VaultUnlockCredential.pin(secret);
        break;
      case 'dpapi':
      default:
        cred = VaultUnlockCredential.dpapi();
        break;
    }

    final importResult = await vaultStorage.importPortableVault(
      vaultJson: vaultJson,
      credential: cred,
      rewrapForCurrentDpapi: rewrap,
    );

    request.response.write(jsonEncode({
      'ok': true,
      'message': 'Bóveda importada exitosamente y servicios recargados en caliente.',
      'manifest': importResult.internalManifest,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/generate-rescue-kit' && method == 'POST') {
    final kit = await vaultStorage.generateRescueKit();
    request.response.write(jsonEncode({
      'ok': true,
      'codes': kit.codes,
      'qr_key': kit.qrKey,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/download-mlkey' && method == 'GET') {
    final mlKeyJson = await vaultStorage.downloadMlKey();
    const filename = 'llave_maestra_mochilalista.mlkey';
    request.response.headers.add('Content-Disposition', 'attachment; filename="$filename"');
    request.response.write(jsonEncode({
      'ok': true,
      'filename': filename,
      'mlkey_json': mlKeyJson,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/pin/status' && method == 'GET') {
    final token = request.headers.value('X-Vault-Session-Token') ??
        request.cookies
            .cast<Cookie?>()
            .firstWhere((c) => c?.name == 'vault_session_token', orElse: () => null)
            ?.value;
    final pinEnabled = vaultStorage.isPinEnabled();
    final locked = pinEnabled && !vaultStorage.isSessionValid(token);
    request.response.write(jsonEncode({
      'pin_enabled': pinEnabled,
      'locked': locked,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/pin/lock' && method == 'POST') {
    final token = request.headers.value('X-Vault-Session-Token') ??
        request.cookies
            .cast<Cookie?>()
            .firstWhere((c) => c?.name == 'vault_session_token', orElse: () => null)
            ?.value;
    vaultStorage.revokeSession(token);
    request.response.write(jsonEncode({
      'ok': true,
      'locked': true,
      'message': 'Consola bloqueada manualmente.',
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/pin/configure' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final enabled = body['enabled'] as bool? ?? false;
    final pin = body['pin'] as String?;
    await vaultStorage.configurePin(pin: pin, enabled: enabled);
    request.response.write(jsonEncode({
      'ok': true,
      'pin_enabled': vaultStorage.isPinEnabled(),
      'message': enabled ? 'PIN local activado exitosamente.' : 'PIN local desactivado exitosamente.',
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/pin/verify' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final pin = body['pin'] as String? ?? '';
    final res = await vaultStorage.verifyPin(pin);
    request.response.write(jsonEncode(res));
    await request.response.close();
    return;
  }

  if (path == '/api/vault/pin/recover' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final typeStr = body['credential_type'] as String? ?? 'mlkey';
    final secret = body['secret'] as String?;
    final newPin = body['new_pin'] as String?;
    final disablePin = body['disable_pin'] as bool? ?? false;

    VaultUnlockCredential cred;
    switch (typeStr) {
      case 'dpapi':
        cred = VaultUnlockCredential.dpapi();
        break;
      case 'rescue_code':
        if (secret == null) throw VaultAuthException('Se requiere el Código de Rescate.');
        cred = VaultUnlockCredential.rescueCode(secret);
        break;
      case 'qr_key':
        if (secret == null) throw VaultAuthException('Se requiere la clave QR.');
        cred = VaultUnlockCredential.qrKey(secret);
        break;
      case 'mlkey':
      default:
        if (secret == null) throw VaultAuthException('Se requiere el archivo .mlkey.');
        cred = VaultUnlockCredential.mlKey(secret);
        break;
    }

    final res = await vaultStorage.recoverPin(
      credential: cred,
      newPin: newPin,
      disablePin: disablePin,
    );
    request.response.write(jsonEncode(res));
    await request.response.close();
    return;
  }

  // =================== 0. CONTROL DE SISTEMA Y MODO DUAL ===================
  if (path == '/api/system/mode') {
    if (method == 'GET') {
      request.response.write(jsonEncode({
        'mode': dbService.currentMode,
        'label': dbService.currentMode == 'sandbox'
            ? 'Modo Pruebas (Sandbox)'
            : 'Modo Real (Producción)',
      }));
      await request.response.close();
      return;
    } else if (method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final targetMode = body['mode'] as String? ?? 'sandbox';
      dbService.setMode(targetMode);
      request.response.write(jsonEncode({
        'ok': true,
        'mode': dbService.currentMode,
        'label': dbService.currentMode == 'sandbox'
            ? 'Modo Pruebas (Sandbox)'
            : 'Modo Real (Producción)',
      }));
      await request.response.close();
      return;
    }
  }

  if (path == '/api/system/reset-sandbox' && method == 'POST') {
    await dbService.resetSandbox();
    request.response.write(jsonEncode({
      'ok': true,
      'message':
          'Entorno de pruebas Sandbox restablecido exitosamente a los datos de demostración.',
    }));
    await request.response.close();
    return;
  }

  // =================== 1. DASHBOARD FINANCIERO ===================
  if (path == '/api/dashboard' && method == 'GET') {
    final clients = await dbService.getClients();
    final releases = await dbService.getReleases();
    final now = DateTime.now();

    double totalRevenueAccumulated = 0.0;
    double totalRevenueMonth = 0.0;
    int activeCount = 0;
    int expiringSoonCount = 0;
    int expiredCount = 0;
    int perpetualCount = 0;
    int outdatedAppCount = 0;
    final List<Map<String, dynamic>> urgentActions = [];

    final latestVersion =
        releases.isNotEmpty ? releases.first['version_name'] : '9.34.0';

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
      final isPerpetual = plan == 'PERPETUO_LIBERADO' || plan == 'PERPETUO';
      final expStr = c['license_expires'] as String?;
      final expDate = expStr != null ? DateTime.tryParse(expStr) : null;

      if (isPerpetual) {
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

      if ((c['installed_version'] as String? ?? '') != latestVersion) {
        outdatedAppCount++;
      }
    }

    urgentActions.sort(
        (a, b) => (a['days_left'] as int).compareTo(b['days_left'] as int));

    final data = {
      'totalRevenueMonth': totalRevenueMonth,
      'totalRevenueAccumulated': totalRevenueAccumulated,
      'totalActiveClients': activeCount,
      'expiringSoonClients': expiringSoonCount,
      'expiredClients': expiredCount,
      'perpetualClients': perpetualCount,
      'outdatedAppClients': outdatedAppCount,
      'latestAppVersion': latestVersion,
      'urgentActions': urgentActions,
      'currentMode': dbService.currentMode,
    };

    request.response.write(jsonEncode(data));
    await request.response.close();
    return;
  }

  // =================== 2. CLIENTES ===================
  // Exportar CSV
  if ((path == '/api/clients/export-csv' || path == '/api/clients/export') &&
      method == 'GET') {
    final csvData = await dbService.exportClientsToCsv();
    request.response.headers.contentType =
        ContentType('text', 'csv', charset: 'utf-8');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="clientes_mochilalista_${dbService.currentMode}_${DateTime.now().toIso8601String().substring(0, 10)}.csv"',
    );
    request.response.write(csvData);
    await request.response.close();
    return;
  }

  // Lista o Creación de Clientes
  if (path == '/api/clients') {
    if (method == 'GET') {
      final clients = await dbService.getClients();
      request.response.write(jsonEncode(clients));
      await request.response.close();
      return;
    } else if (method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newClient = await dbService.createClient(data);
      request.response.statusCode = HttpStatus.created;
      request.response.write(jsonEncode(newClient));
      await request.response.close();
      return;
    }
  }

  // Historial detallado de cliente: /api/clients/:id/history
  if (path.startsWith('/api/clients/') &&
      path.endsWith('/history') &&
      method == 'GET') {
    final segments = path.split('/');
    if (segments.length == 5) {
      final clientId = segments[3];
      final history = await dbService.getClientHistory(clientId);
      if (history == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response
            .write(jsonEncode({'error': 'Cliente no encontrado: $clientId'}));
      } else {
        request.response.write(jsonEncode(history));
      }
      await request.response.close();
      return;
    }
  }

  // Migrar teléfono: /api/clients/:id/migrate-device
  if (path.startsWith('/api/clients/') &&
      path.endsWith('/migrate-device') &&
      method == 'POST') {
    final segments = path.split('/');
    if (segments.length == 5) {
      final clientId = segments[3];
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newDeviceId =
          (body['new_device_id'] as String? ?? '').trim().toUpperCase();
      final feeAmount = (body['fee_amount'] as num?)?.toDouble() ??
          (body['fee'] as num?)?.toDouble() ??
          configService.migrationFee;
      final paymentMethod = body['payment_method'] as String? ?? 'Yape';
      final reason = body['reason'] as String?;
      final emitImmediately =
          body['emit_immediately'] == true || body['emitImmediately'] == true;

      if (newDeviceId.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response
            .write(jsonEncode({'error': 'El nuevo DeviceID es obligatorio.'}));
        await request.response.close();
        return;
      }

      final updated = await dbService.migrateDevice(
        clientId: clientId,
        newDeviceId: newDeviceId,
        feeAmount: feeAmount,
        paymentMethod: paymentMethod,
        reason: reason,
        emitImmediately: emitImmediately,
        signer: signer,
      );

      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    }
  }

  // Marcar actualizado: /api/clients/:id/mark-updated
  if (path.startsWith('/api/clients/') &&
      path.endsWith('/mark-updated') &&
      method == 'POST') {
    final segments = path.split('/');
    if (segments.length == 5) {
      final clientId = segments[3];
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final versionName = body['version_name'] as String? ?? '9.34.0';

      final updated = await dbService.markClientUpdated(clientId, versionName);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    }
  }

  // Pagos manuales o anulación de pagos: /api/clients/:id/payments/...
  final paymentsMatch =
      RegExp(r'^/api/clients/([^/]+)/payments(?:/([^/]+))?$').firstMatch(path);
  if (paymentsMatch != null) {
    final clientId = paymentsMatch.group(1)!;
    final paymentId = paymentsMatch.group(2);

    if (paymentId == null && method == 'POST') {
      // Registrar pago manual
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final updated = await dbService.addManualPayment(clientId, body);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    } else if (paymentId != null && method == 'DELETE') {
      // Anular pago
      final updated = await dbService.deletePayment(clientId, paymentId);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response
            .write(jsonEncode({'error': 'Pago o cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    }
  }

  // Operaciones sobre Cliente Individual: GET, PUT, DELETE
  final clientSingleMatch = RegExp(r'^/api/clients/([^/]+)$').firstMatch(path);
  if (clientSingleMatch != null) {
    final clientId = clientSingleMatch.group(1)!;
    if (method == 'GET') {
      final client = await dbService.getClientById(clientId);
      if (client == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(client));
      }
      await request.response.close();
      return;
    } else if (method == 'PUT') {
      final bodyStr = await utf8.decodeStream(request);
      final updates = jsonDecode(bodyStr) as Map<String, dynamic>;
      final updated = await dbService.updateClient(clientId, updates);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    } else if (method == 'DELETE') {
      final ok = await dbService.deleteClient(clientId);
      if (!ok) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode(
            {'ok': true, 'message': 'Cliente eliminado con éxito.'}));
      }
      await request.response.close();
      return;
    }
  }

  // =================== 3. GENERACIÓN E INSPECCIÓN DE LICENCIAS ===================
  if (path == '/api/licenses/generate' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;

    final clientId = body['client_id'] as String? ?? '';
    final client = await dbService.getClientById(clientId);
    if (client == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      await request.response.close();
      return;
    }

    final plan = (body['plan'] as String? ?? 'MENSUAL').toUpperCase().trim();
    final normPlan = LicenseSigner.normalizePlanSlug(plan);
    final deviceId =
        (client['current_device_id'] as String? ?? '').trim().toUpperCase();
    final nonce = (client['next_nonce'] as num?)?.toInt() ?? 1;

    final customDays = (body['custom_days'] as num?)?.toInt();
    final defaultDays = configService.getPlanDays(normPlan, fallback: 30);
    int daysToAdd = customDays ?? defaultDays;
    final defaultPrice = configService.getPlanPrice(normPlan, fallback: 35.0);
    final paymentAmount = (body['payment_amount'] as num?)?.toDouble() ??
        (body['amount'] as num?)?.toDouble() ??
        defaultPrice;
    final paymentMethod = body['payment_method'] as String? ?? 'Yape';
    final paymentRef = (body['payment_ref'] as String?) ??
        (body['payment_reference'] as String?) ??
        'Pago registrado';
    final aiExtra = (body['custom_ai_bonus'] as num?)?.toInt() ??
        (body['ai_extra_credits'] as num?)?.toInt() ??
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

    if (customDays == null) {
      daysToAdd = configService.getPlanDays(normPlan, fallback: 30);
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

    // Regla estricta anti-doble conteo en el claim c del token:
    // Para suscripciones comerciales, el token solo lleva el bono extra (0 por defecto)
    // Para RECARGA_IA_150, el token lleva 150 (o el monto configurado)
    final tokenClaimC =
        normPlan == 'RECARGA_IA_150' ? (aiExtra > 0 ? aiExtra : 150) : aiExtra;

    // Firma asimétrica Ed25519
    final token = await signer.generateLicenseToken(
      deviceFingerprint: deviceId,
      plan: normPlan,
      daysToAdd: daysToAdd,
      nonce: nonce,
      updatesUntil: updatesUntil,
      aiExtraCredits: tokenClaimC,
      businessTag: client['business_name'] as String?,
    );

    // Persistencia en base de datos (acumula base + bono)
    final updatedClient = await dbService.recordCodeEmission(
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

    final baseAi = configService.getPlanAiCredits(normPlan,
        fallback: LicenseSigner.getCumulativeScansForPlan(normPlan));
    final totalCredited = baseAi + aiExtra;

    request.response.write(jsonEncode({
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
      'client': updatedClient,
    }));
    await request.response.close();
    return;
  }

  // Inspección de Token Forense
  if (path == '/api/licenses/inspect' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final token = (body['token'] as String? ?? '').trim();

    final result = await signer.inspectToken(token);

    // Si es válido, cruzar con la base de datos de clientes
    if (result['isValid'] == true && result['deviceId'] != null) {
      final clients = await dbService.getClients();
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
        };
      } catch (_) {
        result['matching_client'] = null;
      }
    }

    request.response.write(jsonEncode(result));
    await request.response.close();
    return;
  }

  // =================== 4. FINANZAS Y LIBRO CONTABLE ===================
  if (path == '/api/finances' && method == 'GET') {
    final finances = await dbService.getConsolidatedFinances();
    request.response.write(jsonEncode(finances));
    await request.response.close();
    return;
  }

  if ((path == '/api/finances/export-csv' || path == '/api/finances/export') &&
      method == 'GET') {
    final csvData = await dbService.exportFinancesToCsv();
    request.response.headers.contentType =
        ContentType('text', 'csv', charset: 'utf-8');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="libro_contable_${dbService.currentMode}_${DateTime.now().toIso8601String().substring(0, 10)}.csv"',
    );
    request.response.write(csvData);
    await request.response.close();
    return;
  }

  // =================== EXPORTACIÓN PROFESIONAL A EXCEL (.XLSX) ===================
  // 1. Libro Maestro de 5 Hojas Oficiales
  if ((path == '/api/export/excel-master' || path == '/api/export/excel') &&
      method == 'GET') {
    final bytes = await excelService.generateMasterWorkbook();
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    request.response.headers.contentType = ContentType(
        'application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="MochilaLista_Reporte_Maestro_${dbService.currentMode}_$dateStr.xlsx"',
    );
    request.response.add(bytes);
    await request.response.close();
    return;
  }

  // 2. Reporte Financiero Filtrado por Rango de Fechas
  if ((path == '/api/export/excel-finances' ||
          path == '/api/finances/export-excel') &&
      method == 'GET') {
    final fromDate = request.uri.queryParameters['from'];
    final toDate = request.uri.queryParameters['to'];
    final bytes = await excelService.generateFinancesReport(
        fromDate: fromDate, toDate: toDate);
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    request.response.headers.contentType = ContentType(
        'application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="MochilaLista_Reporte_Financiero_${dbService.currentMode}_$dateStr.xlsx"',
    );
    request.response.add(bytes);
    await request.response.close();
    return;
  }

  // =================== 5. CENTRO DE RESPALDOS EN DISCO (BACKUPS) ===================
  if (path == '/api/backups' && method == 'GET') {
    final backups = await dbService.listBackups();
    request.response.write(jsonEncode(backups));
    await request.response.close();
    return;
  }

  if (path == '/api/backups/create' && method == 'POST') {
    final res = await dbService.createManualBackup();
    request.response.write(jsonEncode(res));
    await request.response.close();
    return;
  }

  if (path == '/api/backups/open-folder' && method == 'POST') {
    final dirPath = Directory(dbService.backupDir).absolute.path;
    if (Platform.isWindows) {
      try {
        Process.run('explorer.exe', [dirPath]);
      } catch (_) {}
    }
    request.response.write(jsonEncode({'ok': true, 'path': dirPath}));
    await request.response.close();
    return;
  }

  if (path.startsWith('/api/backups/download/') && method == 'GET') {
    final filename = path.replaceFirst('/api/backups/download/', '').trim();
    final file = File('${dbService.backupDir}/$filename');
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response
          .write(jsonEncode({'error': 'Archivo de backup no encontrado'}));
      await request.response.close();
      return;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="$filename"',
    );
    await file.openRead().pipe(request.response);
    return;
  }

  if (path == '/api/backups/restore' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final filename = body['filename'] as String? ?? '';
    final ok = await dbService.restoreFromBackup(filename);
    if (ok) {
      request.response.write(jsonEncode({
        'ok': true,
        'message': 'Base de datos restaurada al punto $filename exitosamente.',
      }));
    } else {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'error':
            'No se pudo restaurar desde $filename. Verifique que el archivo exista en backups/.',
      }));
    }
    await request.response.close();
    return;
  }

  // =================== 6. LANZAMIENTOS (RELEASES) Y APKS ===================
  // Carga directa de APK desde PC (Binary stream)
  if (path == '/api/releases/upload-apk' && method == 'POST') {
    final queryName = request.uri.queryParameters['filename'] ??
        request.headers.value('X-File-Name') ??
        'mochilalista-uploaded.apk';
    final safeFileName = queryName.replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');

    final targetDir = dbService.currentReleasesApkDir;
    await targetDir.create(recursive: true);
    final targetFile = File('${targetDir.path}/$safeFileName');

    final bytesBuilder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      bytesBuilder.add(chunk);
    }
    final allBytes = bytesBuilder.takeBytes();
    await targetFile.writeAsBytes(allBytes);

    final sha256Digest = sha256.convert(allBytes).toString().toLowerCase();
    final sizeMb = (allBytes.length / (1024 * 1024)).toStringAsFixed(2);

    request.response.write(jsonEncode({
      'ok': true,
      'file_name': safeFileName,
      'file_path': targetFile.path,
      'sha256': sha256Digest,
      'file_size_mb': '$sizeMb MB',
    }));
    await request.response.close();
    return;
  }

  // Autodetectar e importar build local compilado con Flutter (priorizando arm64-v8a ligero)
  if (path == '/api/releases/detect-local-build' && method == 'GET') {
    final candidateFiles = [
      File(
          '../app_movil/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'),
      File('../app_movil/build/app/outputs/flutter-apk/app-release.apk'),
      File('releases_apks/${dbService.currentMode}/mochilalista-release.apk'),
    ];

    String versionName = '9.34.0';
    int versionCode = 78;
    final pubspec = File('../app_movil/pubspec.yaml');
    if (await pubspec.exists()) {
      final lines = await pubspec.readAsLines();
      for (final line in lines) {
        if (line.trim().startsWith('version:')) {
          final vPart = line.replaceFirst('version:', '').trim();
          final parts = vPart.split('+');
          if (parts.isNotEmpty) versionName = parts[0];
          if (parts.length > 1) versionCode = int.tryParse(parts[1]) ?? 78;
          break;
        }
      }
    }

    // Lector auxiliar no destructivo de novedades comerciales desde app_changelog_registry.dart
    String suggestedChangelog = '';
    final changelogFile =
        File('../app_movil/lib/core/config/app_changelog_registry.dart');
    if (await changelogFile.exists()) {
      try {
        final content = await changelogFile.readAsString();
        final matches = RegExp(
                r'title:\s*["\x27](.+?)["\x27],\s*description:\s*["\x27](.+?)["\x27]',
                dotAll: true)
            .allMatches(content);
        final bullets = <String>[];
        for (final m in matches) {
          final title = m.group(1)?.trim() ?? '';
          final desc = m.group(2)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
          if (title.isNotEmpty) {
            bullets.add('• $title: $desc');
          }
          if (bullets.length >= 4) break;
        }
        if (bullets.isNotEmpty) {
          suggestedChangelog = bullets.join('\n');
        }
      } catch (_) {}
    }

    final List<Map<String, dynamic>> availableBuilds = [];
    File? selectedFile;

    for (final f in candidateFiles) {
      if (await f.exists()) {
        final b = await f.readAsBytes();
        final s = sha256.convert(b).toString().toLowerCase();
        final mb = (b.length / (1024 * 1024)).toStringAsFixed(2);
        final fname = f.uri.pathSegments.last;
        final isArm64 = fname.contains('arm64');
        final type = isArm64 ? 'arm64_light' : 'universal';
        final label = isArm64
            ? 'APK Ligero ARM64 (Optimizado WhatsApp)'
            : 'APK Universal (Todas las arquitecturas)';

        final info = {
          'file_name': fname,
          'file_path': f.path,
          'size_mb': '$mb MB',
          'sha256': s,
          'architecture': isArm64 ? 'arm64-v8a' : 'universal',
          'type': type,
          'label': label,
        };
        availableBuilds.add(info);

        selectedFile ??= f;
      }
    }

    if (selectedFile != null) {
      final bytes = await selectedFile.readAsBytes();
      final sha = sha256.convert(bytes).toString().toLowerCase();
      final sizeMb = (bytes.length / (1024 * 1024)).toStringAsFixed(2);

      // Copiar al almacén físico del modo activo
      final targetDir = dbService.currentReleasesApkDir;
      await targetDir.create(recursive: true);
      final destFile = File('${targetDir.path}/mochilalista-v$versionName.apk');
      await selectedFile.copy(destFile.path);

      request.response.write(jsonEncode({
        'apk_found': true,
        'version_name': versionName,
        'version_code': versionCode,
        'db_schema_version': 36,
        'min_required_version': '9.0.0',
        'file_name': selectedFile.uri.pathSegments.last,
        'file_path': destFile.path,
        'file_size_mb': '$sizeMb MB',
        'sha256': sha,
        'suggested_changelog': suggestedChangelog,
        'available_builds': availableBuilds,
      }));
    } else {
      request.response.write(jsonEncode({
        'apk_found': false,
        'version_name': versionName,
        'version_code': versionCode,
        'db_schema_version': 36,
        'min_required_version': '9.0.0',
        'suggested_changelog': suggestedChangelog,
        'available_builds': [],
        'message':
            'No se encontró archivo APK en build/app/outputs/flutter-apk/ (ejecute compilar_apk_arm64.bat o compilar_apk_comercial.bat).',
      }));
    }
    await request.response.close();
    return;
  }

  // Descarga directa del APK almacenado físicamente
  if (path.startsWith('/api/releases/download/') && method == 'GET') {
    final versionName = path.replaceFirst('/api/releases/download/', '').trim();
    final release = await dbService.getReleaseByVersion(versionName);

    File? apkFile;
    if (release != null &&
        (release['apk_file_path'] as String? ?? '').isNotEmpty) {
      final f = File(release['apk_file_path'] as String);
      if (await f.exists()) apkFile = f;
    }

    if (apkFile == null) {
      // Buscar en releases_apks/{mode}/
      final candidates = [
        File(
            'releases_apks/${dbService.currentMode}/mochilalista-v$versionName.apk'),
        File(
            'releases_apks/${dbService.currentMode}/mochilalista-$versionName.apk'),
        File('../app_movil/build/app/outputs/flutter-apk/app-release.apk'),
      ];
      for (final c in candidates) {
        if (await c.exists()) {
          apkFile = c;
          break;
        }
      }
    }

    if (apkFile == null || !await apkFile.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({
        'error':
            'Archivo APK no encontrado en disco para la versión $versionName'
      }));
      await request.response.close();
      return;
    }

    request.response.headers.contentType =
        ContentType('application', 'vnd.android.package-archive');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="mochilalista-v$versionName.apk"',
    );
    await apkFile.openRead().pipe(request.response);
    return;
  }

  // Mostrar archivo APK en el Explorador de Windows (explorer.exe /select,...)
  if (path == '/api/releases/reveal-file' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final versionName = body['version_name'] as String? ?? '';
    final release = await dbService.getReleaseByVersion(versionName);

    String? fullPath = release?['apk_file_path'] as String?;
    if (fullPath == null || !File(fullPath).existsSync()) {
      final local = File(
          'releases_apks/${dbService.currentMode}/mochilalista-v$versionName.apk');
      if (local.existsSync()) fullPath = local.absolute.path;
    }

    if (fullPath != null && File(fullPath).existsSync()) {
      if (Platform.isWindows) {
        try {
          Process.run(
              'explorer.exe', ['/select,', File(fullPath).absolute.path]);
        } catch (_) {}
      }
      request.response.write(jsonEncode({'ok': true, 'path': fullPath}));
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode(
          {'error': 'No se encontró archivo físico para esta versión'}));
    }
    await request.response.close();
    return;
  }

  // Matriz de distribución
  if ((path == '/api/releases/matrix' ||
          path == '/api/releases/distribution-matrix') &&
      method == 'GET') {
    final matrix = await dbService.getUpdateDistributionMatrix();
    request.response.write(jsonEncode(matrix));
    await request.response.close();
    return;
  }

  // Catálogo de releases: GET y POST
  if (path == '/api/releases') {
    if (method == 'GET') {
      final releases = await dbService.getReleases();
      request.response.write(jsonEncode(releases));
      await request.response.close();
      return;
    } else if (method == 'POST') {
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newRelease = await dbService.createRelease(body);
      request.response.statusCode = HttpStatus.created;
      request.response.write(jsonEncode(newRelease));
      await request.response.close();
      return;
    }
  }

  // Operaciones sobre versión individual: PUT (editar changelog) y DELETE (eliminar)
  final releaseSingleMatch =
      RegExp(r'^/api/releases/([^/]+)$').firstMatch(path);
  if (releaseSingleMatch != null) {
    final ver = releaseSingleMatch.group(1)!;
    if (method == 'PUT') {
      final bodyStr = await utf8.decodeStream(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final updated = await dbService.updateRelease(ver, body);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Versión no encontrada'}));
      } else {
        request.response.write(jsonEncode(updated));
      }
      await request.response.close();
      return;
    } else if (method == 'DELETE') {
      final ok = await dbService.deleteRelease(ver);
      if (!ok) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Versión no encontrada'}));
      } else {
        request.response.write(jsonEncode(
            {'ok': true, 'message': 'Versión eliminada con éxito.'}));
      }
      await request.response.close();
      return;
    }
  }

  // =================== 7. CENTRO DE PERSONALIZACIÓN DEL PROPIETARIO (PLAN 09) ===================
  if ((path == '/api/config' || path == '/api/config/owner') &&
      method == 'GET') {
    request.response.write(jsonEncode(configService.config));
    await request.response.close();
    return;
  }

  if ((path == '/api/config' || path == '/api/config/owner') &&
      method == 'PUT') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final updated = await configService.saveConfig(body);
    request.response.write(jsonEncode(updated));
    await request.response.close();
    return;
  }

  if ((path == '/api/config/reset' || path == '/api/config/owner/reset') &&
      method == 'POST') {
    final restored = await configService.resetToDefaults();
    request.response.write(jsonEncode({
      'ok': true,
      'message':
          'Configuración del propietario restablecida a los valores oficiales de fábrica.',
      'config': restored,
    }));
    await request.response.close();
    return;
  }

  if (path == '/api/config/preview-template' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final templateKey = body['template_key'] as String?;
    final rawTemplate = body['template'] as String?;
    final context = (body['context'] as Map<String, dynamic>?) ?? {};

    final target = (rawTemplate != null && rawTemplate.isNotEmpty)
        ? rawTemplate
        : (templateKey ?? '');

    final rendered = configService.renderTemplate(target, context);
    request.response.write(jsonEncode({
      'ok': true,
      'rendered': rendered,
    }));
    await request.response.close();
    return;
  }

  // Ruta API no encontrada
  request.response.statusCode = HttpStatus.notFound;
  request.response.write(jsonEncode({'error': 'Ruta no encontrada: $path'}));
  await request.response.close();
}

Future<void> _handleStaticFile(HttpRequest request, String path) async {
  String filePath = path == '/' ? 'web/index.html' : 'web$path';
  final file = File(filePath);

  if (await file.exists()) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'html':
        request.response.headers.contentType = ContentType.html;
        break;
      case 'css':
        request.response.headers.contentType =
            ContentType('text', 'css', charset: 'utf-8');
        break;
      case 'js':
        request.response.headers.contentType =
            ContentType('application', 'javascript', charset: 'utf-8');
        break;
      case 'json':
        request.response.headers.contentType = ContentType.json;
        break;
      case 'png':
        request.response.headers.contentType = ContentType('image', 'png');
        break;
      case 'jpg':
      case 'jpeg':
        request.response.headers.contentType = ContentType('image', 'jpeg');
        break;
      case 'svg':
        request.response.headers.contentType = ContentType('image', 'svg+xml');
        break;
      default:
        request.response.headers.contentType = ContentType.binary;
    }
    await file.openRead().pipe(request.response);
  } else {
    // Si no existe, servir index.html como fallback SPA
    final indexFile = File('web/index.html');
    if (await indexFile.exists()) {
      request.response.headers.contentType = ContentType.html;
      await indexFile.openRead().pipe(request.response);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Página no encontrada');
      await request.response.close();
    }
  }
}
