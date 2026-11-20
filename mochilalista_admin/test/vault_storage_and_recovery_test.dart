@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:test/test.dart';

import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_crypto_service.dart';
import '../lib/vault_storage_service.dart';

void main() {
  group('FASE 2: Servicio de Doble Almacenamiento, Portabilidad y Auto-Recuperación', () {
    late Directory tempProjectA;
    late Directory tempMirrorA;
    late Directory tempCloudA;
    late MockDpapiService dpapiA;
    late DatabaseService dbA;
    late ConfigService configA;
    late LicenseSigner signerA;
    late VaultStorageService vaultA;
    late Uint8List masterSeed;

    setUp(() async {
      tempProjectA = await Directory.systemTemp.createTemp('ml_proj_a_');
      tempMirrorA = await Directory.systemTemp.createTemp('ml_mirror_a_');
      tempCloudA = await Directory.systemTemp.createTemp('ml_cloud_a_');
      dpapiA = MockDpapiService('PC-TEST-A');

      dbA = DatabaseService(
        dataDir: '${tempProjectA.path}/data',
        backupDir: '${tempProjectA.path}/backups',
        releasesDir: '${tempProjectA.path}/releases_apks',
      );
      await dbA.init();

      configA = ConfigService(
        dataDirectory: Directory('${tempProjectA.path}/data'),
        backupsDirectory: Directory('${tempProjectA.path}/backups'),
      );
      await configA.init();

      // Sembrar clave maestra Ed25519 en tempProjectA
      final keyDir = Directory('${tempProjectA.path}/private_keys');
      await keyDir.create(recursive: true);
      masterSeed = Uint8List.fromList(List.generate(32, (i) => (i * 7 + 13) % 256));
      final masterKeyFile = File('${keyDir.path}/ed25519_master.key');
      await masterKeyFile.writeAsString(jsonEncode({
        'format': 'ED25519_SEED',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'seed': masterSeed,
      }));

      signerA = LicenseSigner();
      await signerA.loadMasterKey(keyPath: masterKeyFile.path);

      vaultA = VaultStorageService(
        projectRootDir: tempProjectA.path,
        mirrorDir: tempMirrorA.path,
        dpapiService: dpapiA,
        dbService: dbA,
        configService: configA,
        signer: signerA,
      );
      await vaultA.initialize();
    });

    tearDown(() async {
      try {
        if (await tempProjectA.exists()) await tempProjectA.delete(recursive: true);
        if (await tempMirrorA.exists()) await tempMirrorA.delete(recursive: true);
        if (await tempCloudA.exists()) await tempCloudA.delete(recursive: true);
      } catch (_) {}
    });

    test('1. Doble Escritura Cifrada Cero Texto Plano en Espejo y Nube Local', () async {
      // Activar modo prod y configurar nube local
      dbA.setMode('prod');
      await vaultA.setCloudSyncPath(tempCloudA.path);

      // Crear cliente comercial en producción
      final client = await dbA.createClient({
        'business_name': 'Librería Central Segura S.A.C.',
        'owner_name': 'Carlos Mendoza Gómez',
        'phone': '+51 987654321',
        'license_type': 'ANUAL',
      });
      expect(client['id'], isNotNull);

      // Verificar que syncMirror creó los archivos en el directorio espejo
      final mirrorVault = File('${tempMirrorA.path}/auto_mirror_latest.mlvault');
      final mirrorKeyring = File('${tempMirrorA.path}/vault_keyring.json');
      final mirrorManifest = File('${tempMirrorA.path}/vault_manifest.json');
      final cloudVault = File('${tempCloudA.path}/MochilaLista_Backup_Sync.mlvault');

      expect(await mirrorVault.exists(), isTrue);
      expect(await mirrorKeyring.exists(), isTrue);
      expect(await mirrorManifest.exists(), isTrue);
      expect(await cloudVault.exists(), isTrue);

      // REGLA ESTRICTA CERO TEXTO PLANO EN ESPEJO
      final mirrorPlainKey = File('${tempMirrorA.path}/ed25519_master.key');
      final mirrorPlainClients = File('${tempMirrorA.path}/prod_clients_db.json');
      expect(await mirrorPlainKey.exists(), isFalse, reason: 'La clave maestra JAMÁS debe estar en texto plano en el espejo');
      expect(await mirrorPlainClients.exists(), isFalse, reason: 'La base de clientes JAMÁS debe estar en texto plano en el espejo');

      // Verificar que el contenido de .mlvault es cifrado AES-GCM binario y no contiene strings sensibles
      final vaultContent = await mirrorVault.readAsString();
      expect(vaultContent.contains('Librería Central Segura'), isFalse);
      expect(vaultContent.contains('Carlos Mendoza Gómez'), isFalse);
      expect(vaultContent.contains('ED25519_SEED'), isFalse);

      final manifestContent = await mirrorManifest.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;
      expect(manifest['clients_count'], equals(1));
      expect(manifest['has_master_key'], isTrue);
      expect(manifest['ciphertext_sha256'], isNotEmpty);
    });

    test('2. Auto-recuperación en 1 Clic tras Borrado Accidental Local', () async {
      dbA.setMode('prod');
      await dbA.createClient({
        'business_name': 'Bodega San Judas Tadeo',
        'owner_name': 'Juana Quispe',
        'phone': '+51 911222333',
        'license_type': 'SEMESTRAL',
      });
      await vaultA.syncMirror();

      // Firmar token antes del desastre
      final originalToken = await signerA.generateLicenseToken(
        deviceFingerprint: 'ML-AAAA-BBBB-CCCC',
        businessTag: 'Juana Quispe',
        plan: 'SEMESTRAL',
        daysToAdd: 180,
        nonce: 1,
      );
      expect(originalToken, startsWith('ML9-'));

      // SIMULAR DESASTRE TOTAL: Borrado de data/ y private_keys/ en tempProjectA
      final dataDir = Directory('${tempProjectA.path}/data');
      final privDir = Directory('${tempProjectA.path}/private_keys');
      if (await dataDir.exists()) await dataDir.delete(recursive: true);
      if (await privDir.exists()) await privDir.delete(recursive: true);

      // Verificar que health reporta recovery_available == true
      final healthBefore = await vaultA.checkStorageHealth();
      expect(healthBefore['recovery_available'], isTrue);
      expect(healthBefore['status'], equals('recovery_mode'));

      // EJECUTAR AUTO-RECUPERACIÓN
      final importResult = await vaultA.recoverFromMirror();
      expect(importResult.internalManifest, isNotNull);

      // Verificar que los archivos físicos volvieron a existir
      expect(await vaultA.clientsDbFile.exists(), isTrue);
      expect(await vaultA.ownerConfigFile.exists(), isTrue);
      expect(await vaultA.masterKeyFile.exists(), isTrue);

      // Verificar que dbService recuperó los datos y signerA sigue firmando y verificando
      final recoveredClients = await dbA.getClients();
      expect(recoveredClients.length, equals(1));
      expect(recoveredClients.first['business_name'], equals('Bodega San Judas Tadeo'));

      final healthAfter = await vaultA.checkStorageHealth();
      expect(healthAfter['recovery_available'], isFalse);

      // Verificar firma post-recuperación con LicenseSigner recargado en caliente
      final inspected = await signerA.inspectToken(originalToken);
      expect(inspected['valid'], isTrue);
      expect(inspected['client'], equals('Juana Quispe'));
    });

    test('3. Mudanza Multi-PC (PC-A -> PC-B) con .mlkey y Códigos de Rescate + Re-envoltorio DPAPI', () async {
      dbA.setMode('prod');
      await dbA.createClient({
        'business_name': 'Distribuidora Huascarán',
        'owner_name': 'Marcos Vidal',
        'phone': '+51 933444555',
        'license_type': 'ANUAL',
      });

      // Enrolar .mlkey y Kit de Rescate en PC-A
      final mlKeyJson = await vaultA.downloadMlKey();
      final rescueKit = await vaultA.generateRescueKit();
      expect(rescueKit.codes.length, equals(8));

      // Exportar bóveda portable .mlvault desde PC-A
      final portableVaultJson = await vaultA.exportPortableVault(includeMasterKey: true);

      // SIMULAR NUEVA LAPTOP (PC-B) EN DIRECTORIO AISLADO
      final tempProjectB = await Directory.systemTemp.createTemp('ml_proj_b_');
      final tempMirrorB = await Directory.systemTemp.createTemp('ml_mirror_b_');
      final dpapiB = MockDpapiService('PC-TEST-B');

      try {
        final dbB = DatabaseService(dataDir: '${tempProjectB.path}/data');
        await dbB.init();
        final configB = ConfigService(dataDirectory: Directory('${tempProjectB.path}/data'));
        await configB.init();
        final signerB = LicenseSigner();

        final vaultB = VaultStorageService(
          projectRootDir: tempProjectB.path,
          mirrorDir: tempMirrorB.path,
          dpapiService: dpapiB,
          dbService: dbB,
          configService: configB,
          signer: signerB,
        );
        await vaultB.initialize();

        // 1. Probar que DPAPI de PC-B NO puede descifrar directamente el paquete de PC-A
        expect(
          () async => await vaultB.importPortableVault(
            vaultJson: portableVaultJson,
            credential: VaultUnlockCredential.dpapi(),
          ),
          throwsA(isA<VaultAuthException>()),
        );

        // 2. Importar exitosamente en PC-B usando el archivo .mlkey
        final importResMlKey = await vaultB.importPortableVault(
          vaultJson: portableVaultJson,
          credential: VaultUnlockCredential.mlKey(mlKeyJson),
          rewrapForCurrentDpapi: true,
        );
        expect(importResMlKey.files.clientsJson.contains('Distribuidora Huascarán'), isTrue);

        // 3. Comprobar que en PC-B la VMK quedó re-envuelta en el DPAPI de PC-B
        final healthB = await vaultB.checkStorageHealth();
        expect(healthB['factors']['dpapi_enrolled'], isTrue);

        // 4. Probar que signerB en PC-B ahora puede firmar y los tokens se validan con la clave pública de PC-A
        final tokenFromB = await signerB.generateLicenseToken(
          deviceFingerprint: 'ML-9999-8888-7777',
          businessTag: 'Cliente Laptop B',
          plan: 'TRIMESTRAL',
          daysToAdd: 90,
          nonce: 1,
        );
        expect(tokenFromB, startsWith('ML9-'));

        final inspected = await signerA.inspectToken(tokenFromB);
        expect(inspected['valid'], isTrue);
        expect(inspected['client'], equals('Cliente Laptop B'));

        // 5. Probar importación alternativa en PC-B usando 1 de los 8 Códigos de Rescate impresos
        final rescueCode = rescueKit.codes[3]; // Código #4
        final importResRescue = await vaultB.importPortableVault(
          vaultJson: portableVaultJson,
          credential: VaultUnlockCredential.rescueCode(rescueCode.toLowerCase().replaceAll('-', ' ')),
          rewrapForCurrentDpapi: true,
        );
        expect(importResRescue.files.clientsJson.contains('Distribuidora Huascarán'), isTrue);
      } finally {
        if (await tempProjectB.exists()) await tempProjectB.delete(recursive: true);
        if (await tempMirrorB.exists()) await tempMirrorB.delete(recursive: true);
      }
    });

    test('4. Bloqueo PIN Real (HTTP 423), Backoff Anti-Fuerza Bruta y Recuperación "¿Olvidaste tu PIN?"', () async {
      // Estado inicial: PIN desactivado
      expect(vaultA.isPinEnabled(), isFalse);
      expect(vaultA.isSessionValid(null), isTrue);

      // Activar PIN "2468"
      await vaultA.configurePin(pin: '2468', enabled: true);
      expect(vaultA.isPinEnabled(), isTrue);
      expect(vaultA.isSessionValid(null), isFalse);
      expect(vaultA.isSessionValid('token_inventado'), isFalse);

      // Fallos de PIN sucesivos secuenciales
      for (int i = 1; i <= 4; i++) {
        await expectLater(
          vaultA.verifyPin('0000'),
          throwsA(isA<VaultAuthException>()),
        );
      }

      // Intento #5 activa el backoff exponencial
      await expectLater(
        vaultA.verifyPin('0000'),
        throwsA(isA<VaultAuthException>()),
      );

      // Inmediatamente después del 5to fallo, cualquier intento es bloqueado por tiempo
      await expectLater(
        vaultA.verifyPin('2468'),
        throwsA(predicate((e) => e is VaultAuthException && e.message.contains('bloqueada'))),
      );

      // RECUPERACIÓN: El usuario olvidó el PIN y usa su archivo .mlkey
      final mlKeyJson = await vaultA.downloadMlKey();
      final recoverResult = await vaultA.recoverPin(
        credential: VaultUnlockCredential.mlKey(mlKeyJson),
        newPin: '1357',
      );
      expect(recoverResult['success'], isTrue);
      expect(recoverResult['token'], isNotNull);

      // El token emitido por recuperación es válido de inmediato
      expect(vaultA.isSessionValid(recoverResult['token'] as String), isTrue);

      // El nuevo PIN 1357 ahora funciona correctamente
      final loginNewPin = await vaultA.verifyPin('1357');
      expect(loginNewPin['success'], isTrue);
      expect(vaultA.isSessionValid(loginNewPin['token'] as String), isTrue);

      // Desactivar PIN
      await vaultA.configurePin(pin: null, enabled: false);
      expect(vaultA.isPinEnabled(), isFalse);
      expect(vaultA.isSessionValid(null), isTrue);
    });
  });
}
