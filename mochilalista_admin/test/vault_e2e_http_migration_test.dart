@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

import '../server.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';

void main() {
  group('FASE 4: Simulación E2E HTTP de Mudanza Multi-PC, Bloqueo HTTP 423 y Auto-Recuperación', () {
    late Directory tempDirA;
    late Directory tempMirrorA;
    late Directory tempDirB;
    late Directory tempMirrorB;

    late MockDpapiService dpapiA;
    late MockDpapiService dpapiB;

    late DatabaseService dbA;
    late ConfigService configA;
    late LicenseSigner signerA;
    late ExcelExportService excelA;
    late VaultStorageService vaultA;
    late HttpServer serverA;

    late DatabaseService dbB;
    late ConfigService configB;
    late LicenseSigner signerB;
    late ExcelExportService excelB;
    late VaultStorageService vaultB;
    late HttpServer serverB;

    late HttpClient httpClient;
    late Uint8List masterSeed;

    setUpAll(() async {
      httpClient = HttpClient();

      // 1. Configurar Entorno Aislado PC-A
      tempDirA = await Directory.systemTemp.createTemp('ml_pca_root_');
      tempMirrorA = await Directory.systemTemp.createTemp('ml_pca_mirror_');
      dpapiA = MockDpapiService('PC-TEST-A');

      final keyDirA = Directory('${tempDirA.path}/private_keys');
      await keyDirA.create(recursive: true);
      masterSeed = Uint8List.fromList(List.generate(32, (i) => (i * 11 + 17) % 256));
      final masterKeyFileA = File('${keyDirA.path}/ed25519_master.key');
      await masterKeyFileA.writeAsString(jsonEncode({
        'format': 'ED25519_SEED',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'seed': masterSeed,
      }));

      dbA = DatabaseService(
        dataDir: '${tempDirA.path}/data',
        backupDir: '${tempDirA.path}/backups',
        releasesDir: '${tempDirA.path}/releases_apks',
      );
      await dbA.init();
      dbA.setMode('prod');

      configA = ConfigService(
        dataDirectory: Directory('${tempDirA.path}/data'),
        backupsDirectory: Directory('${tempDirA.path}/backups'),
      );
      await configA.init();

      signerA = LicenseSigner();
      await signerA.loadMasterKey(keyPath: masterKeyFileA.path);

      excelA = ExcelExportService(
        dbService: dbA,
        configService: configA,
      );

      vaultA = VaultStorageService(
        projectRootDir: tempDirA.path,
        mirrorDir: tempMirrorA.path,
        dpapiService: dpapiA,
        dbService: dbA,
        configService: configA,
        signer: signerA,
      );
      await vaultA.initialize();

      // Registrar un cliente en PC-A (Modo Prod)
      await dbA.createClient({
        'business_name': 'Librería Central Arequipa',
        'owner_name': 'Juan Pérez',
        'phone': '+51987654321',
        'current_device_id': 'ML-9K4B',
        'license_type': 'MENSUAL',
      });
      await vaultA.syncMirror();

      serverA = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverA.listen((req) => handleRequest(req, dbA, signerA, configA, excelA, vaultA));

      // 2. Configurar Entorno Aislado PC-B (Limpio, sin clientes ni clave previa)
      tempDirB = await Directory.systemTemp.createTemp('ml_pcb_root_');
      tempMirrorB = await Directory.systemTemp.createTemp('ml_pcb_mirror_');
      dpapiB = MockDpapiService('PC-TEST-B');

      dbB = DatabaseService(
        dataDir: '${tempDirB.path}/data',
        backupDir: '${tempDirB.path}/backups',
        releasesDir: '${tempDirB.path}/releases_apks',
      );
      await dbB.init();
      dbB.setMode('prod');

      configB = ConfigService(
        dataDirectory: Directory('${tempDirB.path}/data'),
        backupsDirectory: Directory('${tempDirB.path}/backups'),
      );
      await configB.init();

      signerB = LicenseSigner();

      excelB = ExcelExportService(
        dbService: dbB,
        configService: configB,
      );

      vaultB = VaultStorageService(
        projectRootDir: tempDirB.path,
        mirrorDir: tempMirrorB.path,
        dpapiService: dpapiB,
        dbService: dbB,
        configService: configB,
        signer: signerB,
      );
      await vaultB.initialize();

      serverB = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverB.listen((req) => handleRequest(req, dbB, signerB, configB, excelB, vaultB));
    });

    tearDownAll(() async {
      httpClient.close();
      await serverA.close(force: true);
      await serverB.close(force: true);

      if (tempDirA.existsSync()) tempDirA.deleteSync(recursive: true);
      if (tempMirrorA.existsSync()) tempMirrorA.deleteSync(recursive: true);
      if (tempDirB.existsSync()) tempDirB.deleteSync(recursive: true);
      if (tempMirrorB.existsSync()) tempMirrorB.deleteSync(recursive: true);
    });

    Future<Map<String, dynamic>> httpGet(String baseUrl, String path, {String? token}) async {
      final req = await httpClient.getUrl(Uri.parse('$baseUrl$path'));
      req.headers.add('X-App-Mode', 'prod');
      if (token != null) req.headers.add('X-Vault-Session-Token', token);
      final res = await req.close();
      final bodyText = await utf8.decodeStream(res);
      return {
        'status': res.statusCode,
        'body': bodyText.isNotEmpty ? jsonDecode(bodyText) : null,
      };
    }

    Future<Map<String, dynamic>> httpPost(String baseUrl, String path, dynamic data, {String? token}) async {
      final req = await httpClient.postUrl(Uri.parse('$baseUrl$path'));
      req.headers.contentType = ContentType.json;
      req.headers.add('X-App-Mode', 'prod');
      if (token != null) req.headers.add('X-Vault-Session-Token', token);
      if (data != null) req.write(jsonEncode(data));
      final res = await req.close();
      final bodyText = await utf8.decodeStream(res);
      return {
        'status': res.statusCode,
        'body': bodyText.isNotEmpty ? jsonDecode(bodyText) : null,
      };
    }

    test('Flujo E2E HTTP Completo: PC-A (Kit, PIN, HTTP 423, Rescate) -> Exportar -> PC-B (Importar, Firma en Caliente, Auto-Recuperación)', () async {
      final urlA = 'http://localhost:${serverA.port}';
      final urlB = 'http://localhost:${serverB.port}';

      // =========================================================================
      // PASO 1: EN PC-A -> Health, Descarga .mlkey, Kit de Rescate y Bloqueo PIN
      // =========================================================================

      // 1.1 Health en PC-A
      final healthA = await httpGet(urlA, '/api/vault/health');
      expect(healthA['status'], equals(HttpStatus.ok));
      expect(healthA['body']['mirror_exists'], isTrue);
      expect(healthA['body']['files']['clients_db']['exists'], isTrue);
      expect(healthA['body']['files']['master_key']['exists'], isTrue);

      // 1.2 Descargar .mlkey
      final mlkeyRes = await httpGet(urlA, '/api/vault/download-mlkey');
      expect(mlkeyRes['status'], equals(HttpStatus.ok));
      expect(mlkeyRes['body']['ok'], isTrue);
      final mlkeyJson = mlkeyRes['body']['mlkey_json'] as String;
      expect(mlkeyJson.contains('format'), isTrue);

      // 1.3 Generar Kit de Emergencia con 8 códigos ML-XXXX-YYYY-ZZZZ
      final rescueKitRes = await httpPost(urlA, '/api/vault/generate-rescue-kit', {});
      expect(rescueKitRes['status'], equals(HttpStatus.ok));
      final codes = (rescueKitRes['body']['codes'] as List).cast<String>();
      expect(codes.length, equals(8));
      for (final code in codes) {
        expect(code.startsWith('ML-'), isTrue, reason: 'Código de rescate debe tener prefijo ML-');
        expect(code.length, equals(17), reason: 'Formato ML-XXXX-YYYY-ZZZZ debe tener 17 caracteres');
      }

      // 1.4 Configurar PIN en PC-A (5678)
      final pinCfgRes = await httpPost(urlA, '/api/vault/pin/configure', {'enabled': true, 'pin': '5678'});
      expect(pinCfgRes['status'], equals(HttpStatus.ok));
      expect(pinCfgRes['body']['pin_enabled'], isTrue);

      // 1.5 Verificar que endpoint protegido devuelve HTTP 423 Locked sin token
      final lockedReq = await httpGet(urlA, '/api/clients');
      expect(lockedReq['status'], equals(423), reason: 'Petición sin token debe responder HTTP 423 Locked');
      expect(lockedReq['body']['locked'], isTrue);

      // 1.6 Desbloquear con PIN válido
      final unlockRes = await httpPost(urlA, '/api/vault/pin/verify', {'pin': '5678'});
      expect(unlockRes['status'], equals(HttpStatus.ok));
      final sessionToken = (unlockRes['body']['session_token'] ?? unlockRes['body']['token']) as String;
      expect(sessionToken, isNotEmpty);

      // 1.7 Petición con token X-Vault-Session-Token ahora devuelve HTTP 200 OK
      final clientsAuthorized = await httpGet(urlA, '/api/clients', token: sessionToken);
      expect(clientsAuthorized['status'], equals(HttpStatus.ok));
      expect(clientsAuthorized['body'], isA<List>());
      final listA = clientsAuthorized['body'] as List;
      expect(listA.any((c) => c['business_name'] == 'Librería Central Arequipa'), isTrue);

      // 1.8 Simular olvido de PIN: bloquear consola y recuperar acceso con 1 Código de Rescate
      await httpPost(urlA, '/api/vault/pin/lock', {}, token: sessionToken);
      final lockedAgain = await httpGet(urlA, '/api/clients');
      expect(lockedAgain['status'], equals(423));

      // Recuperar PIN usando el código #3 (con formato oficial ML-XXXX-YYYY-ZZZZ)
      final rescueCodeUsed = codes[2];
      final recoverRes = await httpPost(urlA, '/api/vault/pin/recover', {
        'credential_type': 'rescue_code',
        'secret': rescueCodeUsed,
        'disable_pin': true,
      });
      expect(recoverRes['status'], equals(HttpStatus.ok));
      expect(recoverRes['body']['ok'], isTrue);
      final newToken = (recoverRes['body']['session_token'] ?? recoverRes['body']['token']) as String;

      // Consola desbloqueada de nuevo
      final clientsUnlocked = await httpGet(urlA, '/api/clients', token: newToken);
      expect(clientsUnlocked['status'], equals(HttpStatus.ok));

      // 1.9 Exportar Bóveda Portable (.mlvault) desde PC-A
      final exportRes = await httpPost(urlA, '/api/vault/export', {'include_master_key': true});
      expect(exportRes['status'], equals(HttpStatus.ok));
      expect(exportRes['body']['ok'], isTrue);
      final vaultJson = exportRes['body']['vault_json'] as String;
      expect(vaultJson.contains('MLVAULT'), isTrue);

      // =========================================================================
      // PASO 2: EN PC-B -> Inspeccionar, Importar con .mlkey y Emitir en Caliente
      // =========================================================================

      // 2.1 Inspeccionar .mlvault en PC-B
      final inspectRes = await httpPost(urlB, '/api/vault/inspect', {'vault_json': vaultJson});
      expect(inspectRes['status'], equals(HttpStatus.ok));
      expect(inspectRes['body']['ok'], isTrue);
      final metaB = inspectRes['body']['metadata'] as Map<String, dynamic>;
      expect(metaB['has_master_key'], isTrue);
      expect((metaB['available_slots'] as List).contains('mlkey'), isTrue);

      // 2.2 Importar .mlvault en PC-B usando la llave .mlkey de PC-A y re-encriptar con DPAPI de PC-B
      final importRes = await httpPost(urlB, '/api/vault/import', {
        'vault_json': vaultJson,
        'credential_type': 'mlkey',
        'secret': mlkeyJson,
        'rewrap_dpapi': true,
      });
      expect(importRes['status'], equals(HttpStatus.ok));
      expect(importRes['body']['ok'], isTrue);

      // 2.3 Verificar que PC-B recargó en caliente la cartera y la clave Ed25519
      final clientsB = await httpGet(urlB, '/api/clients');
      expect(clientsB['status'], equals(HttpStatus.ok));
      final listB = clientsB['body'] as List;
      final importedClient = listB.firstWhere((c) => c['business_name'] == 'Librería Central Arequipa');
      expect(importedClient, isNotNull);

      // 2.4 Emitir licencia en caliente desde PC-B y verificar que firma con la clave Ed25519 original
      expect(signerB.isLoaded, isTrue, reason: 'LicenseSigner de PC-B debe tener cargada la clave en caliente');
      final issueRes = await httpPost(urlB, '/api/licenses/generate', {
        'client_id': importedClient['id'],
        'plan': 'TRIMESTRAL',
        'payment_amount': 90.0,
        'payment_method': 'YAPE',
        'payment_ref': 'MIGRACION-PC-B',
      });
      expect(issueRes['status'], equals(HttpStatus.ok));
      final tokenIssued = (issueRes['body']['token'] ?? issueRes['body']['license']?['token']) as String;
      expect(tokenIssued.startsWith('ML9-'), isTrue);

      // Validar forensemente el token con la clave pública de PC-A
      final inspectToken = await signerA.inspectToken(tokenIssued);
      expect(inspectToken['signature_verified'], isTrue, reason: 'Token emitido en PC-B debe ser verificable con PC-A');
      expect(inspectToken['valid'], isTrue);

      // =========================================================================
      // PASO 3: EN PC-B -> Simulación de Desastre (Wipe) y Auto-Recuperación en 1 Clic
      // =========================================================================

      // 3.1 Borrado total de datos locales en PC-B
      final dbFileB = File('${tempDirB.path}/data/prod_clients_db.json');
      if (await dbFileB.exists()) await dbFileB.delete();
      final keyFileB = File('${tempDirB.path}/private_keys/ed25519_master.key');
      if (await keyFileB.exists()) await keyFileB.delete();

      // 3.2 Verificar que /health en PC-B detecta recuperación disponible
      final healthAfterWipe = await httpGet(urlB, '/api/vault/health');
      expect(healthAfterWipe['status'], equals(HttpStatus.ok));
      expect(healthAfterWipe['body']['recovery_available'], isTrue);

      // 3.3 Restaurar todo en 1 clic vía /recover-from-mirror con DPAPI de PC-B
      final recoverMirrorRes = await httpPost(urlB, '/api/vault/recover-from-mirror', {
        'credential_type': 'dpapi',
      });
      expect(recoverMirrorRes['status'], equals(HttpStatus.ok));
      expect(recoverMirrorRes['body']['ok'], isTrue);

      // 3.4 Verificar que los archivos físicos y la memoria fueron restaurados
      expect(await dbFileB.exists(), isTrue);
      expect(await keyFileB.exists(), isTrue);
      final clientsRestored = await httpGet(urlB, '/api/clients');
      expect(clientsRestored['status'], equals(HttpStatus.ok));
      final listRestored = clientsRestored['body'] as List;
      expect(listRestored.any((c) => c['business_name'] == 'Librería Central Arequipa'), isTrue);
    });
  });
}
