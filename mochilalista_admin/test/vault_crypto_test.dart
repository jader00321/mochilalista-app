@Timeout(Duration(minutes: 3))
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import '../lib/dpapi_service.dart';
import '../lib/vault_crypto_service.dart';

void main() {
  group('FASE 1: Motor Criptográfico Envelope Encryption en 2 Niveles y DPAPI', () {
    late MockDpapiService mockDpapiPcA;
    late MockDpapiService mockDpapiPcB;

    setUp(() {
      mockDpapiPcA = MockDpapiService('PC-ALPHA-101');
      mockDpapiPcB = MockDpapiService('PC-BETA-202');
    });

    test('1. Jerarquía en 2 Niveles e Invarianza de Factores (DEK efímera vs VMK persistente)', () async {
      // 1. Inicializar keyring con DPAPI en PC-A
      final init = await VaultCryptoService.createInitialKeyring(dpapi: mockDpapiPcA);
      final keyring = init.keyring;
      final vmk = init.vmk;

      // 2. Enrolar los otros 3 factores
      final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(keyring, vmk);
      final rescueKit = await VaultCryptoService.enrollRescueKitSlots(keyring, vmk);
      await VaultCryptoService.enrollPinSlot(keyring, vmk, '9876');

      expect(rescueKit.codes.length, equals(8));
      expect(mlKeyJson.contains('MLKEY'), isTrue);

      // 3. Exportar Paquete 1 en un momento T1 con clientes C1
      final files1 = VaultPayloadFiles(
        clientsJson: jsonEncode([{'id': 'CLI-01', 'business_name': 'Librería A'}]),
        releasesJson: jsonEncode([]),
        configJson: jsonEncode({'theme': 'dark'}),
        masterKeyEd25519: 'TEST_KEY_ALPHA_ED25519',
      );
      final vaultJson1 = await VaultCryptoService.exportVaultPackage(
        keyring: keyring,
        vmk: vmk,
        files: files1,
        includeMasterKey: true,
        stats: {'total_clients': 1},
      );

      // 4. Exportar Paquete 2 en un momento T2 con clientes C2
      final files2 = VaultPayloadFiles(
        clientsJson: jsonEncode([
          {'id': 'CLI-01', 'business_name': 'Librería A'},
          {'id': 'CLI-02', 'business_name': 'Bazar B'},
        ]),
        releasesJson: jsonEncode([]),
        configJson: jsonEncode({'theme': 'light'}),
        masterKeyEd25519: 'TEST_KEY_ALPHA_ED25519',
      );
      final vaultJson2 = await VaultCryptoService.exportVaultPackage(
        keyring: keyring,
        vmk: vmk,
        files: files2,
        includeMasterKey: true,
        stats: {'total_clients': 2},
      );

      final parsed1 = jsonDecode(vaultJson1) as Map<String, dynamic>;
      final parsed2 = jsonDecode(vaultJson2) as Map<String, dynamic>;

      // A. Verificar que las DEKs y nonces son únicos entre paquetes (Cero reutilización)
      final dekNonce1 = parsed1['wrapped_dek_by_vmk']['nonce_b64'];
      final dekNonce2 = parsed2['wrapped_dek_by_vmk']['nonce_b64'];
      expect(dekNonce1, isNot(equals(dekNonce2)));

      final payloadNonce1 = parsed1['payload_envelope']['nonce_b64'];
      final payloadNonce2 = parsed2['payload_envelope']['nonce_b64'];
      expect(payloadNonce1, isNot(equals(payloadNonce2)));

      // B. Verificar que la MISMA llave física .mlkey abre AMBOS paquetes
      final importedViaMlKey1 = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson1,
        credential: VaultUnlockCredential.mlKey(mlKeyJson),
      );
      expect(importedViaMlKey1.files.clientsJson, contains('Librería A'));

      final importedViaMlKey2 = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson2,
        credential: VaultUnlockCredential.mlKey(mlKeyJson),
      );
      expect(importedViaMlKey2.files.clientsJson, contains('Bazar B'));

      // C. Verificar que el MISMO código de rescate abre AMBOS paquetes
      final anyRescueCode = rescueKit.codes[3]; // Código #4
      final importedViaRescue1 = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson1,
        credential: VaultUnlockCredential.rescueCode(anyRescueCode),
      );
      expect(importedViaRescue1.files.clientsJson, contains('Librería A'));

      final importedViaRescue2 = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson2,
        credential: VaultUnlockCredential.rescueCode(anyRescueCode),
      );
      expect(importedViaRescue2.files.clientsJson, contains('Bazar B'));
    });

    test('2. Desbloqueo Independiente por cada uno de los 4 Factores', () async {
      final init = await VaultCryptoService.createInitialKeyring(dpapi: mockDpapiPcA);
      final keyring = init.keyring;
      final vmk = init.vmk;

      final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(keyring, vmk);
      final rescueKit = await VaultCryptoService.enrollRescueKitSlots(keyring, vmk);
      await VaultCryptoService.enrollPinSlot(keyring, vmk, '123456');

      final files = VaultPayloadFiles(
        clientsJson: jsonEncode([{'id': 'C-1', 'name': 'Comercial Don Pepe'}]),
        releasesJson: jsonEncode([]),
        configJson: jsonEncode({'currency': 'PEN'}),
        masterKeyEd25519: 'MASTER_KEY_SECRET_ED25519_BYTES',
      );

      final vaultJson = await VaultCryptoService.exportVaultPackage(
        keyring: keyring,
        vmk: vmk,
        files: files,
        includeMasterKey: true,
        stats: {'total_clients': 1},
      );

      // A. Factor 1: DPAPI (Éxito en PC-A, Fallo en PC-B)
      final resDpapiA = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson,
        credential: VaultUnlockCredential.dpapi(),
        dpapi: mockDpapiPcA,
      );
      expect(resDpapiA.files.clientsJson, contains('Comercial Don Pepe'));

      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultJson,
          credential: VaultUnlockCredential.dpapi(),
          dpapi: mockDpapiPcB,
        ),
        throwsA(isA<VaultAuthException>()),
        reason: 'DPAPI de PC-B debe rechazar el descifrado del blob de PC-A',
      );

      // B. Factor 2: Archivo .mlkey (Éxito con clave legítima, Fallo con clave corrupta)
      final resMlKey = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson,
        credential: VaultUnlockCredential.mlKey(mlKeyJson),
      );
      expect(resMlKey.files.masterKeyEd25519, equals('MASTER_KEY_SECRET_ED25519_BYTES'));

      final parsedMl = jsonDecode(mlKeyJson) as Map<String, dynamic>;
      parsedMl['key_b64'] = base64Encode(List<int>.filled(32, 0xAA));
      final corruptedMlKey = jsonEncode(parsedMl);
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultJson,
          credential: VaultUnlockCredential.mlKey(corruptedMlKey),
        ),
        throwsA(isA<VaultAuthException>()),
      );

      // C. Factor 3: Los 8 Códigos de Rescate de forma independiente (y con tolerancia a minúsculas/espacios)
      for (int i = 0; i < rescueKit.codes.length; i++) {
        final code = rescueKit.codes[i];
        // Probar alternando mayúsculas, minúsculas y espacios accidentales
        final mutatedCode = (i % 2 == 0)
            ? code.toLowerCase().replaceAll('-', ' ')
            : code.toUpperCase();

        final resCode = await VaultCryptoService.importVaultPackage(
          vaultJson: vaultJson,
          credential: VaultUnlockCredential.rescueCode(mutatedCode),
        );
        expect(resCode.files.clientsJson, contains('Comercial Don Pepe'));
      }

      // Probar código QR
      final resQr = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson,
        credential: VaultUnlockCredential.qrKey(rescueKit.qrKey),
      );
      expect(resQr.files.clientsJson, contains('Comercial Don Pepe'));

      // Código de rescate totalmente incorrecto debe fallar
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultJson,
          credential: VaultUnlockCredential.rescueCode('ML-9999-XXXX-0000'),
        ),
        throwsA(isA<VaultAuthException>()),
      );

      // D. Factor 4: PIN Local Opcional
      final resPin = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultJson,
        credential: VaultUnlockCredential.pin('123456'),
      );
      expect(resPin.files.clientsJson, contains('Comercial Don Pepe'));

      // PIN incorrecto debe fallar
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultJson,
          credential: VaultUnlockCredential.pin('000000'),
        ),
        throwsA(isA<VaultAuthException>()),
      );

      // E. Simulación de "Olvido Total de PIN" y Recuperación Inmediata
      // Si el propietario olvida su PIN '123456', desenvuelve la VMK usando su .mlkey
      final recoveredVmk = await VaultCryptoService.unwrapVmkWithMlKey(keyring, mlKeyJson);
      expect(recoveredVmk, isNotNull);

      // Redefine un nuevo PIN '4321' sin alterar el resto de factores
      await VaultCryptoService.enrollPinSlot(keyring, recoveredVmk!, '4321');

      // Exporta nuevo snapshot con el PIN actualizado
      final vaultWithNewPin = await VaultCryptoService.exportVaultPackage(
        keyring: keyring,
        vmk: recoveredVmk,
        files: files,
        includeMasterKey: true,
        stats: {},
      );

      // Ahora desbloquea con '4321' y falla con '123456'
      final resNewPin = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultWithNewPin,
        credential: VaultUnlockCredential.pin('4321'),
      );
      expect(resNewPin.files.clientsJson, contains('Comercial Don Pepe'));

      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultWithNewPin,
          credential: VaultUnlockCredential.pin('123456'),
        ),
        throwsA(isA<VaultAuthException>()),
      );
    });

    test('3. Migración Simulada a Nueva Laptop (rewrapVmkForNewDpapi)', () async {
      // 1. En PC-A se inicializa el llavero
      final init = await VaultCryptoService.createInitialKeyring(dpapi: mockDpapiPcA);
      final keyring = init.keyring;
      final vmk = init.vmk;

      final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(keyring, vmk);
      final rescueKit = await VaultCryptoService.enrollRescueKitSlots(keyring, vmk);

      final filesA = VaultPayloadFiles(
        clientsJson: jsonEncode([{'id': 'MIG-01', 'note': 'Datos originados en PC-A'}]),
        releasesJson: '[]',
        configJson: '{}',
        masterKeyEd25519: 'ED25519_MASTER_PC_A',
      );

      final vaultExportedA = await VaultCryptoService.exportVaultPackage(
        keyring: keyring,
        vmk: vmk,
        files: filesA,
        includeMasterKey: true,
        stats: {},
      );

      // 2. Llegada a PC-B (laptop nueva)
      // PC-B no puede desbloquear vía DPAPI
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: vaultExportedA,
          credential: VaultUnlockCredential.dpapi(),
          dpapi: mockDpapiPcB,
        ),
        throwsA(isA<VaultAuthException>()),
      );

      // 3. PC-B desbloquea con el archivo .mlkey traído en pendrive USB
      final importOnPcB = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultExportedA,
        credential: VaultUnlockCredential.mlKey(mlKeyJson),
      );
      expect(importOnPcB.files.clientsJson, contains('Datos originados en PC-A'));

      // 4. PC-B re-envuelve la VMK en su propio DPAPI local
      final rewrapOk = await VaultCryptoService.rewrapVmkForNewDpapi(
        importOnPcB.keyring,
        importOnPcB.vmk,
        mockDpapiPcB,
      );
      expect(rewrapOk, isTrue);

      // 5. Ahora PC-B exporta una nueva versión en su disco
      final vaultExportedB = await VaultCryptoService.exportVaultPackage(
        keyring: importOnPcB.keyring,
        vmk: importOnPcB.vmk,
        files: importOnPcB.files,
        includeMasterKey: true,
        stats: {},
      );

      // 6. PC-B ahora abre en 1 clic vía su propio DPAPI sin pedir contraseñas
      final importDpapiB = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultExportedB,
        credential: VaultUnlockCredential.dpapi(),
        dpapi: mockDpapiPcB,
      );
      expect(importDpapiB.files.masterKeyEd25519, equals('ED25519_MASTER_PC_A'));

      // 7. Y los 8 códigos originales siguen abriendo la bóveda en PC-B
      final importRescueOnB = await VaultCryptoService.importVaultPackage(
        vaultJson: vaultExportedB,
        credential: VaultUnlockCredential.rescueCode(rescueKit.codes[0]),
      );
      expect(importRescueOnB.files.masterKeyEd25519, equals('ED25519_MASTER_PC_A'));
    });

    test('4. Integridad Estricta y Detección de Manipulaciones (Anti-Tampering)', () async {
      final init = await VaultCryptoService.createInitialKeyring(dpapi: mockDpapiPcA);
      final mlKeyJson = await VaultCryptoService.enrollMlKeySlot(init.keyring, init.vmk);

      final files = VaultPayloadFiles(
        clientsJson: '[{"id":"1"}]',
        releasesJson: '[]',
        configJson: '{}',
        masterKeyEd25519: 'PRIVKEY',
      );

      final originalVaultJson = await VaultCryptoService.exportVaultPackage(
        keyring: init.keyring,
        vmk: init.vmk,
        files: files,
        includeMasterKey: true,
        stats: {},
      );

      // A. Alteración de 1 byte en ciphertext_sha256
      final mapTamperedSha = jsonDecode(originalVaultJson) as Map<String, dynamic>;
      mapTamperedSha['payload_envelope']['ciphertext_sha256'] =
          '0000000000000000000000000000000000000000000000000000000000000000';
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: jsonEncode(mapTamperedSha),
          credential: VaultUnlockCredential.mlKey(mlKeyJson),
        ),
        throwsA(isA<VaultIntegrityException>()),
      );

      // B. Alteración de 1 byte en el ciphertext del payload
      final mapTamperedPayload = jsonDecode(originalVaultJson) as Map<String, dynamic>;
      final rawCipher = base64Decode(mapTamperedPayload['payload_envelope']['encrypted_payload_b64'] as String);
      rawCipher[0] = rawCipher[0] ^ 0xFF; // Flip bits
      mapTamperedPayload['payload_envelope']['encrypted_payload_b64'] = base64Encode(rawCipher);
      // Actualizar el sha del ciphertext para que pase el primer filtro y falle en auth tag AES-GCM
      mapTamperedPayload['payload_envelope']['ciphertext_sha256'] =
          sha256.convert(rawCipher).toString();

      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: jsonEncode(mapTamperedPayload),
          credential: VaultUnlockCredential.mlKey(mlKeyJson),
        ),
        throwsA(isA<VaultIntegrityException>()),
      );

      // C. Alteración de la cabecera pública protegida por AAD (ej. cambiar app_version)
      final mapTamperedAad = jsonDecode(originalVaultJson) as Map<String, dynamic>;
      mapTamperedAad['app_version'] = '9.99.9-HACKED';
      expect(
        () async => await VaultCryptoService.importVaultPackage(
          vaultJson: jsonEncode(mapTamperedAad),
          credential: VaultUnlockCredential.mlKey(mlKeyJson),
        ),
        throwsA(isA<VaultIntegrityException>()),
      );

      // D. Inspección segura de metadatos públicos sin descifrar
      final inspection = VaultCryptoService.inspectVaultPackage(originalVaultJson);
      expect(inspection['format'], equals('MLVAULT'));
      expect(inspection['includes_master_key'], isTrue);
      expect(inspection['has_dpapi'], isTrue);
      expect(inspection['has_mlkey'], isTrue);
    });

    test('5. Prueba Real de WindowsDpapiService (Condicional si corre en Windows)', () async {
      final dpapi = WindowsDpapiService();
      if (!dpapi.isSupported) {
        print('Prueba de Windows DPAPI omitida: plataforma no es Windows.');
        return;
      }

      final secretVmk = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
      final entropy = Uint8List.fromList(utf8.encode('EntropyTestSeed'));

      // 1. Proteger vía stdin/stdout
      final protected = await dpapi.protect(secretVmk, entropy: entropy);
      expect(protected, isNotNull);
      expect(protected!.length, greaterThan(32));

      // 2. Desproteger vía stdin/stdout
      final unprotected = await dpapi.unprotect(protected, entropy: entropy);
      expect(unprotected, isNotNull);
      expect(unprotected, equals(secretVmk));

      // 3. Desproteger con entropía incorrecta debe fallar (retornar null)
      final wrongEntropy = Uint8List.fromList(utf8.encode('WrongEntropySeed'));
      final failEntropy = await dpapi.unprotect(protected, entropy: wrongEntropy);
      expect(failEntropy, isNull);

      // 4. Desproteger datos corruptos debe retornar null limpiamente
      final corruptedBlob = Uint8List.fromList(protected.sublist(0, 20));
      final failCorrupt = await dpapi.unprotect(corruptedBlob, entropy: entropy);
      expect(failCorrupt, isNull);
    });
  });
}
