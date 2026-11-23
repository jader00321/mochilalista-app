import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/core/services/sync/client_sync_service.dart';
import 'package:app_movil/features/auth/screens/license/license_locked_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 5: Protocolo Dual de Sincronización Offline (ClientSyncService)', () {
    test('1. Paridad Criptográfica 1:1 con vector canónico de Fase 4', () {
      final syncService = ClientSyncService();

      // Vector canónico exacto sincronizado con mochilalista_admin/test/client_offline_sync_and_migration_test.dart
      final payload = <String, dynamic>{
        'v': 1,
        'hw': 'ML-7K9A',
        'bhw': null,
        'mod': 'Samsung Galaxy A54 5G',
        'os': 'Android 14 (API 34)',
        'av': '9.38.0',
        'bc': 82,
        'db': 36,
        'pl': 'MENSUAL',
        'st': 'ACTIVA',
        'exp': '2026-12-31',
        'dr': 38,
        'n': 5,
        'ai': 42,
        'aiu': 18,
        'byok': false,
        'pc': 1,
        'drv': true,
        'bh': 'OK',
        'lb': '2026-11-23T10:00:00Z',
        'ts': 1795430000000,
      };

      const expectedToken =
          'MLS1-eyJ2IjoxLCJodyI6Ik1MLTdLOUEiLCJiaHciOm51bGwsIm1vZCI6IlNhbXN1bmcgR2FsYXh5IEE1NCA1RyIsIm9zIjoiQW5kcm9pZCAxNCAoQVBJIDM0KSIsImF2IjoiOS4zOC4wIiwiYmMiOjgyLCJkYiI6MzYsInBsIjoiTUVOU1VBTCIsInN0IjoiQUNUSVZBIiwiZXhwIjoiMjAyNi0xMi0zMSIsImRyIjozOCwibiI6NSwiYWkiOjQyLCJhaXUiOjE4LCJieW9rIjpmYWxzZSwicGMiOjEsImRydiI6dHJ1ZSwiYmgiOiJPSyIsImxiIjoiMjAyNi0xMS0yM1QxMDowMDowMFoiLCJ0cyI6MTc5NTQzMDAwMDAwMH0.QIj8FO1DHXdH4DTxraO6tQ';

      final token = syncService.generateSyncToken(payload);
      expect(token, equals(expectedToken), reason: 'El token generado debe ser idéntico al vector de prueba de Fase 4');
    });

    test('2. Blindaje de Privacidad: Lista blanca estricta de 21 claves', () async {
      final syncService = ClientSyncService();

      final contaminatedData = <String, dynamic>{
        'v': 1,
        'hw': 'ML-PRIV1',
        'mod': 'Test Phone',
        // Datos comerciales contaminantes prohibidos:
        'cliente_nombre': 'Juan Pérez',
        'ruc': '10456789012',
        'total_ventas': 15400.50,
        'margen_ganancia': 35.8,
        'productos': ['Gaseosa 500ml', 'Arroz 1kg'],
      };

      final clean = syncService.filterAllowedKeys(contaminatedData);
      expect(clean.containsKey('cliente_nombre'), isFalse);
      expect(clean.containsKey('ruc'), isFalse);
      expect(clean.containsKey('total_ventas'), isFalse);
      expect(clean.containsKey('margen_ganancia'), isFalse);
      expect(clean.containsKey('productos'), isFalse);
      expect(clean.containsKey('v'), isTrue);
      expect(clean.containsKey('hw'), isTrue);
      expect(clean.containsKey('mod'), isTrue);

      final token = syncService.generateSyncToken(contaminatedData);
      expect(token.contains('Juan'), isFalse);
      expect(token.contains('15400'), isFalse);
    });

    test('3. Generación y serialización de archivo JSON .mlsync', () async {
      final syncService = ClientSyncService();
      final tempDir = await Directory.systemTemp.createTemp('mlsync_test_');

      try {
        final payload = await syncService.buildCurrentSnapshot(
          overrideHw: 'ML-FILE99',
          overrideMod: 'Redmi Note 12',
          overrideOs: 'Android 13',
          overrideAv: '9.37.0',
          overrideBc: 81,
          overrideDb: 36,
          overridePl: 'TRIMESTRAL',
          overrideSt: 'ACTIVA',
          overrideExp: '2027-02-15T00:00:00Z',
          overrideDr: 84,
          overrideN: 2,
          overrideAi: 70,
          overrideAiu: 30,
          overrideByok: false,
          overridePc: 1,
          overrideDrv: true,
          overrideBh: 'OPTIMAL',
          overrideLb: '2026-11-20T12:00:00Z',
          overrideTs: 1795431234567,
        );

        final file = await syncService.createMlsyncTempFile(payload, targetDir: tempDir);
        expect(await file.exists(), isTrue);
        expect(file.path.endsWith('Estado_MochilaLista_ML-FILE99.mlsync'), isTrue);

        final fileJson = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(fileJson['format'], equals('MLSYNC_V1'));
        expect(fileJson['hardware_id'], equals('ML-FILE99'));
        expect(fileJson['token'], startsWith('MLS1-'));
        expect(fileJson['summary']['app_version'], equals('9.37.0'));
        expect(fileJson['summary']['ai_balance'], equals(70));
        expect(fileJson['summary']['backup_health'], equals('OPTIMAL'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('4. Inserción y remoción limpia de token en mensajes WhatsApp', () {
      final syncService = ClientSyncService();
      const baseMessage = 'Hola Julio Angello, solicito activar mi plan en MochilaLista.';
      const dummyToken = 'MLS1-eyJ2IjoxLCJodyI6Ik1MLVRFU1QifQ.AbCdEf1234567890';

      // Anexar
      final withToken = syncService.appendSyncTokenToMessage(baseMessage, dummyToken);
      expect(withToken, contains('Ref. soporte: MLS1-'));
      expect(syncService.messageContainsSyncToken(withToken), isTrue);

      // No duplicar si se llama de nuevo
      final withTokenAgain = syncService.appendSyncTokenToMessage(withToken, dummyToken);
      expect(withTokenAgain, equals(withToken));

      // Remover
      final stripped = syncService.removeSyncTokenFromMessage(withToken);
      expect(stripped, equals(baseMessage));
      expect(syncService.messageContainsSyncToken(stripped), isFalse);
    });
  });

  group('FASE 5: Vía B - Switch Amigable en OrderPlanBottomSheet', () {
    testWidgets('Switch activo por defecto anexa token; al desactivar lo elimina en vivo', (tester) async {
      const dummyToken = 'MLS1-eyJ2IjoxLCJodyI6Ik1MLVRFU1QyIn0.XyZ1234567890123';
      String sentMessage = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderPlanBottomSheet(
              planName: 'Mensual',
              price: 'S/ 35.00',
              desc: 'Ideal para probar mes a mes',
              aiScansBadge: '+50 IA',
              hardwareId: 'ML-TEST2',
              defaultMessage: 'Hola Julio Angello, deseo activar el Plan Mensual.',
              syncToken: dummyToken,
              isDark: false,
              onSendWhatsApp: (msg) {
                sentMessage = msg;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verificar presencia del switch y textos tranquilizadores
      final switchFinder = find.byKey(const ValueKey('switch_include_license_ref'));
      expect(switchFinder, findsOneWidget);
      expect(find.text('Incluir datos de mi licencia para atención rápida'), findsOneWidget);
      expect(find.text('Ayuda a verificar tu plan y agilizar tu solicitud'), findsOneWidget);

      // 2. Verificar que inicialmente el switch está encendido (true) y el mensaje contiene la referencia
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final initialController = tester.widget<TextField>(textFieldFinder).controller!;
      expect(initialController.text, contains('Ref. soporte: $dummyToken'));

      // 3. Desactivar el switch con tap
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verificar que el switch está en false y el mensaje ya NO contiene el token
      final updatedSwitch = tester.widget<Switch>(switchFinder);
      expect(updatedSwitch.value, isFalse);
      expect(initialController.text.contains('Ref. soporte:'), isFalse);

      // 4. Volver a encender el switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(switchFinder).value, isTrue);
      expect(initialController.text, contains('Ref. soporte: $dummyToken'));

      // 5. Pulsar "Enviar por WhatsApp" y validar el mensaje emitido
      final sendBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar por WhatsApp');
      expect(sendBtnFinder, findsOneWidget);
      await tester.tap(sendBtnFinder);
      await tester.pumpAndSettle();

      expect(sentMessage, contains('Ref. soporte: $dummyToken'));
    });
  });

  group('FASE 5: Vía C - Rescate Directo en LicenseLockedScreen (PENDIENTE_MIGRACION)', () {
    testWidgets('Muestra botones de rescate y ficha .mlsync cuando isPendingMigration es true', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ShareParams? capturedShareParams;
      ClientSyncService.clientShareOverride = (params) async {
        capturedShareParams = params;
        return true;
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: LicenseLockedScreen(
            isPendingMigration: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Título y descripción de migración
      expect(find.text('Migración de Dispositivo'), findsOneWidget);

      // 2. Botón principal de WhatsApp de migración
      final waBtnFinder = find.byKey(const ValueKey('btn_locked_whatsapp'));
      expect(waBtnFinder, findsOneWidget);
      expect(find.text('Enviar solicitud de migración por WhatsApp'), findsOneWidget);

      // 3. Botón secundario para compartir ficha .mlsync
      final shareMlsyncBtn = find.byKey(const ValueKey('btn_locked_share_mlsync'));
      expect(shareMlsyncBtn, findsOneWidget);
      expect(find.text('Compartir ficha de migración (.mlsync)'), findsOneWidget);

      // 4. Switch para incluir datos de licencia activo
      final switchFinder = find.byKey(const ValueKey('switch_locked_include_license_ref'));
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // 5. Pulsar compartir ficha de migración y verificar interceptación de share
      await tester.tap(shareMlsyncBtn);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(capturedShareParams, isNotNull);
      expect(capturedShareParams!.files, isNotNull);
      expect(capturedShareParams!.files!.first.path, contains('.mlsync'));

      // Drenar timer de CustomSnackBar (3.68s)
      await tester.pump(const Duration(seconds: 5));

      ClientSyncService.clientShareOverride = null;
    });
  });

  group('FASE 5: Vía A - Botón Compartir Estado en LicenseStatusAndActivationScreen', () {
    testWidgets('Muestra botón btn_share_client_sync_state y genera ficha .mlsync al pulsar', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      ShareParams? capturedShareParams;
      ClientSyncService.clientShareOverride = (params) async {
        capturedShareParams = params;
        return true;
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: LicenseStatusAndActivationScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final shareBtnFinder = find.byKey(const ValueKey('btn_share_client_sync_state'));
      expect(shareBtnFinder, findsOneWidget);
      expect(find.text('Compartir estado con Soporte'), findsOneWidget);

      await tester.tap(shareBtnFinder);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(capturedShareParams, isNotNull);
      expect(capturedShareParams!.files, isNotNull);
      expect(capturedShareParams!.files!.first.path, contains('.mlsync'));

      // Drenar timer de CustomSnackBar (3.68s)
      await tester.pump(const Duration(seconds: 5));

      ClientSyncService.clientShareOverride = null;
    });
  });

  group('FASE 5: Verificación de 0px Overflow a 1.3x y Cero Emojis Crudos', () {
    final screenSizes = [
      const Size(320, 568), // iPhone SE 1st gen / pantalla compacta
      const Size(360, 640), // Android estándar económico
      const Size(412, 915), // Android moderno
    ];

    for (final size in screenSizes) {
      testWidgets('0px Overflow en LicenseLockedScreen a ${size.width}x${size.height}dp con textScaler 1.3x', (tester) async {
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: const LicenseLockedScreen(isPendingMigration: true),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'No debe haber overflow en ${size.width}x${size.height}dp');
      });

      testWidgets('0px Overflow en OrderPlanBottomSheet a ${size.width}x${size.height}dp con textScaler 1.3x', (tester) async {
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.3),
              ),
              child: Scaffold(
                body: OrderPlanBottomSheet(
                  planName: 'Anual',
                  price: 'S/ 280.00',
                  desc: 'Mayor ahorro comercial',
                  aiScansBadge: '+1,200 IA',
                  hardwareId: 'ML-TEST-RESPONSIVE',
                  defaultMessage: 'Hola, deseo solicitar el Plan Anual.',
                  syncToken: 'MLS1-eyJ2IjoxfQ.ABC123',
                  isDark: false,
                  onSendWhatsApp: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'No debe haber overflow en OrderPlanBottomSheet');
      });
    }

    test('Cero emojis crudos en los archivos nuevos y modificados de Fase 5', () {
      final syncServiceFile = File('lib/core/services/sync/client_sync_service.dart');
      final lockedScreenFile = File('lib/features/auth/screens/license/license_locked_screen.dart');

      final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);

      if (syncServiceFile.existsSync()) {
        final content = syncServiceFile.readAsStringSync();
        expect(emojiRegex.hasMatch(content), isFalse, reason: 'client_sync_service.dart no debe contener emojis crudos');
      }

      if (lockedScreenFile.existsSync()) {
        final content = lockedScreenFile.readAsStringSync();
        expect(emojiRegex.hasMatch(content), isFalse, reason: 'license_locked_screen.dart no debe contener emojis crudos');
      }
    });
  });
}
