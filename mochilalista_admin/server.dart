import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'lib/license_signer.dart';
import 'lib/database_service.dart';
import 'lib/config_service.dart';
import 'lib/excel_export_service.dart';
import 'lib/vault_crypto_service.dart';
import 'lib/vault_storage_service.dart';
import 'lib/apk_inspector_service.dart';
import 'lib/client_sync_service.dart';

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
    print(
        '⚠️ [VaultStorage] ATENCIÓN: Modo Asistencia de Recuperación Activo.');
    print(
        '⚠️ [VaultStorage] Espejo disponible en ${health['mirror']['mirror_dir']} para restaurar datos locales.');
  } else {
    print(
        '🛡️ [VaultStorage] Bóveda Cifrada Activa. Espejo en: ${health['mirror']['mirror_dir']}');
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
    handleRequest(
        request, dbService, signer, configService, excelService, vaultStorage);
  }
}

Future<String> _readRequestBody(HttpRequest request) async {
  final bytes =
      await request.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
  return utf8.decode(bytes, allowMalformed: true);
}

/// Construye argumentos seguros de PowerShell `-NoProfile -STA` para copiar
/// un archivo real como `CF_HDROP` (`FileDrop` + `Preferred DropEffect` COPY)
/// compatible con WhatsApp Desktop / Chromium / Explorador de Windows.
List<String> buildWindowsClipboardPsArgs(String fullPath) {
  final escaped = fullPath.replaceAll("'", "''");
  final psScript = [
    'Add-Type -AssemblyName System.Windows.Forms',
    r"$p = '" + escaped + "'",
    r"if (-not (Test-Path -LiteralPath $p)) { Write-Error ('Archivo no encontrado: ' + $p); exit 2 }",
    r'$dataObj = New-Object System.Windows.Forms.DataObject',
    r'$col = New-Object System.Collections.Specialized.StringCollection',
    r'[void]$col.Add($p)',
    r'$dataObj.SetFileDropList($col)',
    r'$dropEffect = New-Object System.IO.MemoryStream(, [byte[]](5,0,0,0))',
    r"$dataObj.SetData('Preferred DropEffect', $dropEffect)",
    r'[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true, 10, 50)',
  ].join('; ');
  return ['-NoProfile', '-STA', '-Command', psScript];
}

/// Comparador SemVer riguroso (major.minor.patch)
int compareSemVer(String v1, String v2) {
  List<int> parse(String v) {
    final clean = v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first;
    final parts = clean.split('.');
    return [
      parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 0) : 0,
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0,
    ];
  }

  final p1 = parse(v1);
  final p2 = parse(v2);
  for (int i = 0; i < 3; i++) {
    if (p1[i] != p2[i]) return p1[i].compareTo(p2[i]);
  }
  return 0;
}

Future<void> _launchBrowserDetached(String url) async {
  if (Platform.isWindows) {
    final programFiles =
        Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final programFilesX86 =
        Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final localAppData = Platform.environment['LocalAppData'] ?? '';

    final chromeCandidates = [
      '$programFiles\\Google\\Chrome\\Application\\chrome.exe',
      '$programFilesX86\\Google\\Chrome\\Application\\chrome.exe',
      if (localAppData.isNotEmpty)
        '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
    ];

    String? chromeBin;
    for (final cand in chromeCandidates) {
      if (File(cand).existsSync()) {
        chromeBin = cand;
        break;
      }
    }

    if (chromeBin != null) {
      await Process.start(chromeBin, [url], mode: ProcessStartMode.detached);
      return;
    }

    final edgeCandidates = [
      '$programFilesX86\\Microsoft\\Edge\\Application\\msedge.exe',
      '$programFiles\\Microsoft\\Edge\\Application\\msedge.exe',
    ];
    String? edgeBin;
    for (final cand in edgeCandidates) {
      if (File(cand).existsSync()) {
        edgeBin = cand;
        break;
      }
    }

    if (edgeBin != null) {
      await Process.start(edgeBin, [url], mode: ProcessStartMode.detached);
      return;
    }

    await Process.start('cmd.exe', ['/c', 'start', '""', url],
        mode: ProcessStartMode.detached);
  } else if (Platform.isMacOS) {
    await Process.start('open', [url], mode: ProcessStartMode.detached);
  } else {
    await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
  }
}

Future<void> handleRequest(
  HttpRequest request,
  DatabaseService dbService,
  LicenseSigner signer,
  ConfigService configService,
  ExcelExportService excelService,
  VaultStorageService vaultStorage, {
  void Function(int code)? onExitOverride,
  Future<void> Function(String url)? onOpenBrowserOverride,
  ApkInspectorService? apkInspectorService,
  Future<bool> Function(String filePath)? onCopyFileOverride,
  ClientSyncService? clientSyncService,
}) async {
  final path = request.uri.path;
  final method = request.method;

  // Habilitar CORS para peticiones locales
  request.response.headers.add('Access-Control-Allow-Origin', '*');
  request.response.headers
      .add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  request.response.headers.add('Access-Control-Allow-Headers',
      'Content-Type, X-App-Mode, X-File-Name, X-Vault-Session-Token');

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
          configService, excelService, vaultStorage,
          onExitOverride: onExitOverride,
          onOpenBrowserOverride: onOpenBrowserOverride,
          apkInspectorService: apkInspectorService,
          onCopyFileOverride: onCopyFileOverride,
          clientSyncService: clientSyncService);
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
  VaultStorageService vaultStorage, {
  void Function(int code)? onExitOverride,
  Future<void> Function(String url)? onOpenBrowserOverride,
  ApkInspectorService? apkInspectorService,
  Future<bool> Function(String filePath)? onCopyFileOverride,
  ClientSyncService? clientSyncService,
}) async {
  final inspector = apkInspectorService ?? ApkInspectorService();
  final syncService = clientSyncService ?? ClientSyncService();
  request.response.headers.contentType = ContentType.json;

  // =================== MIDDLEWARE DE BLOQUEO PIN REAL (HTTP 423 LOCKED) ===================
  if (vaultStorage.isPinEnabled()) {
    final isExempt = path == '/api/vault/health' ||
        path == '/api/vault/pin/status' ||
        path == '/api/vault/pin/verify' ||
        path == '/api/vault/pin/recover' ||
        path == '/api/vault/pin/lock' ||
        path == '/api/system/open-browser';

    if (!isExempt) {
      final token = request.headers.value('X-Vault-Session-Token') ??
          request.cookies
              .cast<Cookie?>()
              .firstWhere((c) => c?.name == 'vault_session_token',
                  orElse: () => null)
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
              if (secret != null)
                cred = VaultUnlockCredential.rescueCode(secret);
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
    final vaultJson = await vaultStorage.exportPortableVault(
        includeMasterKey: includeMasterKey);
    final timestamp =
        DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final filename = 'mochilalista_vault_$timestamp.mlvault';
    request.response.headers
        .add('Content-Disposition', 'attachment; filename="$filename"');
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
        if (secret == null)
          throw VaultAuthException('Se requiere el archivo .mlkey.');
        cred = VaultUnlockCredential.mlKey(secret);
        break;
      case 'rescue_code':
        if (secret == null)
          throw VaultAuthException('Se requiere el Código de Rescate.');
        cred = VaultUnlockCredential.rescueCode(secret);
        break;
      case 'qr_key':
        if (secret == null)
          throw VaultAuthException('Se requiere la clave QR.');
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
      'message':
          'Bóveda importada exitosamente y servicios recargados en caliente.',
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
    request.response.headers
        .add('Content-Disposition', 'attachment; filename="$filename"');
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
            .firstWhere((c) => c?.name == 'vault_session_token',
                orElse: () => null)
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
            .firstWhere((c) => c?.name == 'vault_session_token',
                orElse: () => null)
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
      'message': enabled
          ? 'PIN local activado exitosamente.'
          : 'PIN local desactivado exitosamente.',
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
        if (secret == null)
          throw VaultAuthException('Se requiere el Código de Rescate.');
        cred = VaultUnlockCredential.rescueCode(secret);
        break;
      case 'qr_key':
        if (secret == null)
          throw VaultAuthException('Se requiere la clave QR.');
        cred = VaultUnlockCredential.qrKey(secret);
        break;
      case 'mlkey':
      default:
        if (secret == null)
          throw VaultAuthException('Se requiere el archivo .mlkey.');
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
  if (path == '/api/system/mode' || path == '/api/mode') {
    if (method == 'GET') {
      request.response.write(jsonEncode({
        'ok': true,
        'mode': dbService.currentMode,
        'label': dbService.currentMode == 'sandbox'
            ? 'Modo Pruebas (Sandbox)'
            : 'Modo Real (Producción)',
      }));
      await request.response.close();
      return;
    } else if (method == 'POST') {
      final bodyStr = await _readRequestBody(request);
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

  // Apertura de navegador Google Chrome / sistema: /api/system/open-browser
  if (path == '/api/system/open-browser' && method == 'POST') {
    const targetUrl = 'http://localhost:8080';
    if (onOpenBrowserOverride != null) {
      await onOpenBrowserOverride(targetUrl);
    } else {
      await _launchBrowserDetached(targetUrl);
    }
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'ok': true,
      'url': targetUrl,
      'message': 'Navegador iniciado exitosamente.',
    }));
    await request.response.close();
    return;
  }

  // Apagado limpio y seguro del servidor: /api/system/shutdown
  // Protegido por el middleware de bloqueo PIN real (HTTP 423 si la sesión está bloqueada)
  if (path == '/api/system/shutdown' && method == 'POST') {
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({
      'ok': true,
      'message': 'Servidor administrativo apagado correctamente.',
    }));
    await request.response.close();

    // Invocar el callback de salida inyectable (onExitOverride) o exit(0) tras un breve margen para liberar la conexión HTTP
    Future.delayed(const Duration(milliseconds: 250), () {
      if (onExitOverride != null) {
        onExitOverride(0);
      } else {
        exit(0);
      }
    });
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
    int prospectCount = 0;
    int outdatedAppCount = 0;
    final List<Map<String, dynamic>> urgentActions = [];

    // Determinar la versión máxima publicada usando SemVer riguroso
    String? latestVersion;
    for (final r in releases) {
      final vn = r['version_name'] as String? ?? '';
      if (vn.trim().isNotEmpty) {
        if (latestVersion == null || compareSemVer(vn, latestVersion) > 0) {
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
          compareSemVer(clientVer, latestVersion) < 0) {
        outdatedAppCount++;
      }
    }

    urgentActions.sort(
        (a, b) => (a['days_left'] as int).compareTo(b['days_left'] as int));

    final data = {
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
      final bodyStr = await _readRequestBody(request);
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;
      try {
        final newClient = await dbService.createClient(data);
        request.response.statusCode = HttpStatus.created;
        request.response.write(jsonEncode(newClient));
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
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
      final bodyStr = await _readRequestBody(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newDeviceId =
          (body['new_device_id'] as String? ?? '').trim().toUpperCase();
      final feeMode = (body['fee_mode'] as String? ?? 'STANDARD').toUpperCase();
      double feeAmount = (body['fee_amount'] as num?)?.toDouble() ??
          (body['fee'] as num?)?.toDouble() ??
          configService.migrationFee;
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
        migrationScenario: migrationScenario,
        newDeviceModel: newDeviceModel,
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
      final bodyStr = await _readRequestBody(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final versionName = (body['version_name'] as String? ?? '9.34.0').trim();
      final bool force = body['force'] == true;

      final updated = await dbService.markClientUpdated(clientId, versionName,
          force: force);
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
      } else {
        request.response.write(jsonEncode({
          ...updated,
          'force_applied': force,
          'previous_installed_version': updated['previous_installed_version'],
        }));
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
      final bodyStr = await _readRequestBody(request);
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
    } else if (paymentId != null && method == 'PUT') {
      // Editar pago existente (Plan Maestro 18 - Fase 4)
      try {
        final bodyStr = await _readRequestBody(request);
        final body = jsonDecode(bodyStr) as Map<String, dynamic>;
        final updated =
            await dbService.updatePayment(clientId, paymentId, body);
        if (updated == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response
              .write(jsonEncode({'error': 'Pago o cliente no encontrado'}));
        } else {
          request.response.write(jsonEncode(updated));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        final msg = (e is ArgumentError) ? e.message.toString() : e.toString();
        request.response.write(jsonEncode({'error': msg}));
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

  // Emisión y consulta de Boleta de Pago Oficial: /api/clients/:id/payments/:paymentId/receipt
  final receiptMatch =
      RegExp(r'^/api/clients/([^/]+)/payments/([^/]+)/receipt$')
          .firstMatch(path);
  if (receiptMatch != null && method == 'POST') {
    final clientId = receiptMatch.group(1)!;
    final paymentId = receiptMatch.group(2)!;
    final bodyStr = await _readRequestBody(request);
    Map<String, dynamic> body = {};
    if (bodyStr.isNotEmpty) {
      try {
        body = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {}
    }
    final customNote = body['custom_note'] as String?;
    final voucherType = body['voucher_type'] as String?;
    final invoiceRuc = body['invoice_ruc'] as String?;
    final invoiceBusinessName = body['invoice_business_name'] as String?;
    final invoiceFiscalAddress = body['invoice_fiscal_address'] as String?;
    final showIgvBreakdown = body['show_igv_breakdown'] as bool?;

    try {
      final receiptData = await dbService.issueOrGetPaymentReceipt(
        clientId: clientId,
        paymentId: paymentId,
        customNote: customNote,
        voucherType: voucherType,
        invoiceRuc: invoiceRuc,
        invoiceBusinessName: invoiceBusinessName,
        invoiceFiscalAddress: invoiceFiscalAddress,
        showIgvBreakdown: showIgvBreakdown,
        configService: configService,
      );

      if (receiptData == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response
            .write(jsonEncode({'error': 'Cliente o pago no encontrado'}));
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode(receiptData));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': e.toString()}));
    }
    await request.response.close();
    return;
  }

  // Operaciones sobre Cliente Individual: GET, PUT, DELETE
  // Sincronización de datos reales reportados del celular: /api/clients/:id/sync-reported
  final syncReportedMatch =
      RegExp(r'^/api/clients/([^/]+)/sync-reported$').firstMatch(path);
  if (syncReportedMatch != null && method == 'POST') {
    final clientId = syncReportedMatch.group(1)!;
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    try {
      final updated = await dbService.syncClientReportedState(
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
        request.response.statusCode = HttpStatus.notFound;
        request.response
            .write(jsonEncode({'error': 'Cliente no encontrado: $clientId'}));
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode(updated));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': e.toString()}));
    }
    await request.response.close();
    return;
  }

  // Edición del motivo en historial de migraciones de hardware: /api/clients/:id/device-history/:index
  final devHistoryMatch =
      RegExp(r'^/api/clients/([^/]+)/device-history/(\d+)$').firstMatch(path);
  if (devHistoryMatch != null && method == 'PUT') {
    final clientId = devHistoryMatch.group(1)!;
    final historyIndex = int.parse(devHistoryMatch.group(2)!);
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final reason = (body['reason'] as String? ?? '').trim();

    try {
      final updated = await dbService.updateDeviceHistoryReason(
        clientId: clientId,
        historyIndex: historyIndex,
        reason: reason,
      );
      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(
            {'error': 'Cliente o registro de migración no encontrado'}));
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({
          'ok': true,
          'message': 'Motivo de migración actualizado exitosamente',
          'client': updated,
        }));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': e.toString()}));
    }
    await request.response.close();
    return;
  }

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
      final bodyStr = await _readRequestBody(request);
      final updates = jsonDecode(bodyStr) as Map<String, dynamic>;
      try {
        final updated = await dbService.updateClient(clientId, updates);
        if (updated == null) {
          request.response.statusCode = HttpStatus.notFound;
          request.response
              .write(jsonEncode({'error': 'Cliente no encontrado'}));
        } else {
          request.response.write(jsonEncode(updated));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': e.toString()}));
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
    final defaultPrice = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? 0.0
        : configService.getPlanPrice(normPlan, fallback: 35.0);
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
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({
          'error':
              'Para la modalidad Bono / Recarga IA Personalizada debes especificar una cantidad de escaneos IA mayor a 0.'
        }));
        await request.response.close();
        return;
      }
    } else if (customDays == null) {
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
    // Para BONO_IA_PERSONALIZADO, el token lleva la cantidad exacta solicitada
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

    final baseAi = (normPlan == 'BONO_IA_PERSONALIZADO')
        ? 0
        : configService.getPlanAiCredits(normPlan,
            fallback: LicenseSigner.getCumulativeScansForPlan(normPlan));
    final totalCredited = baseAi + aiExtra;
    final lastCode =
        (updatedClient?['generated_codes_history'] as List?)?.isNotEmpty == true
            ? (updatedClient!['generated_codes_history'] as List).last
                as Map<String, dynamic>?
            : null;

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
      'payment_id': lastCode?['payment_id'],
      'amount_paid': lastCode?['amount_paid'] ?? 0.0,
      'client': updatedClient,
    }));
    await request.response.close();
    return;
  }

  // Inspección de Token Forense (Soporte Dual: Tokens de Licencia ML9-... y Fichas de Sincronización MLS1-...)
  if (path == '/api/licenses/inspect' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final token = (body['token'] as String? ?? '').trim();

    // Detección automática de ficha de sincronización offline (.mlsync o token MLS1-...)
    if (token.contains('MLS1-') ||
        token.contains('MLSYNC_V1') ||
        token.contains('"format": "MLSYNC_V1"') ||
        token.contains('"format":"MLSYNC_V1"')) {
      final syncResult = syncService.parseRawInput(token);
      if (syncResult.valid && syncResult.payload != null) {
        final clients = await dbService.getClients();
        final analysis =
            syncService.analyzeForClients(syncResult.payload!, clients);
        request.response.write(jsonEncode({
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
        }));
      } else {
        request.response.write(jsonEncode({
          'ok': false,
          'input_kind': 'CLIENT_SYNC',
          'valid': false,
          'isValid': false,
          'error_code': syncResult.errorCode,
          'error': syncResult.errorMessage,
        }));
      }
      await request.response.close();
      return;
    }

    final result = await signer.inspectToken(token);
    result['input_kind'] = 'LICENSE_TOKEN';

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

    request.response.write(jsonEncode(result));
    await request.response.close();
    return;
  }

  // =================== 3C. PROTOCOLO DUAL DE SINCRONIZACIÓN OFFLINE (.mlsync / MLS1-...) (PLAN 19 FASE 4) ===================
  // Parser universal: extrae, valida firma HMAC-SHA256, cruza con clientes, calcula diff y rescate de migración
  if (path == '/api/sync/parse' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final rawInput = (body['raw_input'] as String? ?? '').trim();
    final expectedClientId = (body['expected_client_id'] as String?)?.trim();

    final parseResult = syncService.parseRawInput(rawInput);
    if (!parseResult.valid || parseResult.payload == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'ok': false,
        'error_code': parseResult.errorCode ?? 'PARSE_ERROR',
        'error': parseResult.errorMessage ?? 'Entrada inválida',
      }));
      await request.response.close();
      return;
    }

    final clients = await dbService.getClients();
    final analysis = syncService.analyzeForClients(
      parseResult.payload!,
      clients,
      expectedClientId: expectedClientId,
    );

    request.response.write(jsonEncode({
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
    }));
    await request.response.close();
    return;
  }

  // Aplicar sincronización real verificada en servidor con protección anti-sobreescritura
  if (path == '/api/sync/apply' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final clientId = (body['client_id'] as String? ?? '').trim();
    final rawInput = (body['raw_input'] as String? ?? '').trim();
    final forceOlder = body['force_older'] == true;

    if (clientId.isEmpty || rawInput.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'ok': false,
        'error_code': 'MISSING_FIELDS',
        'error':
            'Se requiere client_id y raw_input (ficha .mlsync o token MLS1-...).',
      }));
      await request.response.close();
      return;
    }

    // Re-verificar firma HMAC en servidor (defensa en profundidad)
    final parseResult = syncService.parseRawInput(rawInput);
    if (!parseResult.valid || parseResult.payload == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'ok': false,
        'error_code': parseResult.errorCode ?? 'INVALID_TOKEN',
        'error': parseResult.errorMessage ?? 'Token inválido',
      }));
      await request.response.close();
      return;
    }

    try {
      final updated = await dbService.applyClientSyncSnapshot(
        clientId,
        parseResult.payload!,
        forceOlder: forceOlder,
      );

      if (updated == null) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({
          'ok': false,
          'error': 'Cliente no encontrado.',
        }));
      } else {
        request.response.write(jsonEncode({
          'ok': true,
          'client': updated,
          'message': 'Sincronización aplicada exitosamente.',
        }));
      }
    } on StaleSyncException catch (e) {
      request.response.statusCode = HttpStatus.conflict; // 409
      request.response.write(jsonEncode({
        'ok': false,
        'error_code': 'STALE_SYNC',
        'error': e.message,
        'sync_timestamp': e.syncTimestamp.toIso8601String(),
        'last_sync_at': e.lastSyncAt.toIso8601String(),
      }));
    }

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
  // Carga directa de APK desde PC (Binary stream) con inspección forense automática
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

    // Inspección forense multicapa automática
    final inspection = await inspector.inspectApk(
      targetFile,
      apkLibraryDir: configService.apkLibraryDir,
    );

    request.response.write(jsonEncode({
      'ok': inspection.success,
      ...inspection.toJson(),
    }));
    await request.response.close();
    return;
  }

  // Autodetectar e inspeccionar builds locales (Biblioteca Oficial + app_movil/build)
  if (path == '/api/releases/detect-local-build' && method == 'GET') {
    final libDir = Directory(configService.apkLibraryDir);
    final candidates = await inspector.detectLocalApks(apkLibraryDir: libDir);

    final hasApk = candidates.isNotEmpty;
    final top = hasApk ? candidates.first : null;

    request.response.write(jsonEncode({
      'ok': true,
      'apk_found': hasApk,
      'version_name': top?.versionName ?? '9.40.0',
      'version_code': top?.versionCode ?? 84,
      'db_schema_version': top?.dbSchemaVersion ?? 36,
      'min_required_version': top?.minRequiredVersion ?? '9.0.0',
      'file_name': top?.fileName,
      'file_path': top?.filePath,
      'file_size_mb': top?.sizeMb,
      'sha256': top?.sha256,
      'signature_verified': top?.signatureVerified,
      'signature_status': top?.signatureStatus,
      'signature_detail': top?.signatureDetail,
      'signer_sha256': top?.signerSha256,
      'signer_dn': top?.signerDn,
      'suggested_changelog': top?.suggestedChangelog ?? '',
      'suggested_internal_notes': top?.suggestedInternalNotes ?? '',
      'suggested_release_type': top?.suggestedReleaseType ?? 'FEATURE_RELEASE',
      'available_builds': candidates.map((c) => c.toJson()).toList(),
      'total_found': candidates.length,
      if (!hasApk)
        'message':
            'No se encontraron archivos APK en la biblioteca oficial ni en build/app/outputs/flutter-apk/.',
    }));
    await request.response.close();
    return;
  }

  // Importar build local seleccionado directamente a releases_apks/<env>/ sin re-subirlo
  if (path == '/api/releases/import-local-apk' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final rawSourcePath = (body['source_path'] as String? ?? '').trim();

    if (rawSourcePath.isEmpty ||
        !rawSourcePath.toLowerCase().endsWith('.apk')) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'error': 'Ruta de archivo .apk inválida',
      }));
      await request.response.close();
      return;
    }

    final normalizedSource =
        ApkInspectorService.canonicalizePath(rawSourcePath);
    final sourceFile = File(normalizedSource);
    if (!await sourceFile.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({
        'error':
            'El archivo APK de origen no existe en disco: $normalizedSource',
      }));
      await request.response.close();
      return;
    }

    // Validación canónica de ruta (evitar path traversal y falsos 403 por segmentos ..)
    final canonicalSource = sourceFile.resolveSymbolicLinksSync();
    final sourceCmp =
        Platform.isWindows ? canonicalSource.toLowerCase() : canonicalSource;
    final rawRoots = [
      configService.apkLibraryDir,
      '../app_movil/build',
      'releases_apks',
      Directory.systemTemp.path,
    ];
    final sep = Platform.pathSeparator;
    final isAllowed = rawRoots.any((r) {
      final canonRoot = ApkInspectorService.canonicalizePath(r);
      final rootCmp = Platform.isWindows ? canonRoot.toLowerCase() : canonRoot;
      if (rootCmp.isEmpty) return false;
      return sourceCmp == rootCmp || sourceCmp.startsWith('$rootCmp$sep');
    });

    if (!isAllowed) {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.write(jsonEncode({
        'error':
            'Acceso denegado: el archivo debe residir en la biblioteca de APKs o directorio de build.',
      }));
      await request.response.close();
      return;
    }

    // Copiar atómicamente al directorio de releases del entorno
    final targetDir = dbService.currentReleasesApkDir;
    await targetDir.create(recursive: true);
    final safeFileName = sourceFile.uri.pathSegments.last
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\.-]'), '_');
    final destFile = File('${targetDir.path}/$safeFileName');
    await sourceFile.copy(destFile.path);

    // Inspección forense del archivo importado preservando acceso a notas compañeras en origen y biblioteca
    final inspection = await inspector.inspectApk(
      destFile,
      apkLibraryDir: configService.apkLibraryDir,
      extraSearchDirs: [sourceFile.parent],
    );

    request.response.write(jsonEncode({
      'ok': true,
      'imported_path': inspection.filePath,
      ...inspection.toJson(),
    }));
    await request.response.close();
    return;
  }

  // Descarga directa del APK almacenado físicamente (con soporte de variantes universal / arm64)
  if (path.startsWith('/api/releases/download/') && method == 'GET') {
    final versionName = path.replaceFirst('/api/releases/download/', '').trim();
    final variant = request.uri.queryParameters['variant']?.toLowerCase();
    final release = await dbService.getReleaseByVersion(versionName);

    File? apkFile;
    if (release != null) {
      if (variant == 'arm64' && release['arm64_apk'] != null) {
        final p = (release['arm64_apk'] as Map<String, dynamic>)['file_path']
            as String?;
        if (p != null && File(p).existsSync()) apkFile = File(p);
      } else if (variant == 'universal' && release['universal_apk'] != null) {
        final p = (release['universal_apk']
            as Map<String, dynamic>)['file_path'] as String?;
        if (p != null && File(p).existsSync()) apkFile = File(p);
      }

      if (apkFile == null &&
          (release['apk_file_path'] as String? ?? '').isNotEmpty) {
        final f = File(release['apk_file_path'] as String);
        if (await f.exists()) apkFile = f;
      }
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
      'attachment; filename="${apkFile.uri.pathSegments.last}"',
    );
    await apkFile.openRead().pipe(request.response);
    return;
  }

  // Copiar archivo APK binario real al portapapeles de Windows (CF_HDROP en -STA con reintentos COM)
  final copyFileMatch =
      RegExp(r'^/api/releases/([^/]+)/copy-file$').firstMatch(path);
  if (copyFileMatch != null && method == 'POST') {
    final versionName = Uri.decodeComponent(copyFileMatch.group(1)!);
    final variant = request.uri.queryParameters['variant']?.toLowerCase();
    final release = await dbService.getReleaseByVersion(versionName);

    File? apkFile;
    if (release != null) {
      if (variant == 'arm64' && release['arm64_apk'] != null) {
        final p = (release['arm64_apk'] as Map<String, dynamic>)['file_path']
            as String?;
        if (p != null && File(p).existsSync()) apkFile = File(p);
      } else if (variant == 'universal' && release['universal_apk'] != null) {
        final p = (release['universal_apk']
            as Map<String, dynamic>)['file_path'] as String?;
        if (p != null && File(p).existsSync()) apkFile = File(p);
      }

      if (apkFile == null &&
          (release['apk_file_path'] as String? ?? '').isNotEmpty) {
        final f = File(release['apk_file_path'] as String);
        if (await f.exists()) apkFile = f;
      }
    }

    if (apkFile == null || !await apkFile.exists()) {
      final local = File(
          'releases_apks/${dbService.currentMode}/mochilalista-v$versionName.apk');
      if (await local.exists()) apkFile = local;
    }

    if (apkFile == null || !await apkFile.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({
        'error':
            'No se encontró archivo APK en disco para copiar al portapapeles',
      }));
      await request.response.close();
      return;
    }

    final rawFullPath = apkFile.absolute.path;
    final canonicalFullPath = ApkInspectorService.canonicalizePath(rawFullPath);
    bool copiedOk = false;
    String? clipboardError;

    if (onCopyFileOverride != null) {
      copiedOk = await onCopyFileOverride(rawFullPath);
    } else if (Platform.isWindows) {
      try {
        final psArgs = buildWindowsClipboardPsArgs(canonicalFullPath);
        final proc = await Process.run('powershell', psArgs)
            .timeout(const Duration(seconds: 12));
        copiedOk = proc.exitCode == 0;
        if (!copiedOk) {
          final err = proc.stderr.toString().trim();
          final out = proc.stdout.toString().trim();
          clipboardError = err.isNotEmpty
              ? err
              : (out.isNotEmpty ? out : 'PowerShell exitCode ${proc.exitCode}');
        }
      } catch (e) {
        copiedOk = false;
        clipboardError = e.toString();
      }
    } else {
      copiedOk = true; // Simulado en sistemas no-Windows
    }

    if (!copiedOk) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({
        'ok': false,
        'error': clipboardError ??
            'No se pudo copiar el archivo .APK al portapapeles de Windows.',
        'copied_path': canonicalFullPath,
        'file_name': apkFile.uri.pathSegments.last,
        'variant': variant ?? 'universal',
      }));
      await request.response.close();
      return;
    }

    request.response.write(jsonEncode({
      'ok': true,
      'copied_path': canonicalFullPath,
      'file_name': apkFile.uri.pathSegments.last,
      'variant': variant ?? 'universal',
    }));
    await request.response.close();
    return;
  }

  // Re-verificar firma criptográfica, tamaño, SHA-256 y existencia física en disco
  final verifyReleaseMatch =
      RegExp(r'^/api/releases/([^/]+)/verify$').firstMatch(path);
  if (verifyReleaseMatch != null && method == 'POST') {
    final versionName = Uri.decodeComponent(verifyReleaseMatch.group(1)!);
    final release = await dbService.getReleaseByVersion(versionName);
    if (release == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Versión no encontrada'}));
      await request.response.close();
      return;
    }

    final updates = <String, dynamic>{};
    final verifiedVariants = <String>[];
    ApkInspectionResult? primaryInspection;
    bool anyFileExists = false;

    Future<Map<String, dynamic>?> verifyVariantPath(
        String? rawPath, String label) async {
      if (rawPath == null || rawPath.trim().isEmpty) return null;
      final canon = ApkInspectorService.canonicalizePath(rawPath);
      final f = File(canon);
      if (!await f.exists()) return null;

      anyFileExists = true;
      final res = await inspector.inspectApk(
        f,
        apkLibraryDir: configService.apkLibraryDir,
      );
      verifiedVariants.add(label);
      primaryInspection ??= res;
      return {
        'file_path': res.filePath,
        'file_size_mb': res.sizeMb,
        'sha256': res.sha256,
        'signature_status': res.signatureStatus,
        'signature_verified': res.signatureVerified,
        if (res.signatureDetail != null)
          'signature_detail': res.signatureDetail,
        'signer_sha256': res.signerSha256,
        'signer_dn': res.signerDn,
        'file_exists': true,
      };
    }

    final rawUnivPath = (release['universal_apk']
        as Map<String, dynamic>?)?['file_path'] as String?;
    final rawArmPath = (release['arm64_apk']
        as Map<String, dynamic>?)?['file_path'] as String?;
    final rawMainPath = release['apk_file_path'] as String?;

    final updatedUniv = await verifyVariantPath(rawUnivPath, 'universal');
    if (updatedUniv != null) {
      updates['universal_apk'] = updatedUniv;
    }

    final updatedArm = await verifyVariantPath(rawArmPath, 'arm64');
    if (updatedArm != null) {
      updates['arm64_apk'] = updatedArm;
    }

    if (rawMainPath != null && rawMainPath.trim().isNotEmpty) {
      final mainCanon = ApkInspectorService.canonicalizePath(rawMainPath);
      final mainExists = await File(mainCanon).exists();
      if (mainExists) {
        if (primaryInspection == null) {
          await verifyVariantPath(mainCanon, 'primary');
        } else {
          anyFileExists = true;
        }
      }
    }

    if (primaryInspection != null) {
      final p = primaryInspection!;
      updates['apk_file_path'] = p.filePath;
      updates['file_size_mb'] = p.sizeMb;
      updates['apk_sha256'] = p.sha256;
      updates['signature_verified'] = p.signatureVerified;
      updates['signature_status'] = p.signatureStatus;
      updates['signature_detail'] = p.signatureDetail;
      updates['signer_sha256'] = p.signerSha256;
      updates['signer_dn'] = p.signerDn;
      if (p.versionCode != null) updates['version_code'] = p.versionCode;
      updates['db_schema_version'] = p.dbSchemaVersion;
      if (p.abiVariant == 'UNIVERSAL' && updatedUniv == null) {
        updates['universal_apk'] = {
          'file_path': p.filePath,
          'file_size_mb': p.sizeMb,
          'sha256': p.sha256,
          'signature_status': p.signatureStatus,
          'signature_verified': p.signatureVerified,
          if (p.signatureDetail != null) 'signature_detail': p.signatureDetail,
          'signer_sha256': p.signerSha256,
          'signer_dn': p.signerDn,
          'file_exists': true,
        };
      } else if (p.abiVariant == 'ARM64' && updatedArm == null) {
        updates['arm64_apk'] = {
          'file_path': p.filePath,
          'file_size_mb': p.sizeMb,
          'sha256': p.sha256,
          'signature_status': p.signatureStatus,
          'signature_verified': p.signatureVerified,
          if (p.signatureDetail != null) 'signature_detail': p.signatureDetail,
          'signer_sha256': p.signerSha256,
          'signer_dn': p.signerDn,
          'file_exists': true,
        };
      }
    } else {
      updates['signature_verified'] = null;
      updates['signature_status'] = 'UNVERIFIED';
      updates['signature_detail'] =
          'No se encontró ningún archivo físico APK registrado en disco.';
    }

    final updatedRelease = await dbService.updateRelease(versionName, updates);
    final companionNotes = await inspector.readCompanionNotesForVersion(
      versionName,
      apkPath: (updatedRelease?['apk_file_path'] as String?) ??
          rawMainPath ??
          rawUnivPath ??
          rawArmPath,
      apkLibraryDir: configService.apkLibraryDir,
    );

    request.response.write(jsonEncode({
      'ok': true,
      'release': updatedRelease ?? release,
      'file_exists': anyFileExists,
      'verified_variants': verifiedVariants,
      'suggested_changelog': companionNotes['suggested_changelog'],
      'suggested_internal_notes': companionNotes['suggested_internal_notes'],
      if (companionNotes['changelog_source'] != null)
        'changelog_source': companionNotes['changelog_source'],
      if (companionNotes['internal_notes_source'] != null)
        'internal_notes_source': companionNotes['internal_notes_source'],
    }));
    await request.response.close();
    return;
  }

  // Obtener notas compañeras (*_cambios.txt y *_atp.txt) desde biblioteca o carpeta del APK
  final companionNotesMatch =
      RegExp(r'^/api/releases/([^/]+)/companion-notes$').firstMatch(path);
  if (companionNotesMatch != null && method == 'GET') {
    final versionName = Uri.decodeComponent(companionNotesMatch.group(1)!);
    final release = await dbService.getReleaseByVersion(versionName);
    final apkPath = (release?['apk_file_path'] as String?) ??
        ((release?['universal_apk'] as Map<String, dynamic>?)?['file_path']
            as String?) ??
        ((release?['arm64_apk'] as Map<String, dynamic>?)?['file_path']
            as String?);

    final notes = await inspector.readCompanionNotesForVersion(
      versionName,
      apkPath: apkPath,
      apkLibraryDir: configService.apkLibraryDir,
    );
    request.response.write(jsonEncode(notes));
    await request.response.close();
    return;
  }

  // Registrar trazabilidad de despacho de APK (mark-sent)
  if (path == '/api/releases/mark-sent' && method == 'POST') {
    final bodyStr = await _readRequestBody(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final clientId = body['client_id'] as String? ?? '';
    final version = body['version'] as String? ?? '';
    final variant = body['variant'] as String?;

    if (clientId.isEmpty || version.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({
        'error': 'client_id y version son requeridos',
      }));
      await request.response.close();
      return;
    }

    final updated = await dbService.recordApkDispatched(clientId, version,
        variant: variant);
    if (updated == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'Cliente no encontrado'}));
    } else {
      request.response.write(jsonEncode({
        'ok': true,
        'client_id': clientId,
        'version': version,
        'variant': variant,
        'marked_at': DateTime.now().toUtc().toIso8601String(),
      }));
    }
    await request.response.close();
    return;
  }

  // Mostrar archivo APK en el Explorador de Windows (explorer.exe /select,...)
  if (path == '/api/releases/reveal-file' && method == 'POST') {
    final bodyStr = await utf8.decodeStream(request);
    final body = jsonDecode(bodyStr) as Map<String, dynamic>;
    final versionName = body['version_name'] as String? ?? '';
    final variant =
        (request.uri.queryParameters['variant'] ?? body['variant'] as String?)
            ?.toLowerCase();
    final release = await dbService.getReleaseByVersion(versionName);

    String? fullPath;
    if (release != null) {
      if (variant == 'arm64' && release['arm64_apk'] != null) {
        final p = (release['arm64_apk'] as Map<String, dynamic>)['file_path']
            as String?;
        if (p != null && File(p).existsSync()) fullPath = p;
      } else if (variant == 'universal' && release['universal_apk'] != null) {
        final p = (release['universal_apk']
            as Map<String, dynamic>)['file_path'] as String?;
        if (p != null && File(p).existsSync()) fullPath = p;
      }

      if (fullPath == null &&
          (release['apk_file_path'] as String? ?? '').isNotEmpty) {
        final p = release['apk_file_path'] as String;
        if (File(p).existsSync()) fullPath = p;
      }
    }

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
      request.response.write(jsonEncode(
          {'ok': true, 'path': fullPath, 'variant': variant ?? 'universal'}));
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
      final bodyStr = await _readRequestBody(request);
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newRelease = await dbService.createRelease(body);
      request.response.statusCode = HttpStatus.created;
      request.response.write(jsonEncode(newRelease));
      await request.response.close();
      return;
    }
  }

  // Operaciones sobre versión individual: PUT (editar changelog/metadatos) y DELETE (eliminar)
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
      case 'ico':
        request.response.headers.contentType = ContentType('image', 'x-icon');
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
