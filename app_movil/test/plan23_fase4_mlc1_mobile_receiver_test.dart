import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/commercial_catalog_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/commercial_config_sync_service.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/features/auth/screens/license/license_locked_screen.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = 'ML-P23F4';

  final rawEmojiRegex = RegExp(
    r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );

  dynamic canonicalizeValue(dynamic value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((e) => e.toString()).toList()..sort();
      final out = <String, dynamic>{};
      for (final k in sortedKeys) {
        out[k] = canonicalizeValue(value[k]);
      }
      return out;
    }
    if (value is List) {
      return value.map(canonicalizeValue).toList();
    }
    return value;
  }

  Map<String, dynamic> buildCanonicalPayload({
    required int revision,
    required int iatUnix,
    String sup = '+51 922 836 879',
    String yh = 'Julio Angello Vasquez Navarro',
    String yp = '922836879',
    Map<String, String>? bcp,
    Map<String, String>? bbva,
    Map<String, Map<String, Object>>? productOverrides,
  }) {
    final products = <String, dynamic>{};
    for (final entry in EffectiveCommercialConfig.defaultPlansMap.entries) {
      final ov = productOverrides?[entry.key];
      final spec = entry.value;
      products[entry.key] = <String, dynamic>{
        'ai': ov?['ai'] ?? spec.aiCredits,
        'd': ov?['d'] ?? spec.days,
        'ds': ov?['ds'] ?? spec.description,
        'lb': ov?['lb'] ?? spec.label,
        'pr': ov?['pr'] ?? spec.price,
        'um': ov?['um'] ?? spec.updatesMonths,
      };
    }

    return canonicalizeValue(<String, dynamic>{
          'bbva': bbva ?? <String, String>{'acc': '', 'cci': '', 'h': ''},
          'bcp': bcp ?? <String, String>{'acc': '', 'cci': '', 'h': ''},
          'iat': iatUnix,
          'p': products,
          'sup': sup,
          'v': 1,
          'ver': revision,
          'yh': yh,
          'yp': yp,
        })
        as Map<String, dynamic>;
  }

  Future<String> signCanonicalPayload(
    Map<String, dynamic> payload, {
    SimpleKeyPair? keyPair,
    bool omitDomainPrefix = false,
  }) async {
    final ed25519 = Ed25519();
    final kp = keyPair ?? testKeyPair;
    final payloadJson = jsonEncode(canonicalizeValue(payload));
    final payloadB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(
      utf8.encode(payloadJson),
    );
    final signedBytes = utf8.encode(
      omitDomainPrefix ? payloadB64 : 'MLC1-$payloadB64',
    );
    final sig = await ed25519.sign(signedBytes, keyPair: kp);
    final sigB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(sig.bytes);
    return 'MLC1-$payloadB64.$sigB64';
  }

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final ed25519 = Ed25519();
    testKeyPair = await ed25519.newKeyPair();
    testPublicKey = await testKeyPair.extractPublicKey();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    Ed25519LicenseValidator.setTestPublicKey(testPublicKey.bytes);

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestableScreen(
    Widget child, {
    required LicenseProvider licenseProvider,
    required CommercialCatalogProvider catalogProvider,
    TextScaler? textScaler,
    Size? mediaSize,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(value: licenseProvider),
        ChangeNotifierProvider<CommercialCatalogProvider?>.value(
          value: catalogProvider,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        builder: (context, widget) {
          final current = MediaQuery.of(context);
          return MediaQuery(
            data: current.copyWith(
              size: mediaSize ?? current.size,
              textScaler: textScaler ?? current.textScaler,
            ),
            child: widget!,
          );
        },
        home: child,
      ),
    );
  }

  group('FASE 4.1: Verificación Ed25519 MLC1, Separación de Dominio y Esquema', () {
    test('Valida firma auténtica MLC1 con dominio correcto y extrae hora Perú GMT-5', () async {
      final service = CommercialConfigSyncService();
      // 2026-11-25T19:30:00Z => 2026-11-25 14:30 hora Lima (UTC-5)
      final utcTime = DateTime.utc(2026, 11, 25, 19, 30);
      final payload = buildCanonicalPayload(
        revision: 4,
        iatUnix: (utcTime.millisecondsSinceEpoch / 1000).floor(),
        sup: '+51 999 111 222',
        yp: '999111222',
        productOverrides: {
          'mensual': {'pr': 42.5},
          'migracion': {'pr': 55.0},
        },
      );
      final token = await signCanonicalPayload(payload);
      final whatsappWrapped =
          'Hola, aplica esta actualización oficial:\n\n$token\n\nGracias.';

      expect(CommercialConfigSyncService.extractMlc1Token(whatsappWrapped), equals(token));

      final res = await service.parseAndVerifyToken(whatsappWrapped);
      expect(res.isValid, isTrue);
      expect(res.status, equals('VALID'));
      expect(res.revision, equals(4));
      expect(res.issuedAtLima, equals('25/11/2026 14:30'));
      expect((res.payload!['p']['mensual']['pr'] as num).toDouble(), equals(42.5));
      expect((res.payload!['p']['migracion']['pr'] as num).toDouble(), equals(55.0));
    });

    test('Rechaza firma sin prefijo de dominio MLC1- (separación anti-replay)', () async {
      final service = CommercialConfigSyncService();
      final payload = buildCanonicalPayload(revision: 1, iatUnix: 1795635000);
      final domainlessToken = await signCanonicalPayload(
        payload,
        omitDomainPrefix: true,
      );

      final res = await service.parseAndVerifyToken(domainlessToken);
      expect(res.isValid, isFalse);
      expect(res.status, equals('INVALID_SIGNATURE'));
    });

    test('Rechaza payload adulterado y clave Ed25519 forjada', () async {
      final service = CommercialConfigSyncService();
      final payload = buildCanonicalPayload(revision: 2, iatUnix: 1795635000);
      final validToken = await signCanonicalPayload(payload);
      final parts = validToken.substring('MLC1-'.length).split('.');
      final tamperedPayloadJson = jsonEncode({
        ...payload,
        'sup': '+51 900 000 000',
      });
      final tamperedB64 = Ed25519LicenseValidator.encodeBase64UrlSafe(
        utf8.encode(tamperedPayloadJson),
      );
      final tamperedToken = 'MLC1-$tamperedB64.${parts[1]}';

      final tamperedRes = await service.parseAndVerifyToken(tamperedToken);
      expect(tamperedRes.isValid, isFalse);
      expect(tamperedRes.status, equals('INVALID_SIGNATURE'));

      final foreignKeyPair = await Ed25519().newKeyPair();
      final foreignToken = await signCanonicalPayload(
        payload,
        keyPair: foreignKeyPair,
      );
      final foreignRes = await service.parseAndVerifyToken(foreignToken);
      expect(foreignRes.isValid, isFalse);
      expect(foreignRes.status, equals('INVALID_SIGNATURE'));
    });

    test('Rechaza tokens > 8192 bytes, claves desconocidas y rangos numéricos negativos', () async {
      final service = CommercialConfigSyncService();

      // Oversize > 8192 bytes
      final hugeToken = 'MLC1-${'A' * 8200}.${'B' * 88}';
      final oversizeRes = await service.parseAndVerifyToken(hugeToken);
      expect(oversizeRes.isValid, isFalse);
      expect(oversizeRes.status, equals('EXCEEDS_MAX_SIZE'));

      // Clave extra no autorizada
      final payloadWithScript = buildCanonicalPayload(
        revision: 1,
        iatUnix: 1795635000,
      )..['script'] = 'eval(1)';
      final scriptToken = await signCanonicalPayload(payloadWithScript);
      final scriptRes = await service.parseAndVerifyToken(scriptToken);
      expect(scriptRes.isValid, isFalse);
      expect(scriptRes.status, equals('INVALID_SCHEMA'));

      // Precio negativo
      final negativePayload = buildCanonicalPayload(
        revision: 1,
        iatUnix: 1795635000,
        productOverrides: {'mensual': {'pr': -10}},
      );
      final negativeToken = await signCanonicalPayload(negativePayload);
      final negRes = await service.parseAndVerifyToken(negativeToken);
      expect(negRes.isValid, isFalse);
      expect(negRes.status, equals('INVALID_SCHEMA'));

      // Código fuera de rango en days (> 999999)
      final highDaysPayload = buildCanonicalPayload(
        revision: 1,
        iatUnix: 1795635000,
        productOverrides: {'anual': {'d': 1000001}},
      );
      final highDaysToken = await signCanonicalPayload(highDaysPayload);
      final daysRes = await service.parseAndVerifyToken(highDaysToken);
      expect(daysRes.isValid, isFalse);
      expect(daysRes.status, equals('INVALID_SCHEMA'));
    });
  });

  group('FASE 4.2: SharedPreferences, Anti-Downgrade y CommercialCatalogProvider', () {
    test('Persiste en ml_commercial_config_v1, protege contra downgrade y restaura defaults', () async {
      final catalogProv = CommercialCatalogProvider();
      await catalogProv.loadFromStorage();
      expect(catalogProv.hasSyncedOverride, isFalse);
      expect(catalogProv.mensual.price, equals(35.0));
      expect(catalogProv.supportPhone, equals(OwnerLegalIdentity.supportPhone));

      final tokenRev3 = await signCanonicalPayload(
        buildCanonicalPayload(
          revision: 3,
          iatUnix: 1795640000,
          sup: '+51 944 555 666',
          yh: 'Titular Oficial Sync',
          yp: '944555666',
          bcp: {
            'h': 'Titular BCP',
            'acc': '191-12345678-0-01',
            'cci': '00219100123456780015',
          },
          productOverrides: {
            'mensual': {'pr': 45.0, 'ai': 80},
            'migracion': {'pr': 50.0},
          },
        ),
      );

      final applyRes = await catalogProv.applyToken(tokenRev3);
      expect(applyRes.isValid, isTrue);
      expect(catalogProv.hasSyncedOverride, isTrue);
      expect(catalogProv.revision, equals(3));
      expect(catalogProv.mensual.price, equals(45.0));
      expect(catalogProv.mensual.aiCredits, equals(80));
      expect(catalogProv.migracion.price, equals(50.0));
      expect(catalogProv.supportPhone, equals('+51 944 555 666'));
      expect(catalogProv.yapePhone, equals('944555666'));
      expect(catalogProv.hasBcpConfigured, isTrue);
      expect(catalogProv.hasBbvaConfigured, isFalse);

      // Verificación directa en SharedPreferences y recarga en frío de otro Provider
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CommercialConfigSyncService.prefsKey), isNotNull);

      final coldProvider = CommercialCatalogProvider();
      await coldProvider.loadFromStorage();
      expect(coldProvider.revision, equals(3));
      expect(coldProvider.mensual.price, equals(45.0));
      expect(coldProvider.supportWhatsAppUrl, equals('https://wa.me/51944555666'));

      // Guardia anti-downgrade: Rev. #2 rechazado
      final tokenRev2 = await signCanonicalPayload(
        buildCanonicalPayload(revision: 2, iatUnix: 1795649999),
      );
      final downgradeVerRes = await coldProvider.applyToken(tokenRev2);
      expect(downgradeVerRes.isValid, isFalse);
      expect(downgradeVerRes.status, equals('DOWNGRADE_REJECTED'));
      expect(downgradeVerRes.error, contains('Rev. #3'));
      expect(coldProvider.revision, equals(3));

      // Guardia anti-downgrade: mismo ver = 3 pero iat menor rechazado
      final olderIatSameRev = await signCanonicalPayload(
        buildCanonicalPayload(revision: 3, iatUnix: 1795639000),
      );
      final sameRevOlderRes = await coldProvider.applyToken(olderIatSameRev);
      expect(sameRevOlderRes.isValid, isFalse);
      expect(sameRevOlderRes.status, equals('DOWNGRADE_REJECTED'));

      // Restaurar valores compilados de fábrica
      await coldProvider.resetToCompiledDefaults();
      expect(coldProvider.hasSyncedOverride, isFalse);
      expect(coldProvider.revision, equals(0));
      expect(coldProvider.mensual.price, equals(35.0));
      expect(coldProvider.migracion.price, equals(40.0));
      expect(coldProvider.supportPhone, equals(OwnerLegalIdentity.supportPhone));
      expect(coldProvider.hasBcpConfigured, isFalse);
      expect(prefs.getString(CommercialConfigSyncService.prefsKey), isNull);
    });
  });

  group('FASE 4.3: Flujo UI en LicenseStatusAndActivationScreen + Reset Defaults', () {
    testWidgets('Detecta token MLC1 en input, muestra diálogo confirmatorio, refresca UI y permite restaurar defaults', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final licenseProv = LicenseProvider();
      await tester.runAsync(() async {
        await licenseProv.checkLicense();
      });
      final catalogProv = CommercialCatalogProvider();
      await catalogProv.loadFromStorage();

      final utcTime = DateTime.utc(2026, 11, 25, 20, 15);
      final tokenRev5 = await signCanonicalPayload(
        buildCanonicalPayload(
          revision: 5,
          iatUnix: (utcTime.millisecondsSinceEpoch / 1000).floor(),
          sup: '+51 988 777 666',
          yh: 'Comercial Peru MLC1',
          yp: '988777666',
          bcp: {
            'h': 'Julio Vasquez',
            'acc': '193-98765432-0-10',
            'cci': '00219300987654320102',
          },
          productOverrides: {
            'mensual': {'pr': 45.0, 'ai': 75},
            'migracion': {'pr': 55.0},
          },
        ),
      );

      await tester.pumpWidget(
        buildTestableScreen(
          const LicenseStatusAndActivationScreen(),
          licenseProvider: licenseProv,
          catalogProvider: catalogProv,
        ),
      );
      await tester.pumpAndSettle();

      // Estado inicial fábrica
      expect(find.text('S/ 35.00'), findsWidgets);
      expect(find.byKey(const ValueKey('badge_mlc1_synced_catalog')), findsNothing);

      // Pegar token MLC1 en el campo de código
      await tester.enterText(
        find.byKey(const ValueKey('input_license_activation_code')),
        tokenRev5,
      );
      await tester.pump();

      final activateBtn = find.byKey(const ValueKey('btn_activate_license_code'));
      await tester.ensureVisible(activateBtn);
      await tester.tap(activateBtn);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Debe abrir el diálogo de confirmación MLC1 (nunca LicenseActivationFeedbackModal ML9)
      expect(find.byKey(const ValueKey('dialog_mlc1_confirm_apply')), findsOneWidget);
      expect(find.textContaining('Rev. #5'), findsWidgets);
      expect(find.text('S/ 45.00'), findsWidgets);
      expect(find.textContaining('193-98765432-0-10'), findsWidgets);

      // Confirmar aplicación
      await tester.tap(find.byKey(const ValueKey('btn_mlc1_dialog_apply')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog_mlc1_confirm_apply')), findsNothing);
      expect(catalogProv.hasSyncedOverride, isTrue);
      expect(catalogProv.revision, equals(5));

      // Verificar indicadores vivos y tarifas actualizadas
      expect(find.byKey(const ValueKey('badge_mlc1_synced_catalog')), findsOneWidget);
      expect(
        find.textContaining('Tarifas sincronizadas (Rev. #5 · 25/11/2026 15:15)'),
        findsOneWidget,
      );
      expect(find.text('S/ 45.00'), findsWidgets);
      expect(find.textContaining('988777666'), findsWidgets);
      expect(find.textContaining('193-98765432-0-10'), findsWidgets);
      expect(find.textContaining('S/ 55.00'), findsWidgets);
      expect(
        LicenseStatusAndActivationScreen.buildCustomWhatsAppOrderUri(
          'Hola',
          supportPhoneOverride: catalogProv.supportPhone,
        ).toString(),
        equals('https://wa.me/51988777666?text=Hola'),
      );

      // Drenar CustomSnackBar
      await tester.pump(const Duration(seconds: 5));

      // Intentar downgrade desde UI (Rev. #4 después de Rev. #5): muestra error sin abrir diálogo
      final tokenRev4 = await tester.runAsync(
        () => signCanonicalPayload(
          buildCanonicalPayload(revision: 4, iatUnix: 1795649999),
        ),
      );
      final inputField = find.byKey(
        const ValueKey('input_license_activation_code'),
      );
      await tester.ensureVisible(inputField);
      await tester.enterText(inputField, tokenRev4!);
      await tester.pump();
      await tester.ensureVisible(activateBtn);
      await tester.tap(activateBtn);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('dialog_mlc1_confirm_apply')), findsNothing);
      expect(find.textContaining('Rev. #5'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));

      // Probar botón confirmado "Restaurar defaults"
      final resetBtn = find.byKey(const ValueKey('btn_mlc1_reset_defaults'));
      await tester.ensureVisible(resetBtn);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('dialog_mlc1_reset_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('btn_mlc1_confirm_reset_ok')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(catalogProv.hasSyncedOverride, isFalse);
      expect(find.byKey(const ValueKey('badge_mlc1_synced_catalog')), findsNothing);
      expect(find.text('S/ 35.00'), findsWidgets);

      // Drenar CustomSnackBar de restauración
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('FASE 4.4: 0px Overflow en 320x568 / 360x640 / 412x915 @ 1.3x y Cero Emojis', () {
    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ];

    for (final size in sizes) {
      testWidgets(
        '0px Overflow en LicenseStatusAndActivationScreen y diálogo MLC1 a ${size.width}x${size.height} con TextScaler 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final licenseProv = LicenseProvider();
          await tester.runAsync(() async {
            await licenseProv.checkLicense();
          });
          final catalogProv = CommercialCatalogProvider();
          await tester.runAsync(() async {
            await catalogProv.loadFromStorage();
          });

          // Aplicar Rev. #2 previa con BCP y BBVA llenos para stress de ancho en 320dp
          final appliedToken = await tester.runAsync(
            () => signCanonicalPayload(
              buildCanonicalPayload(
                revision: 2,
                iatUnix: 1795635000,
                sup: '+51 999 888 777',
                yh: 'Julio Angello Vasquez Navarro',
                yp: '999888777',
                bcp: {
                  'h': 'Julio Angello Vasquez',
                  'acc': '191-12345678-0-99',
                  'cci': '00219100123456780991',
                },
                bbva: {
                  'h': 'Julio Angello Vasquez',
                  'acc': '0011-0123-0200456789',
                  'cci': '01112300020045678901',
                },
                productOverrides: {
                  'mensual': {'pr': 39.0, 'ai': 60},
                },
              ),
            ),
          );
          await tester.runAsync(() => catalogProv.applyToken(appliedToken!));

          final tokenRev3 = await tester.runAsync(
            () => signCanonicalPayload(
              buildCanonicalPayload(
                revision: 3,
                iatUnix: 1795640000,
                sup: '+51 999 888 777',
                bcp: {
                  'h': 'Titular BCP',
                  'acc': '191-000111222',
                  'cci': '002191000',
                },
              ),
            ),
          );

          final errors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(details);

          try {
            await tester.pumpWidget(
              buildTestableScreen(
                const LicenseStatusAndActivationScreen(),
                licenseProvider: licenseProv,
                catalogProvider: catalogProv,
                textScaler: const TextScaler.linear(1.3),
                mediaSize: size,
              ),
            );
            await tester.pumpAndSettle();

            // Verificar cero emojis en toda la pantalla
            for (final tw in tester.widgetList<Text>(find.byType(Text))) {
              final t = tw.data ?? tw.textSpan?.toPlainText() ?? '';
              expect(
                rawEmojiRegex.hasMatch(t),
                isFalse,
                reason: 'Emoji crudo detectado en pantalla: $t',
              );
            }

            // Abrir diálogo confirmatorio con Rev. #3 para verificar 0px overflow y cero emojis en diálogo
            final inputFinder = find.byKey(
              const ValueKey('input_license_activation_code'),
            );
            await tester.ensureVisible(inputFinder);
            await tester.enterText(inputFinder, tokenRev3!);
            await tester.pump();
            final applyBtnFinder = find.byKey(
              const ValueKey('btn_activate_license_code'),
            );
            await tester.ensureVisible(applyBtnFinder);
            await tester.tap(applyBtnFinder);
            await tester.runAsync(() async {
              await Future.delayed(const Duration(milliseconds: 100));
            });
            await tester.pumpAndSettle();

            expect(
              find.byKey(const ValueKey('dialog_mlc1_confirm_apply')),
              findsOneWidget,
            );
            for (final tw in tester.widgetList<Text>(find.byType(Text))) {
              final t = tw.data ?? tw.textSpan?.toPlainText() ?? '';
              expect(
                rawEmojiRegex.hasMatch(t),
                isFalse,
                reason: 'Emoji crudo detectado en diálogo MLC1: $t',
              );
            }
            await tester.tap(find.byKey(const ValueKey('btn_mlc1_dialog_cancel')));
            await tester.pumpAndSettle();

            // Verificar LicenseLockedScreen con provider efectivo a la misma resolución y escala
            await tester.pumpWidget(
              buildTestableScreen(
                const LicenseLockedScreen(isPendingMigration: false),
                licenseProvider: licenseProv,
                catalogProvider: catalogProv,
                textScaler: const TextScaler.linear(1.3),
                mediaSize: size,
              ),
            );
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = prevOnError;
          }

          final overflowErrors = errors
              .where((e) => e.toString().toLowerCase().contains('overflowed'))
              .toList();
          expect(
            overflowErrors,
            isEmpty,
            reason:
                'Overflow detectado en ${size.width}x${size.height}: ${overflowErrors.map((e) => e.exceptionAsString()).join('\n')}',
          );
        },
      );
    }
  });
}
