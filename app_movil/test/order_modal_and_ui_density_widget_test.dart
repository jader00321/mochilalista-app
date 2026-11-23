import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/core/services/device_fingerprint.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';
import 'package:app_movil/features/auth/screens/license/license_status_and_activation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;
  const String mockDeviceId = "ML-4K9B";
  String clipboardContent = '';

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DeviceFingerprint.setMockFingerprint(mockDeviceId);
    clipboardContent = '';

    testDb = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(testDb);
    LocalDatabase.setCustomDatabase(testDb);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardContent};
        }
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          clipboardContent = (args?['text'] as String?) ?? '';
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    DeviceFingerprint.setMockFingerprint(null);
    LocalDatabase.setCustomDatabase(null);
    await testDb.close();
  });

  Widget buildTestableWidget(Widget child, {LicenseProvider? provider}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LicenseProvider?>.value(
          value: provider,
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Pilar 3: Bottom Sheet Profesional OrderPlanBottomSheet', () {
    testWidgets('Tocar Pedir abre Bottom Sheet editable en 3 zonas con resumen, TextField, Copiar y Restablecer', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      // Scroll hacia la sección de planes
      await tester.scrollUntilVisible(
        find.text("Planes Comerciales Oficiales"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Encontrar el botón Pedir del plan Trimestral
      final pedirTrimestralFinder = find.ancestor(
        of: find.text("Trimestral"),
        matching: find.byType(Container),
      );
      expect(pedirTrimestralFinder, findsWidgets);

      // Localizar los botones Pedir
      final pedirButtons = find.widgetWithText(InkWell, "Pedir");
      expect(pedirButtons, findsWidgets);

      // Pulsar Pedir en el segundo plan (Trimestral)
      await tester.tap(pedirButtons.at(1));
      await tester.pumpAndSettle();

      // 1. Debe abrirse el Bottom Sheet interactivo en 3 zonas
      expect(find.text("Solicitar Trimestral"), findsOneWidget);
      expect(find.text("S/ 90.00"), findsWidgets);
      expect(find.text("+180 IA"), findsWidgets);
      expect(find.textContaining(mockDeviceId), findsWidgets);
      expect(find.text("Mensaje (Editable)"), findsOneWidget);

      // 2. Comprobar texto precargado en el TextField
      final defaultExpectedMsg = OwnerLegalIdentity.buildPlanOrderMessage(
        planName: "Trimestral",
        price: "S/ 90.00",
        hardwareId: mockDeviceId,
      );
      final textFieldFinder = find.descendant(
        of: find.byType(OrderPlanBottomSheet),
        matching: find.byType(TextField),
      );
      expect(textFieldFinder, findsOneWidget);
      expect(find.textContaining(defaultExpectedMsg), findsOneWidget);

      // 3. Editar texto en el TextField
      const String customUserMsg = "Hola Julio, adjunto captura Yape por S/ 90.00 para Bodega Los Andes. ID: ML-4K9B";
      await tester.enterText(textFieldFinder, customUserMsg);
      await tester.pumpAndSettle();
      expect(find.text(customUserMsg), findsOneWidget);

      // 4. Probar botón "Copiar Mensaje"
      final copyMsgBtn = find.widgetWithText(OutlinedButton, "Copiar Mensaje");
      expect(copyMsgBtn, findsOneWidget);
      await tester.tap(copyMsgBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(clipboardContent, equals(customUserMsg));

      // 5. Verificar helper puro buildCustomWhatsAppOrderUri
      final uri = LicenseStatusAndActivationScreen.buildCustomWhatsAppOrderUri(customUserMsg);
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('wa.me'));
      expect(uri.path, equals('/51922836879'));
      expect(uri.queryParameters['text'], equals(customUserMsg));

      // 6. Probar botón "Restablecer"
      final resetMsgBtn = find.widgetWithText(OutlinedButton, "Restablecer");
      expect(resetMsgBtn, findsOneWidget);
      await tester.tap(resetMsgBtn);
      await tester.pumpAndSettle();
      expect(find.textContaining(defaultExpectedMsg), findsOneWidget);

      // 7. Cerrar modal con botón cerrar
      final closeBtn = find.byTooltip("Cerrar");
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(find.text("Solicitar Trimestral"), findsNothing);

      // Limpiar timers pendientes de CustomSnackBar
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Protección Real sobre Barra de Navegación Android: Enviar por WhatsApp queda sobre la barra con 0px Overflow', (tester) async {
      const double screenHeight = 800.0;
      const double screenWidth = 360.0;
      tester.view.physicalSize = const Size(screenWidth, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48.0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text("Planes Comerciales Oficiales"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final pedirButtons = find.widgetWithText(InkWell, "Pedir");
      await tester.tap(pedirButtons.first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final whatsAppBtn = find.widgetWithText(ElevatedButton, "Enviar por WhatsApp");
      expect(whatsAppBtn, findsOneWidget);

      final btnRect = tester.getRect(whatsAppBtn);
      expect(btnRect.bottom, lessThanOrEqualTo(screenHeight - 48.0),
          reason: "El botón de WhatsApp no debe quedar cubierto por la barra de 48dp de Android");

      await tester.tap(find.byTooltip("Cerrar"));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Interacción completa de chips de 1 toque (toggle sin duplicados), reset y micro-botón de Hardware ID', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text("Planes Comerciales Oficiales"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final pedirButtons = find.widgetWithText(InkWell, "Pedir");
      await tester.tap(pedirButtons.first);
      await tester.pumpAndSettle();

      // 1. Probar micro-botón de copiado de Hardware ID
      final copyIdBtn = find.widgetWithText(InkWell, "Copiar ID");
      expect(copyIdBtn, findsOneWidget);
      await tester.tap(copyIdBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(clipboardContent, equals(mockDeviceId), reason: "El micro-botón debe copiar exactamente el Hardware ID");

      // 2. Probar Chip 1: "Ya hice Yape/Plin"
      final chipYape = find.text("Ya hice Yape/Plin");
      expect(chipYape, findsOneWidget);
      await tester.tap(chipYape);
      await tester.pumpAndSettle();

      expect(find.textContaining("Pago realizado vía Yape/Plin. Adjunto comprobante."), findsOneWidget);

      // 3. Probar Chip 2: "Pedir BCP/BBVA"
      final chipBank = find.text("Pedir BCP/BBVA");
      expect(chipBank, findsOneWidget);
      await tester.ensureVisible(chipBank);
      await tester.tap(chipBank);
      await tester.pumpAndSettle();

      expect(find.textContaining("Solicito números de cuenta para transferencia bancaria."), findsOneWidget);

      // 4. Probar Chip 3: "Necesito Factura"
      final chipInvoice = find.text("Necesito Factura");
      expect(chipInvoice, findsOneWidget);
      await tester.ensureVisible(chipInvoice);
      await tester.tap(chipInvoice);
      await tester.pumpAndSettle();

      expect(find.textContaining("Solicito emisión de Factura con RUC."), findsOneWidget);

      // 5. Destocar Chip 1 (Toggle OFF)
      await tester.ensureVisible(chipYape);
      await tester.tap(chipYape);
      await tester.pumpAndSettle();
      expect(find.textContaining("Pago realizado vía Yape/Plin. Adjunto comprobante."), findsNothing);
      expect(find.textContaining("Solicito números de cuenta para transferencia bancaria."), findsOneWidget);
      expect(find.textContaining("Solicito emisión de Factura con RUC."), findsOneWidget);

      // 6. Restablecer desmarca todos los chips y devuelve texto original
      final resetBtn = find.widgetWithText(OutlinedButton, "Restablecer");
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      final defaultExpectedMsg = OwnerLegalIdentity.buildPlanOrderMessage(
        planName: "Mensual",
        price: "S/ 35.00",
        hardwareId: mockDeviceId,
      );
      expect(find.textContaining(defaultExpectedMsg), findsOneWidget);
      expect(find.textContaining("Pago realizado vía Yape/Plin"), findsNothing);
      expect(find.textContaining("Solicito números de cuenta"), findsNothing);
      expect(find.textContaining("Solicito emisión de Factura"), findsNothing);

      await tester.tap(find.byTooltip("Cerrar"));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Pilar 4.2: Simetría Geométrica de Botones QR y Badges IA', () {
    testWidgets('Botones Escanear QR y QR desde Galería tienen exactamente la misma altura (>=48dp)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      final btnCameraFinder = find.widgetWithText(OutlinedButton, "Escanear QR");
      final btnGalleryFinder = find.widgetWithText(OutlinedButton, "QR desde Galería");

      expect(btnCameraFinder, findsOneWidget);
      expect(btnGalleryFinder, findsOneWidget);

      final sizeCamera = tester.getSize(btnCameraFinder);
      final sizeGallery = tester.getSize(btnGalleryFinder);

      expect(sizeCamera.height, equals(sizeGallery.height), reason: "Ambos botones QR deben tener idéntica altura visual");
      expect(sizeCamera.height, greaterThanOrEqualTo(48.0), reason: "La altura mínima uniforme debe ser al menos 48dp");
    });

    testWidgets('Catálogo contiene los 7 badges de escaneos IA acumulativos (+50 IA hasta +1,200 IA)', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = LicenseProvider();
      await tester.runAsync(() async {
        await provider.checkLicense();
      });

      await tester.pumpWidget(buildTestableWidget(
        const LicenseStatusAndActivationScreen(),
        provider: provider,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text("Planes Comerciales Oficiales"),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final requiredAiBadges = [
        "+50 IA",     // Mensual
        "+180 IA",    // Trimestral
        "+450 IA",    // Semestral
        "+1,200 IA",  // Anual
        "+200 IA",    // Perpetua
        "+150 IA",    // Bolsa Extra IA
        "+100 IA",    // Pase Anual de Updates
      ];

      for (final badge in requiredAiBadges) {
        expect(find.text(badge), findsWidgets, reason: "Debe existir el badge de escaneo $badge en el tarifario");
      }
    });
  });

  group('Pilar 4.3: Densidad de Pantalla y 0px Overflow en 320x568dp y 360x640dp', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      testWidgets('LicenseStatusAndActivationScreen y Bottom Sheet de Pedido renderizan con 0px overflow en ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final provider = LicenseProvider();
        await tester.runAsync(() async {
          await provider.checkLicense();
        });

        await tester.pumpWidget(buildTestableWidget(
          const LicenseStatusAndActivationScreen(),
          provider: provider,
        ));
        await tester.pumpAndSettle();

        expect(find.byType(LicenseStatusAndActivationScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: "Sin overflow al renderizar pantalla principal en $size");

        // Scroll hacia los planes
        await tester.scrollUntilVisible(
          find.text("Planes Comerciales Oficiales"),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Tocar el primer chip de Pedir (Mensual)
        final pedirChips = find.widgetWithText(InkWell, "Pedir");
        await tester.scrollUntilVisible(
          pedirChips.first,
          50,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(pedirChips.first);
        await tester.pumpAndSettle();

        // Verificar modal de Pedir abierto
        expect(find.text("Solicitar Mensual"), findsOneWidget);
        expect(find.text("Enviar por WhatsApp"), findsOneWidget);
        expect(tester.takeException(), isNull, reason: "Sin overflow en el modal editable de pedido en $size");

        // Cerrar modal
        await tester.tap(find.byTooltip("Cerrar"));
        await tester.pumpAndSettle();

        // Limpiar timers pendientes si hubiere
        await tester.pump(const Duration(seconds: 4));
      });
    }
  });
}
