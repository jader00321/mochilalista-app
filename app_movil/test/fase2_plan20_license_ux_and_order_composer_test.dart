import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/services/license/ed25519_license_validator.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  late SimpleKeyPair testKeyPair;
  late SimplePublicKey testPublicKey;
  const String mockDeviceId = "ML-9999";

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

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    DeviceFingerprint.setMockFingerprint(null);
    Ed25519LicenseValidator.setTestPublicKey(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestableWidget(
    Widget child, {
    LicenseProvider? provider,
    TextScaler? textScaler,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(
          value: provider,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, widget) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler ?? MediaQuery.of(context).textScaler,
            ),
            child: widget!,
          );
        },
        home: child,
      ),
    );
  }

  group('Pilar 1: Motor Estructurado de 3 Bloques en OrderPlanBottomSheet', () {
    const defaultMsg =
        'Hola Julio Angello, deseo solicitar el Plan Semestral (S/ 160.00) para MochilaLista.\nMi código de dispositivo (Hardware ID) es: ML-9999.\nAdjunto mi comprobante de pago por Yape / Transferencia bancaria.';
    const fakeSyncToken = 'MLS1-eyJodyI6Ik1MLTk5OTkifQ.abcdef1234567890';

    test('extractUserBody preserva intactas notas libres manuales del usuario', () {
      final customMsg =
          '$defaultMsg\n\nPor favor emitir con RUC 20601234567 a nombre de Librería San Martín.\n• Estado: Pago realizado vía Yape/Plin. Adjunto comprobante.\n\nRef. soporte: $fakeSyncToken';

      final userBody = OrderPlanBottomSheet.extractUserBody(customMsg);

      expect(userBody, contains(defaultMsg));
      expect(
        userBody,
        contains('Por favor emitir con RUC 20601234567 a nombre de Librería San Martín.'),
      );
      expect(userBody, isNot(contains('• Estado: Pago realizado')));
      expect(userBody, isNot(contains('Ref. soporte:')));
      expect(userBody, isNot(contains(fakeSyncToken)));
    });

    test('composeMessage ensambla los 3 bloques en orden estricto (Cuerpo + Chips + Ref. Soporte)', () {
      const userText = 'Hola Julio Angello, solicitud de prueba.';

      final composed = OrderPlanBottomSheet.composeMessage(
        userBody: userText,
        yapePlin: true,
        bankAccounts: true,
        invoice: true,
        includeLicenseRef: true,
        syncToken: fakeSyncToken,
      );

      // Bloque 1: Cuerpo al inicio
      expect(composed.startsWith(userText), isTrue);

      // Bloque 2: Complementos en orden antes de la ref técnica
      final yapeIndex = composed.indexOf(OrderPlanBottomSheet.yapePlinLine);
      final bankIndex = composed.indexOf(OrderPlanBottomSheet.bankAccountLine);
      final invIndex = composed.indexOf(OrderPlanBottomSheet.invoiceLine);
      final refIndex = composed.indexOf('Ref. soporte: $fakeSyncToken');

      expect(yapeIndex, isNonNegative);
      expect(bankIndex, isNonNegative);
      expect(invIndex, isNonNegative);
      expect(refIndex, isNonNegative);

      expect(yapeIndex < bankIndex, isTrue);
      expect(bankIndex < invIndex, isTrue);
      expect(invIndex < refIndex, isTrue);

      // Bloque 3: Ref. soporte al final
      expect(composed.endsWith('Ref. soporte: $fakeSyncToken'), isTrue);
    });

    test('composeMessage es 100% idempotente al activar/desactivar chips y switch', () {
      var body = OrderPlanBottomSheet.extractUserBody(defaultMsg);

      // Alternar chip Yape ON
      var msg1 = OrderPlanBottomSheet.composeMessage(
        userBody: body,
        yapePlin: true,
        includeLicenseRef: true,
        syncToken: fakeSyncToken,
      );
      expect(msg1, contains(OrderPlanBottomSheet.yapePlinLine));

      // Re-extraer y alternar chip Yape OFF
      body = OrderPlanBottomSheet.extractUserBody(msg1);
      var msg2 = OrderPlanBottomSheet.composeMessage(
        userBody: body,
        yapePlin: false,
        includeLicenseRef: true,
        syncToken: fakeSyncToken,
      );
      expect(msg2, isNot(contains(OrderPlanBottomSheet.yapePlinLine)));
      expect(msg2, contains('Ref. soporte: $fakeSyncToken'));

      // Re-extraer y desactivar switch de licencia
      body = OrderPlanBottomSheet.extractUserBody(msg2);
      var msg3 = OrderPlanBottomSheet.composeMessage(
        userBody: body,
        includeLicenseRef: false,
        syncToken: fakeSyncToken,
      );
      expect(msg3, isNot(contains('Ref. soporte:')));
      expect(msg3.trim(), equals(defaultMsg.trim()));
    });
  });

  group('Pilar 2: Acordeón Inteligente de Planes Comerciales Oficiales', () {
    testWidgets('Usuario en TRIAL: Acordeón inicia desplegado por defecto', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license?.isTrial, isTrue);

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // En TRIAL, los 7 planes son visibles de inmediato
      expect(find.byKey(const ValueKey("accordion_pricing_catalog_header")), findsOneWidget);
      expect(find.text("Planes Comerciales Oficiales"), findsOneWidget);
      expect(find.text("Mensual"), findsOneWidget);
      expect(find.text("Semestral"), findsOneWidget);
      expect(find.text("Perpetua"), findsOneWidget);
    });

    testWidgets('Usuario con Plan Comercial Pagado: Acordeón inicia retraído y se despliega con toque', (tester) async {
      // Simular Plan Anual Comercial Activo
      await testDb.insert('licencia_app', {
        'device_fingerprint': mockDeviceId,
        'tipo_plan': 'ANUAL',
        'estado_actual': 'ACTIVA',
        'fecha_inicio': DateTime.now().toIso8601String(),
        'fecha_expiracion': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
        'fecha_ultimo_check': DateTime.now().toIso8601String(),
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      expect(provider.license?.isActive, isTrue);
      expect(provider.license?.isTrial, isFalse);

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Debe mostrar la tarjeta retraída con el botón "Ver planes y recargas"
      expect(find.byKey(const ValueKey("accordion_pricing_catalog_header")), findsOneWidget);
      expect(find.text("Planes Comerciales Oficiales"), findsOneWidget);
      expect(
        find.textContaining("Explora 7 planes y recargas: mayor ahorro semestral/anual"),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey("btn_toggle_expand_plans")), findsOneWidget);

      // Los planes NO deben estar visibles en el árbol
      expect(find.text("Semestral"), findsNothing);

      // Desplazarse hasta el botón "Ver planes y recargas" y tocar para desplegar
      final expandBtn = find.byKey(const ValueKey("btn_toggle_expand_plans"));
      await tester.scrollUntilVisible(
        expandBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      // Ahora los planes están visibles
      expect(find.text("Semestral"), findsOneWidget);
      expect(find.text("Perpetua"), findsOneWidget);

      // Tocar el header del acordeón para volver a plegar
      final header = find.byKey(const ValueKey("accordion_pricing_catalog_header"));
      await tester.scrollUntilVisible(
        header,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey("btn_toggle_expand_plans")), findsOneWidget);
      expect(find.text("Semestral"), findsNothing);
    });
  });

  group('Pilar 3: Modal Flotante de Detalle de Plan con Blindaje Anti-Toques', () {
    testWidgets('Tocar la tarjeta de un plan abre PlanDetailBottomSheet con beneficios y no solapa modales', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Tocar en la tarjeta de Plan Semestral (abre detalle)
      final semestralTile = find.byKey(const ValueKey("plan_tile_semestral"));
      expect(semestralTile, findsOneWidget);

      await tester.scrollUntilVisible(
        semestralTile,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(semestralTile);
      await tester.pumpAndSettle();

      // Verificar que PlanDetailBottomSheet está en pantalla
      expect(find.byType(PlanDetailBottomSheet), findsOneWidget);
      expect(find.text("Plan Semestral"), findsWidgets);
      expect(find.textContaining("180 días continuos (6 meses)", findRichText: true), findsOneWidget);
      expect(find.textContaining("450 escaneos inteligentes IA incluidos", findRichText: true), findsOneWidget);
      expect(find.text("Beneficios Destacados:"), findsOneWidget);
      expect(find.textContaining("Garantía oficial MochilaLista: Funcionamiento 100% offline"), findsOneWidget);

      // Tocar botón "Pedir (S/ 160.00)" dentro del modal de detalle
      final pedirBtn = find.byKey(const ValueKey("btn_modal_pedir_este_plan"));
      expect(pedirBtn, findsOneWidget);

      await tester.tap(pedirBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // PlanDetailBottomSheet se cerró y ahora está OrderPlanBottomSheet
      expect(find.byType(PlanDetailBottomSheet), findsNothing);
      expect(find.byType(OrderPlanBottomSheet), findsOneWidget);
      expect(find.text("Solicitar Semestral"), findsOneWidget);
    });

    testWidgets('Botón directo "Pedir" en la tarjeta abre OrderPlanBottomSheet en 1 toque', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Tocar el botón directo "Pedir" de Plan Mensual
      final directPedirBtn = find.byKey(const ValueKey("btn_pedir_mensual"));
      expect(directPedirBtn, findsOneWidget);

      await tester.scrollUntilVisible(
        directPedirBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(directPedirBtn);
      await tester.pumpAndSettle();

      // Abre directamente OrderPlanBottomSheet sin pasar por detalle
      expect(find.byType(PlanDetailBottomSheet), findsNothing);
      expect(find.byType(OrderPlanBottomSheet), findsOneWidget);
      expect(find.text("Solicitar Mensual"), findsOneWidget);
    });
  });

  group('Pilar 4: Responsividad 0px Overflow y Cero Emojis Crudos', () {
    final rawEmojiRegex = RegExp(r'[\u{1F300}-\u{1F6FF}\u{1F900}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true);

    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      testWidgets('0px Overflow con TextScaler.linear(1.3) en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(
          buildTestableWidget(
            const LicenseStatusAndActivationScreen(),
            provider: provider,
            textScaler: const TextScaler.linear(1.3),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = prevOnError;

        final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty, reason: "Detectado overflow en ${size.width}x${size.height}");
      });
    }

    testWidgets('Cero emojis crudos en toda la interfaz de Licencia y Modales', (tester) async {
      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in allTextWidgets) {
        final text = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(
          rawEmojiRegex.hasMatch(text),
          isFalse,
          reason: "Texto contiene emoji crudo no permitido: '$text'",
        );
      }
    });
  });
}
