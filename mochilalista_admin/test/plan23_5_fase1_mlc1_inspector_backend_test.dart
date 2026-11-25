import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

import '../lib/client_sync_service.dart';
import '../lib/commercial_config_sync_service.dart';
import '../lib/config_service.dart';
import '../lib/database_service.dart';
import '../lib/dpapi_service.dart';
import '../lib/excel_export_service.dart';
import '../lib/license_signer.dart';
import '../lib/vault_storage_service.dart';
import '../server.dart';

class _TestDpapiService implements DpapiService {
  @override
  bool get isSupported => true;

  @override
  Future<Uint8List?> protect(Uint8List data, {Uint8List? entropy}) async =>
      Uint8List.fromList(data.map((b) => b ^ 0x5A).toList());

  @override
  Future<Uint8List?> unprotect(Uint8List encryptedData,
          {Uint8List? entropy}) async =>
      Uint8List.fromList(encryptedData.map((b) => b ^ 0x5A).toList());
}

Future<Map<String, dynamic>> _httpJson(
  HttpClient client,
  String method,
  Uri uri, {
  Map<String, dynamic>? body,
}) async {
  final req = await client.openUrl(method, uri);
  if (body != null) {
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
  }
  final res = await req.close();
  final raw = await utf8.decodeStream(res);
  final decoded = raw.trim().isNotEmpty ? jsonDecode(raw) : null;
  return {
    'status': res.statusCode,
    'body': decoded,
    'raw': raw,
  };
}

class _SpyCommercialConfigSyncService extends CommercialConfigSyncService {
  bool buildComparisonCalled = false;

  @override
  Map<String, dynamic> buildCurrentConfigComparison(
    Map<String, dynamic> decodedPayload,
    Map<String, dynamic> currentConfig, {
    required int localRevision,
  }) {
    buildComparisonCalled = true;
    return super.buildCurrentConfigComparison(
      decodedPayload,
      currentConfig,
      localRevision: localRevision,
    );
  }
}

void main() {
  group(
      'PLAN MAESTRO 23.5 - FASE 1: Backend Tri-Protocolo MLC1 en CommercialConfigSyncService y /api/licenses/inspect',
      () {
    late Directory tempDir;
    late Directory dataDir;
    late Directory backupsDir;
    late Directory mirrorDir;
    late String releasesDir;
    late DatabaseService dbService;
    late ConfigService configService;
    late LicenseSigner signer;
    late ExcelExportService excelService;
    late VaultStorageService vaultStorage;
    late ClientSyncService clientSyncService;
    late _SpyCommercialConfigSyncService mlc1Service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ml_p23_5_fase1_');
      dataDir = Directory('${tempDir.path}/data')..createSync(recursive: true);
      backupsDir = Directory('${tempDir.path}/backups')
        ..createSync(recursive: true);
      mirrorDir = Directory('${tempDir.path}/mirror')
        ..createSync(recursive: true);
      releasesDir = '${tempDir.path}/releases_apks';
      Directory(releasesDir).createSync(recursive: true);

      dbService = DatabaseService(
        dataDir: dataDir.path,
        backupDir: backupsDir.path,
        releasesDir: releasesDir,
      );
      await dbService.init();

      configService = ConfigService(
        dataDirectory: dataDir,
        backupsDirectory: backupsDir,
      );
      await configService.init();

      signer = LicenseSigner();
      await signer
          .initWithSeed(List<int>.generate(32, (i) => (i * 19 + 7) % 256));

      excelService = ExcelExportService(
        dbService: dbService,
        configService: configService,
      );

      vaultStorage = VaultStorageService(
        projectRootDir: tempDir.path,
        mirrorDir: mirrorDir.path,
        dpapiService: _TestDpapiService(),
        dbService: dbService,
        configService: configService,
        signer: signer,
      );
      await vaultStorage.initialize();

      clientSyncService = ClientSyncService();
      mlc1Service = _SpyCommercialConfigSyncService();
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        '1. extractMlc1Token, looksLikeMlc1Input y tryDecodePayloadDiagnostic (puro, WhatsApp, QR, truncado y basura)',
        () async {
      final issued = await mlc1Service.generateSignedToken(
        configService.config,
        revision: 1,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 17, 15, 0),
      );
      final token = issued['token'] as String;

      // Token puro
      expect(CommercialConfigSyncService.extractMlc1Token(token), equals(token));
      expect(CommercialConfigSyncService.looksLikeMlc1Input(token), isTrue);

      // Mensaje completo de WhatsApp con CRLF, asteriscos y texto envolvente
      final whatsappMsg = [
        '*MochilaLista — Actualización Oficial de Tarifas y Medios de Pago (Rev. #1)*',
        '',
        '1. Abre MochilaLista en tu teléfono.',
        '2. Ve a Menú > Estado de Licencia y Activación.',
        '',
        token,
        '',
        'Soporte oficial: +51 922 836 879',
      ].join('\r\n');
      expect(
        CommercialConfigSyncService.extractMlc1Token(whatsappMsg),
        equals(token),
      );
      expect(
        CommercialConfigSyncService.looksLikeMlc1Input(whatsappMsg),
        isTrue,
      );

      // Prefijo minúscula normalizado a MLC1- (simulando QR / copia alterada en prefijo)
      final lowerPrefixed = 'mlc1-${token.substring(5)}';
      expect(
        CommercialConfigSyncService.extractMlc1Token(lowerPrefixed),
        equals(token),
      );
      expect(
        CommercialConfigSyncService.looksLikeMlc1Input(lowerPrefixed),
        isTrue,
      );

      // Token MLC1 truncado / malformado NO cae en ML9
      expect(CommercialConfigSyncService.extractMlc1Token('MLC1-abc'), equals(''));
      expect(CommercialConfigSyncService.looksLikeMlc1Input('MLC1-abc'), isTrue);
      expect(
        CommercialConfigSyncService.looksLikeMlc1Input('Código: MLC1-truncado'),
        isTrue,
      );

      // ML9 y MLS1 NO son capturados como MLC1
      expect(
        CommercialConfigSyncService.looksLikeMlc1Input('ML9-abc.def'),
        isFalse,
      );
      expect(
        CommercialConfigSyncService.looksLikeMlc1Input('MLS1-abc.def'),
        isFalse,
      );

      // tryDecodePayloadDiagnostic: decodifica payload legible en token adulterado en firma
      final parts = token.substring(5).split('.');
      final flippedSig =
          '${parts[1].substring(0, 4)}${parts[1][4] == 'A' ? 'B' : 'A'}${parts[1].substring(5)}';
      final tamperedSigToken = 'MLC1-${parts[0]}.$flippedSig';
      final diag = mlc1Service.tryDecodePayloadDiagnostic(tamperedSigToken);
      expect(diag, isNotNull);
      expect(diag!['ver'], equals(1));
      expect(diag['v'], equals(1));

      // Rechaza payload no-Map, no-JSON o excedido (>8192 B)
      final listB64 = LicenseSigner.encodeBase64UrlSafe(utf8.encode('[1,2,3]'));
      expect(
        mlc1Service.tryDecodePayloadDiagnostic('MLC1-$listB64.${parts[1]}'),
        isNull,
      );
      expect(
        mlc1Service.tryDecodePayloadDiagnostic('MLC1-no_es_base64!.zzz'),
        isNull,
      );
      expect(
        mlc1Service.tryDecodePayloadDiagnostic('MLC1-${'A' * 8300}.${parts[1]}'),
        isNull,
      );
    });

    test(
        '2. Verificación Ed25519 con separación de dominio MLC1- y decodificación diagnóstica en fallo',
        () async {
      final issued = await mlc1Service.generateSignedToken(
        configService.config,
        revision: 3,
        signer: signer,
        nowUtc: DateTime.utc(2026, 11, 25, 16, 40, 0),
      );
      final token = issued['token'] as String;

      // Token envuelto en mensaje de WhatsApp pasa verifySignedToken directamente
      final wrapped = 'Hola comerciante:\n$token\nGracias';
      final okRes = await mlc1Service.verifySignedToken(wrapped, signer: signer);
      expect(okRes['valid'], isTrue);
      expect(okRes['revision'], equals(3));
      expect(okRes['domain_separated'], isTrue);
      expect(okRes['payload_bytes'], greaterThan(0));
      expect(okRes['token_bytes'], equals(utf8.encode(token).length));
      expect(okRes['issued_at_lima'], contains('2026-11-25 11:40:00'));

      // Firma sin separación de dominio `MLC1-` debe fallar
      final parts = token.substring(5).split('.');
      final rawSigNoDomain =
          await signer.signRawMessage(utf8.encode(parts[0]));
      final noDomainToken =
          'MLC1-${parts[0]}.${LicenseSigner.encodeBase64UrlSafe(rawSigNoDomain)}';
      final failNoDomain = await mlc1Service.verifySignedToken(
        noDomainToken,
        signer: signer,
      );
      expect(failNoDomain['valid'], isFalse);
      expect(failNoDomain['status'], equals('INVALID_SIGNATURE'));

      // Payload legible sigue siendo extraíble para diagnóstico sin marcar valid: true
      final diagNoDomain = mlc1Service.tryDecodePayloadDiagnostic(noDomainToken);
      expect(diagNoDomain, isNotNull);
      expect(diagNoDomain!['ver'], equals(3));

      // Esquema con clave no autorizada ("script") firmado válidamente falla en INVALID_SCHEMA
      final payloadMap =
          jsonDecode(jsonEncode(okRes['payload'])) as Map<String, dynamic>;
      payloadMap['script'] = 'alert(1)';
      final injectedB64 =
          LicenseSigner.encodeBase64UrlSafe(utf8.encode(jsonEncode(payloadMap)));
      final injectedSig =
          await signer.signRawMessage(utf8.encode('MLC1-$injectedB64'));
      final injectedToken =
          'MLC1-$injectedB64.${LicenseSigner.encodeBase64UrlSafe(injectedSig)}';
      final failSchema = await mlc1Service.verifySignedToken(
        injectedToken,
        signer: signer,
      );
      expect(failSchema['valid'], isFalse);
      expect(failSchema['status'], equals('INVALID_SCHEMA'));
      final diagSchema = mlc1Service.tryDecodePayloadDiagnostic(injectedToken);
      expect(diagSchema, isNotNull);
      expect(diagSchema!['script'], equals('alert(1)'));
      final diagSummary = mlc1Service.buildDiagnosticSummaryFromMap(diagSchema);
      expect(diagSummary['unexpected_keys'], contains('script'));
    });

    test(
        '3. buildCurrentConfigComparison: tolerancia 0.005, trim, 8 productos, 5 canales y 3 estados de revisión',
        () {
      final basePayload = mlc1Service.buildCanonicalPayload(
        configService.config,
        revision: 2,
      );

      // Tolerancia numérica < 0.005 y espacios alrededor en strings -> coincide al 100 %
      final nearPayload =
          jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      nearPayload['sup'] = '  ${basePayload['sup']}  ';
      ((nearPayload['p'] as Map)['mensual'] as Map)['pr'] = 35.002;
      final exactCmp = mlc1Service.buildCurrentConfigComparison(
        nearPayload,
        configService.config,
        localRevision: 2,
      );
      expect(exactCmp['revision_status'], equals('CURRENT'));
      expect(exactCmp['diff_vs_current']['matches_current'], isTrue);
      expect(exactCmp['diff_vs_current']['total_differences'], equals(0));
      expect(
        (exactCmp['diff_vs_current']['products_diff'] as List).length,
        equals(8),
      );
      expect(
        (exactCmp['diff_vs_current']['channels_diff'] as List).length,
        equals(5),
      );

      // Diferencia >= 0.005 en precio y en BCP + revisión antigua -> SUPERSEDED + diff exacto
      final oldPayload =
          jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      oldPayload['ver'] = 1;
      ((oldPayload['p'] as Map)['mensual'] as Map)['pr'] = 35.01;
      ((oldPayload['p'] as Map)['anual'] as Map)['ai'] = 999;
      (oldPayload['bcp'] as Map)['acc'] = '191-00011122-0-33';
      final oldCmp = mlc1Service.buildCurrentConfigComparison(
        oldPayload,
        configService.config,
        localRevision: 4,
      );
      expect(oldCmp['revision_status'], equals('SUPERSEDED'));
      expect(oldCmp['recommendation'], contains('Rev. #4'));
      expect(oldCmp['diff_vs_current']['matches_current'], isFalse);
      expect(oldCmp['diff_vs_current']['total_differences'], equals(3));

      final prodDiff = (oldCmp['diff_vs_current']['products_diff'] as List)
          .cast<Map<String, dynamic>>();
      final mensualDiff = prodDiff.firstWhere((e) => e['id'] == 'mensual');
      expect(mensualDiff['matches'], isFalse);
      expect(mensualDiff['changed_fields'], equals(['pr']));
      final anualDiff = prodDiff.firstWhere((e) => e['id'] == 'anual');
      expect(anualDiff['changed_fields'], equals(['ai']));

      final chDiff = (oldCmp['diff_vs_current']['channels_diff'] as List)
          .cast<Map<String, dynamic>>();
      final bcpDiff = chDiff.firstWhere((e) => e['key'] == 'bcp');
      expect(bcpDiff['matches'], isFalse);

      // Revisión superior a la local -> AHEAD_OR_EXTERNAL
      final aheadPayload =
          jsonDecode(jsonEncode(basePayload)) as Map<String, dynamic>;
      aheadPayload['ver'] = 9;
      final aheadCmp = mlc1Service.buildCurrentConfigComparison(
        aheadPayload,
        configService.config,
        localRevision: 2,
      );
      expect(aheadCmp['revision_status'], equals('AHEAD_OR_EXTERNAL'));
    });

    test(
        '4. HTTP POST /api/licenses/inspect Tri-Protocolo (MLC1 CURRENT/SUPERSEDED/AHEAD/INVALID + ML9 + MLS1 + wiring)',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) => handleRequest(
            req,
            dbService,
            signer,
            configService,
            excelService,
            vaultStorage,
            clientSyncService: clientSyncService,
            commercialSyncService: mlc1Service,
          ));
      final http = HttpClient();
      final baseUrl = 'http://127.0.0.1:${server.port}';

      try {
        // 4A. Emitir ficha MLC1 Rev #1 vía API
        final gen1 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/generate-sync-token'),
          body: {},
        );
        expect(gen1['status'], equals(200));
        final tokenRev1 = gen1['body']['token'] as String;

        // Inspeccionar token Rev #1 (envuelto en mensaje WhatsApp) -> CURRENT, 0 diffs y verifica wiring handleRequest -> _handleApiRoute
        final waToken1 =
            '*MochilaLista — Tarifas (Rev. #1)*\n\n$tokenRev1\n\nSoporte: +51 922 836 879';
        final insp1 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': waToken1},
        );
        expect(insp1['status'], equals(200));
        final b1 = insp1['body'] as Map<String, dynamic>;
        expect(b1['ok'], isTrue);
        expect(b1['input_kind'], equals('COMMERCIAL_CONFIG'));
        expect(b1['token_kind'], equals('MLC1'));
        expect(b1['valid'], isTrue);
        expect(b1['isValid'], isTrue);
        expect(b1['domain_separated'], isTrue);
        expect(b1['revision'], equals(1));
        expect(b1['issued_at'], isNotEmpty);
        expect(
          b1['issued_at_lima'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')),
        );
        expect(b1['payload_bytes'], greaterThan(0));
        expect(b1['token_bytes'], equals(utf8.encode(tokenRev1).length));
        expect(mlc1Service.buildComparisonCalled, isTrue);

        final cmp1 = b1['current_config_comparison'] as Map<String, dynamic>;
        expect(cmp1['revision_status'], equals('CURRENT'));
        expect(cmp1['local_revision'], equals(1));
        expect(cmp1['token_revision'], equals(1));
        expect(cmp1['diff_vs_current']['matches_current'], isTrue);
        expect(cmp1['diff_vs_current']['total_differences'], equals(0));

        // 4B. Actualizar precio MENSUAL, bolsa IA MENSUAL y cuenta BCP, luego emitir Rev #2
        final customCatalog =
            jsonDecode(jsonEncode(configService.catalog)) as Map<String, dynamic>;
        (customCatalog['MENSUAL'] as Map)['price'] = 42.0;
        (customCatalog['MENSUAL'] as Map)['ai_credits'] = 80;
        await configService.saveConfig({
          'catalog': customCatalog,
          'payment_methods': {
            ...configService.paymentMethods,
            'bcp_account_holder': 'Julio Vasquez',
            'bcp_account_number': '191-55500011-0-88',
            'bcp_cci': '002-191-005550001108-88',
          },
        });
        final gen2 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/config/generate-sync-token'),
          body: {},
        );
        expect(gen2['status'], equals(200));
        expect(gen2['body']['revision'], equals(2));

        // Auditar Rev #1 ahora -> SUPERSEDED + diff_vs_current exacto (mensual pr+ai y bcp)
        final inspOld = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': tokenRev1},
        );
        expect(inspOld['status'], equals(200));
        final bOld = inspOld['body'] as Map<String, dynamic>;
        expect(bOld['valid'], isTrue);
        final cmpOld = bOld['current_config_comparison'] as Map<String, dynamic>;
        expect(cmpOld['revision_status'], equals('SUPERSEDED'));
        expect(cmpOld['recommendation'], contains('Rev. #2'));
        expect(cmpOld['diff_vs_current']['matches_current'], isFalse);
        expect(cmpOld['diff_vs_current']['total_differences'], equals(2));

        final prodList = (cmpOld['diff_vs_current']['products_diff'] as List)
            .cast<Map<String, dynamic>>();
        final mensual = prodList.firstWhere((e) => e['id'] == 'mensual');
        expect(mensual['matches'], isFalse);
        expect(mensual['changed_fields'], containsAll(['pr', 'ai']));
        expect(mensual['token_values']['pr'], equals(35.0));
        expect(mensual['current_values']['pr'], equals(42.0));

        final chList = (cmpOld['diff_vs_current']['channels_diff'] as List)
            .cast<Map<String, dynamic>>();
        final bcp = chList.firstWhere((e) => e['key'] == 'bcp');
        expect(bcp['matches'], isFalse);
        expect(bcp['token_value'], equals('Omitido'));
        expect(bcp['current_value'], contains('191-55500011-0-88'));

        // 4C. Auditar ficha válida emitida externamente con revisión ver: 7 (> local 2) -> AHEAD_OR_EXTERNAL
        final aheadIssued = await mlc1Service.generateSignedToken(
          configService.config,
          revision: 7,
          signer: signer,
        );
        final inspAhead = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': aheadIssued['token']},
        );
        expect(inspAhead['status'], equals(200));
        expect(
          inspAhead['body']['current_config_comparison']['revision_status'],
          equals('AHEAD_OR_EXTERNAL'),
        );

        // 4D. Fichas adulteradas / firma con clave distinta / truncada -> HTTP 200, valid=false, payload=null, security_alert
        final parts = tokenRev1.substring(5).split('.');
        final tamperedSig =
            'MLC1-${parts[0]}.${parts[1].substring(0, 6)}${parts[1][6] == 'C' ? 'D' : 'C'}${parts[1].substring(7)}';
        final inspTampered = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': tamperedSig},
        );
        expect(inspTampered['status'], equals(200));
        final bTam = inspTampered['body'] as Map<String, dynamic>;
        expect(bTam['ok'], isFalse);
        expect(bTam['input_kind'], equals('COMMERCIAL_CONFIG'));
        expect(bTam['token_kind'], equals('MLC1'));
        expect(bTam['valid'], isFalse);
        expect(bTam['isValid'], isFalse);
        expect(bTam['status'], equals('INVALID_SIGNATURE'));
        expect(bTam['payload'], isNull);
        expect(bTam['diagnostic_only'], isTrue);
        expect(bTam['security_alert'], contains('FIRMA ED25519 INVÁLIDA'));
        expect(bTam['diagnostic_payload'], isNotNull);
        expect(bTam['diagnostic_payload']['ver'], equals(1));
        expect(bTam['diagnostic_summary']['revision'], equals(1));

        // Clave ajena Ed25519
        final otherKp = await Ed25519().newKeyPairFromSeed(
          List<int>.generate(32, (i) => (i * 11 + 3) % 256),
        );
        final rogueIssued = await mlc1Service.generateSignedToken(
          configService.config,
          revision: 99,
          keyPair: otherKp,
        );
        final inspRogue = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': rogueIssued['token']},
        );
        expect(inspRogue['status'], equals(200));
        expect(inspRogue['body']['valid'], isFalse);
        expect(inspRogue['body']['token_kind'], equals('MLC1'));
        expect(inspRogue['body']['security_alert'], isNotEmpty);
        expect(inspRogue['body']['diagnostic_payload']['ver'], equals(99));

        // Truncado MLC1-corrupto no cae en ML9
        final inspTrunc = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': 'MLC1-truncado-sin-firma'},
        );
        expect(inspTrunc['status'], equals(200));
        expect(inspTrunc['body']['token_kind'], equals('MLC1'));
        expect(inspTrunc['body']['input_kind'], equals('COMMERCIAL_CONFIG'));
        expect(inspTrunc['body']['valid'], isFalse);
        expect(inspTrunc['body']['status'], equals('INVALID_FORMAT'));

        // 4E. Retrocompatibilidad estricta ML9 y MLS1
        final ml9 = await signer.generateLicenseToken(
          deviceFingerprint: 'ML-99AA',
          plan: 'ANUAL',
          daysToAdd: 365,
          nonce: 1,
          businessTag: 'Librería Tri-Protocolo',
        );
        final inspMl9 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': ml9},
        );
        expect(inspMl9['status'], equals(200));
        expect(inspMl9['body']['input_kind'], equals('LICENSE_TOKEN'));
        expect(inspMl9['body']['valid'], isTrue);

        final mls1 = clientSyncService.generateSyncToken({
          'v': 1,
          'hw': 'ML-99AA',
          'av': '9.41.0',
          'pl': 'ANUAL',
          'st': 'ACTIVA',
          'dr': 365,
          'n': 1,
          'ai': 1200,
          'aiu': 0,
          'pc': 1,
          'ts': 1795624800000,
        });
        final inspMls1 = await _httpJson(
          http,
          'POST',
          Uri.parse('$baseUrl/api/licenses/inspect'),
          body: {'token': mls1},
        );
        expect(inspMls1['status'], equals(200));
        expect(inspMls1['body']['input_kind'], equals('CLIENT_SYNC'));
        expect(inspMls1['body']['valid'], isTrue);
      } finally {
        http.close(force: true);
        await server.close(force: true);
      }
    });
  });
}
