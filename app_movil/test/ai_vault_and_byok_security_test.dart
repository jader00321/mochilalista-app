import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/license_repository.dart';
import 'package:app_movil/core/models/ai_key_model.dart';
import 'package:app_movil/core/services/ai/ai_vault_service.dart';
import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/features/profile/screens/ai_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  const mockDeviceId = 'ML-VAULT-TEST-DEVICE';

  Widget buildTestableWidget(Widget child, {LicenseProvider? provider}) {
    return MaterialApp(
      home: ChangeNotifierProvider<LicenseProvider?>.value(
        value: provider,
        child: child,
      ),
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    await ApiConstants.clearUserCustomApiKey();
    ApiConstants.setAiSelectedMode('INCLUDED');

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    await ApiConstants.clearUserCustomApiKey();
    ApiConstants.setAiSelectedMode('INCLUDED');
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  group('1. Modelo AiKeyModel y Enmascaramiento Visual', () {
    test('maskedKey oculta la parte central y preserva prefijo y sufijo', () {
      final key1 = AiKeyModel(
        id: '1',
        alias: 'Gmail Personal',
        apiKey: 'AIzaSyC73928472938472938472938473x9Q',
        createdAt: DateTime(2026, 11, 19),
      );

      expect(key1.maskedKey, equals('AIzaSy••••••••3x9Q'));
      expect(key1.maskedKey, isNot(contains('7392847293847293847293847')));

      final keyShort = AiKeyModel(
        id: '2',
        alias: 'Corta',
        apiKey: '123456',
        createdAt: DateTime(2026, 11, 19),
      );
      expect(keyShort.maskedKey, equals('12••••56'));
    });
  });

  group('2. AiVaultService — CRUD Multi-Clave y Activación', () {
    test('CRUD completo: agrega con alias obligatorio, cambia clave activa, edita alias y elimina', () async {
      final service = AiVaultService();

      // Validación de alias y clave obligatorios
      expect(
        () => service.addKey(alias: '', apiKey: 'AIzaSy12345'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => service.addKey(alias: 'Test', apiKey: ''),
        throwsA(isA<Exception>()),
      );

      // Agregar Clave 1
      final key1 = await service.addKey(
        alias: 'Gmail Principal',
        apiKey: 'AIzaSyKeyOne998877665544332211AA',
      );
      expect(key1.alias, equals('Gmail Principal'));
      expect(key1.apiKey, equals('AIzaSyKeyOne998877665544332211AA'));

      // Como es la primera clave, se convierte en activa automáticamente
      final active1 = await service.getActiveKey();
      expect(active1?.id, equals(key1.id));
      expect(active1?.alias, equals('Gmail Principal'));

      // Agregar Clave 2
      final key2 = await service.addKey(
        alias: 'Tienda Secundaria',
        apiKey: 'AIzaSyKeyTwo112233445566778899BB',
      );

      final keys = await service.getKeys();
      expect(keys.length, equals(2));

      // Cambiar clave activa a Clave 2
      await service.setActiveKey(key2.id);
      final active2 = await service.getActiveKey();
      expect(active2?.id, equals(key2.id));
      expect(active2?.alias, equals('Tienda Secundaria'));

      // Editar alias de Clave 1
      await service.updateAlias(key1.id, 'Gmail Personal Actualizado');
      final updatedKeys = await service.getKeys();
      expect(updatedKeys.firstWhere((k) => k.id == key1.id).alias, equals('Gmail Personal Actualizado'));

      // Eliminar Clave 2 (activa): la clave activa debe cambiar automáticamente a la restante
      await service.deleteKey(key2.id);
      final keysAfterDelete = await service.getKeys();
      expect(keysAfterDelete.length, equals(1));
      final newActive = await service.getActiveKey();
      expect(newActive?.id, equals(key1.id));

      // Eliminar última clave
      await service.deleteKey(key1.id);
      expect(await service.getKeys(), isEmpty);
      expect(await service.getActiveKey(), isNull);
    });
  });

  group('3. Migración y Destrucción de Clave Plana Heredada', () {
    test('Migra automáticamente clave de SharedPreferences a FlutterSecureStorage y la destruye en texto plano', () async {
      SharedPreferences.setMockInitialValues({
        'user_custom_gemini_api_key': 'AIzaSyLegacyPlaintextKey123456789',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_custom_gemini_api_key'), isNotNull);

      final service = AiVaultService();
      await service.initialize(customPrefs: prefs);

      // Verificación 1: Clave migrada a la bóveda segura con alias descriptivo
      final keys = await service.getKeys();
      expect(keys.length, equals(1));
      expect(keys.first.alias, equals('Mi Clave Gemini (Migrada)'));
      expect(keys.first.apiKey, equals('AIzaSyLegacyPlaintextKey123456789'));

      // Verificación 2: Clave activa asignada
      final active = await service.getActiveKey();
      expect(active?.apiKey, equals('AIzaSyLegacyPlaintextKey123456789'));

      // Verificación 3: Destrucción de la clave en SharedPreferences (cero texto plano residual)
      expect(prefs.getString('user_custom_gemini_api_key'), isNull);
    });
  });

  group('4. Verificación de Conectividad testApiKey (Inmune a Obsolescencia)', () {
    test('testApiKey consulta GET v1beta/models?pageSize=1: éxito con 200 OK y error con 403', () async {
      final service = AiVaultService();
      const validKey = 'AIzaSyValidCommercialKey2026';
      const revokedKey = 'AIzaSyRevokedUnauthorizedKey';

      // MockClient que valida la URL exacta canónica
      final mockClient = MockClient((request) async {
        expect(request.method, equals('GET'));
        expect(request.url.path, equals('/v1beta/models'));
        expect(request.url.queryParameters['pageSize'], equals('1'));

        final keyParam = request.url.queryParameters['key'];
        if (keyParam == validKey) {
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'models/gemini-2.5-flash', 'displayName': 'Gemini 2.5 Flash'}
              ]
            }),
            200,
          );
        } else if (keyParam == revokedKey) {
          return http.Response(
            jsonEncode({
              'error': {'code': 403, 'message': 'API key not valid. Please pass a valid API key.'}
            }),
            403,
          );
        }
        return http.Response('Not Found', 404);
      });

      // Prueba con clave válida
      final successResult = await service.testApiKey(validKey, httpClient: mockClient);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.statusCode, equals(200));
      expect(successResult.message, contains('Clave verificada con éxito'));

      // Prueba con clave revocada
      final errorResult = await service.testApiKey(revokedKey, httpClient: mockClient);
      expect(errorResult.isSuccess, isFalse);
      expect(errorResult.statusCode, equals(403));
      expect(errorResult.message, contains('Clave inválida o revocada por Google'));
    });
  });

  group('5. Widget Tests de AiSettingsScreen y 0px Overflow', () {
    testWidgets('Muestra Selector de Modo, Bóveda Segura, sin texto del 1 de cada mes y botón Google AI Studio', (tester) async {
      final repo = LicenseRepository();
      final licenseProv = LicenseProvider(repository: repo);
      await tester.runAsync(() async {
        await licenseProv.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const AiSettingsScreen(),
        provider: licenseProv,
      ));
      await tester.pumpAndSettle();

      // 1. Selector de Modo
      expect(find.text("Bolsa MochilaLista"), findsOneWidget);
      expect(find.text("Clave Propia (BYOK)"), findsOneWidget);

      // 2. Ausencia total del texto antiguo de reinicio mensual
      expect(find.textContaining("El cupo se restablece automáticamente"), findsNothing);
      expect(find.textContaining("1 de diciembre"), findsNothing);
      expect(find.textContaining("1 de enero"), findsNothing);

      // 3. Tarjeta de bolsa acumulativa
      expect(find.text("Bolsa Acumulativa de IA"), findsOneWidget);
      expect(find.text("50 disponibles"), findsOneWidget);

      // 4. Bóveda segura multi-clave
      expect(find.text("Bóveda Segura Multi-Clave"), findsOneWidget);
      expect(find.text("Agregar Clave"), findsOneWidget);

      // 5. Botón directo a Google AI Studio
      expect(find.text("Abrir Google AI Studio"), findsOneWidget);

      // 6. Conmutar a modo BYOK en el selector
      await tester.tap(find.text("Clave Propia (BYOK)"));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(licenseProv.isUsingByokMode, isTrue);
    });

    testWidgets('0px Overflow en viewport ultra compacto 320x568dp', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LicenseRepository();
      final licenseProv = LicenseProvider(repository: repo);
      await tester.runAsync(() async {
        await licenseProv.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const AiSettingsScreen(),
        provider: licenseProv,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Cotizador Universal IA y Cuota"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('0px Overflow en viewport compacto 360x640dp', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LicenseRepository();
      final licenseProv = LicenseProvider(repository: repo);
      await tester.runAsync(() async {
        await licenseProv.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const AiSettingsScreen(),
        provider: licenseProv,
      ));
      await tester.pumpAndSettle();

      expect(find.text("Cotizador Universal IA y Cuota"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
