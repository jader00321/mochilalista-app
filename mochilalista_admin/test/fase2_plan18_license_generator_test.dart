import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import '../lib/database_service.dart';
import 'support/web_bundle_loader.dart';

void main() {
  group('Fase 2 - Plan Maestro 18: Estudio Generador de Licencias Ed25519', () {
    late Directory tempDir;
    late DatabaseService dbService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mochila_fase2_test_');
      final dataDir = '${tempDir.path}/data';
      final backupDir = '${tempDir.path}/backups';
      await Directory(dataDir).create(recursive: true);
      await Directory(backupDir).create(recursive: true);

      final clientsFile = File('$dataDir/sandbox_clients_db.json');
      await clientsFile.writeAsString(jsonEncode([
        {
          'id': 'CLI-TEST-001',
          'business_name': 'Bodega San Jose',
          'owner_name': 'Jose Perez',
          'current_device_id': 'ML-TEST-99',
          'license_type': 'TRIAL',
          'license_expires': '2026-12-31T23:59:59.000Z',
          'next_nonce': 1,
          'ai_reported_balance': 69,
          'ai_accumulated_credits': 69,
          'ai_pending_bonus': 20,
          'payment_history': [],
          'generated_codes_history': [],
        }
      ]));

      dbService = DatabaseService(dataDir: dataDir, backupDir: backupDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. recordCodeEmission con pago > 0 vincula payment_id y amount_paid en generated_codes_history', () async {
      final updatedClient = await dbService.recordCodeEmission(
        clientId: 'CLI-TEST-001',
        token: 'ML9-TEST-TOKEN-PAGADO.SIG',
        plan: 'MENSUAL',
        daysToAdd: 30,
        updatesUntil: null,
        aiExtraCredits: 0,
        paymentAmount: 35.0,
        paymentMethod: 'Yape',
        paymentRef: 'Op. 123456',
      );

      expect(updatedClient, isNotNull);
      expect(updatedClient!['next_nonce'], equals(2));

      final history = (updatedClient['generated_codes_history'] as List).cast<Map<String, dynamic>>();
      expect(history, isNotEmpty);
      final lastCode = history.last;
      expect(lastCode['token'], equals('ML9-TEST-TOKEN-PAGADO.SIG'));
      expect(lastCode['amount_paid'], equals(35.0));
      expect(lastCode['payment_id'], isNotNull);
      expect(lastCode['payment_id'], startsWith('PAY-'));

      final payments = (updatedClient['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments.length, equals(1));
      final payment = payments.first;
      expect(payment['id'], equals(lastCode['payment_id']));
      expect(payment['amount'], equals(35.0));
      expect(payment['method'], equals('Yape'));
      expect(payment['reference'], equals('Op. 123456'));
    });

    test('2. recordCodeEmission con pago S/ 0.00 (Bono Gratuito / Cortesia) no genera payment_history y deja payment_id en null', () async {
      final updatedClient = await dbService.recordCodeEmission(
        clientId: 'CLI-TEST-001',
        token: 'ML9-TEST-TOKEN-GRATIS.SIG',
        plan: 'BONO_IA_PERSONALIZADO',
        daysToAdd: 0,
        updatesUntil: null,
        aiExtraCredits: 20,
        paymentAmount: 0.0,
        paymentMethod: 'Cortesia / Promocion',
        paymentRef: 'Bono Gratuito',
      );

      expect(updatedClient, isNotNull);
      final history = (updatedClient!['generated_codes_history'] as List).cast<Map<String, dynamic>>();
      expect(history, isNotEmpty);
      final lastCode = history.last;
      expect(lastCode['amount_paid'], equals(0.0));
      expect(lastCode['payment_id'], isNull);

      final payments = (updatedClient['payment_history'] as List).cast<Map<String, dynamic>>();
      expect(payments, isEmpty);
    });

    test('3. Iniciar_MochilaLista_Admin.bat preserva 100% CRLF, ASCII puro (<= 127) y sintaxis segura cmd /c con pause', () async {
      final batFile = File('../Iniciar_MochilaLista_Admin.bat');
      expect(await batFile.exists(), isTrue, reason: 'El lanzador BAT debe existir en la raíz');

      final bytes = await batFile.readAsBytes();
      expect(bytes, isNotEmpty);

      // Validar ASCII puro
      for (int i = 0; i < bytes.length; i++) {
        expect(bytes[i], lessThanOrEqualTo(127),
            reason: 'Byte en offset $i tiene valor ${bytes[i]} > 127 (no es ASCII puro)');
      }

      // Validar que cada LF vaya precedido por CR (100% CRLF)
      for (int i = 0; i < bytes.length; i++) {
        if (bytes[i] == 10) { // \n
          expect(i > 0 && bytes[i - 1] == 13, isTrue,
              reason: 'Se detectó LF solitario sin CR en offset $i');
        }
      }

      final content = ascii.decode(bytes);
      expect(content, contains('cmd /c "dart run server.dart || pause"'),
          reason: 'Debe usar cmd /c con pause condicional');
      expect(content, contains('http://localhost:8080/api/vault/health'),
          reason: 'Debe sonder el endpoint health HTTP');
    });

    test('4. Inspección estática de admin_app.js e index.html para Estudio Generador (Fase 2)', () async {
      final jsCode = WebBundleLoader.loadJs();
      expect(jsCode, isNotEmpty);

      // Métodos y utilidades de Fase 2
      expect(jsCode, contains('decodeMl9TokenPayload'), reason: 'Debe implementar fallback Base64URL');
      expect(jsCode, contains('resetCustomSettings'), reason: 'Debe implementar reset atómico de ajustes');
      expect(jsCode, contains('chkEnableCustomSettings'), reason: 'Debe validar switch explícito de ajustes');
      expect(jsCode, contains('btnResetCustomSettings'), reason: 'Debe conectar botón de restablecer');
      expect(jsCode, contains('btnGenOpenReceipt'), reason: 'Debe conectar botón de boleta directa');
      expect(jsCode, contains('btnGenCopyMessageAndCode'), reason: 'Debe conectar botón de copiar mensaje');
      expect(jsCode, contains('buildGeneratorWhatsAppMessage'), reason: 'Debe generar texto contextual para WhatsApp');

      // Verificación de eliminación de bugs
      expect(jsCode.contains('escaneos IA vitalicios`'), isFalse,
          reason: 'No debe sobrescribir saldos reales de celular con texto erróneo de escaneos vitalicios');

      // Verificación de index.html
      final htmlCode = WebBundleLoader.loadHtml();
      expect(htmlCode, isNotEmpty);

      expect(htmlCode, contains('id="chkEnableCustomSettings"'), reason: 'Debe contener switch de ajustes personalizados');
      expect(htmlCode, contains('id="btnResetCustomSettings"'), reason: 'Debe contener botón de restablecer ajustes');
      expect(htmlCode, contains('id="grpLicCustomAiBonus"'), reason: 'Debe agrupar input de bono IA para ocultarlo en plan Bono IA');
      expect(htmlCode, contains('id="btnGenOpenReceipt"'), reason: 'Debe contener botón para abrir boleta');
      expect(htmlCode, contains('id="btnGenCopyMessageAndCode"'), reason: 'Debe contener botón de copiar mensaje');
    });
  });
}
