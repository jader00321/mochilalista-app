import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

class MockAuthProviderForPhase4Test extends ChangeNotifier implements AuthProvider {
  final UserModel _user = UserModel(
    id: 1,
    fullName: "Comerciante Fase 4",
    phone: "999888777",
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: "Negocio Fase 4",
    address: "Av. Industrial 123",
    moneda: "PEN",
  );

  @override
  UserModel? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => true;

  @override
  int? get activeBusinessId => 1;

  @override
  int? get activeUserId => 1;

  @override
  BusinessModel? get currentBusiness => _business;

  @override
  String get userName => "Comerciante Fase 4";

  @override
  String get businessName => "Negocio Fase 4";

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockLicenseProviderForPhase4Test extends ChangeNotifier implements LicenseProvider {
  final int _scans;
  final bool _byok;

  MockLicenseProviderForPhase4Test({int scans = 69, bool byok = false})
      : _scans = scans,
        _byok = byok;

  @override
  int get remainingAiScans => _scans;

  @override
  bool get isUsingByokMode => _byok;

  @override
  bool get isUsingCustomApiKey => _byok;

  @override
  Future<bool> canPerformAiScan({DateTime? overrideNow}) async => true;

  @override
  Future<bool> consumeAiScan({DateTime? overrideNow}) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockScannerProviderForPhase4Test extends ChangeNotifier implements ScannerProvider {
  @override
  String get statusMessage => "";

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockSmartQuotationProviderForPhase4Test extends ChangeNotifier implements SmartQuotationProvider {
  @override
  String get errorMessage => "";

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget createTestApp({
  required Widget child,
  LicenseProvider? licenseProvider,
  bool isDark = true,
  Size screenSize = const Size(412, 915),
  EdgeInsets viewPadding = const EdgeInsets.only(bottom: 48),
  double textScale = 1.0,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: MockAuthProviderForPhase4Test()),
      ChangeNotifierProvider<ScannerProvider>.value(value: MockScannerProviderForPhase4Test()),
      ChangeNotifierProvider<SmartQuotationProvider>.value(value: MockSmartQuotationProviderForPhase4Test()),
      if (licenseProvider != null)
        ChangeNotifierProvider<LicenseProvider>.value(value: licenseProvider)
      else
        Provider<LicenseProvider?>.value(value: null),
    ],
    child: MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14141C),
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          viewPadding: viewPadding,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FASE 4 - Rediseño Profesional de Escanear Factura (ScanMode.invoice)', () {
    testWidgets('1. Elementos visuales completos en modo Escanear Factura con cuota oficial', (tester) async {
      final licenseProv = MockLicenseProviderForPhase4Test(scans: 69, byok: false);

      await tester.pumpWidget(
        createTestApp(
          child: const ScanScreen(mode: ScanMode.invoice),
          licenseProvider: licenseProv,
        ),
      );
      await tester.pumpAndSettle();

      // AppBar
      expect(find.text('Escanear Factura'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
      expect(find.byType(InfoTooltipButton), findsOneWidget);

      // Tarjeta Hero
      expect(find.text('Procesa tu Compra'), findsOneWidget);
      expect(
        find.text('Digitaliza tu factura o boleta de proveedor y actualiza tu stock automáticamente.'),
        findsOneWidget,
      );

      // Badge en vivo de escaneos IA
      expect(find.text('69 escaneos IA disponibles'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);

      // Tarjetas interactivas de Cámara y Galería
      expect(find.text('Cámara'), findsOneWidget);
      expect(find.text('Toma una foto nítida de la factura'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      expect(find.text('Galería'), findsOneWidget);
      expect(find.text('Sube una imagen o captura guardada'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);

      // Bloque inferior pedagógico
      expect(find.text('¿Qué procesa la IA automáticamente?'), findsOneWidget);
      expect(find.text('Ítems y Cantidades'), findsOneWidget);
      expect(find.text('Detecta cada producto y sus unidades de compra.'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      expect(find.text('Costos y Márgenes'), findsOneWidget);
      expect(find.text('Calcula el costo unitario y ayuda a definir tu precio de venta.'), findsOneWidget);
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);

      expect(find.text('Reposición Directa'), findsOneWidget);
      expect(find.text('Actualiza tu inventario al confirmar sin digitar uno por uno.'), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      // Consejo de captura óptima
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);
      expect(
        find.text('Consejo: Coloca la factura sobre una superficie plana, con buena iluminación y evitando sombras o dobleces.'),
        findsOneWidget,
      );
    });

    testWidgets('2. Badge reactivo en modo BYOK / Clave Propia', (tester) async {
      final licenseProv = MockLicenseProviderForPhase4Test(scans: 0, byok: true);

      await tester.pumpWidget(
        createTestApp(
          child: const ScanScreen(mode: ScanMode.invoice),
          licenseProvider: licenseProv,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IA Ilimitada (Clave Propia)'), findsOneWidget);
      expect(find.byIcon(Icons.key_rounded), findsOneWidget);
    });

    testWidgets('3. Seguridad nullable: LicenseProvider null no causa excepción', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ScanScreen(mode: ScanMode.invoice),
          licenseProvider: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Escanear Factura'), findsOneWidget);
      expect(find.text('Procesa tu Compra'), findsOneWidget);
      expect(find.text('IA Oficial Activa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Cero emojis crudos en todo el texto renderizado de Escanear Factura', (tester) async {
      final licenseProv = MockLicenseProviderForPhase4Test(scans: 25, byok: false);

      await tester.pumpWidget(
        createTestApp(
          child: const ScanScreen(mode: ScanMode.invoice),
          licenseProvider: licenseProv,
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      for (final textWidget in textWidgets) {
        final content = textWidget.data ?? '';
        expect(
          emojiPattern.hasMatch(content),
          isFalse,
          reason: 'El texto "$content" no debe contener emojis crudos.',
        );
      }
    });

    testWidgets('5. Responsividad certificada (0px Overflow) en 320x568dp, 360x640dp y 412x915dp con TextScaler 1.3', (tester) async {
      final licenseProv = MockLicenseProviderForPhase4Test(scans: 5, byok: false);
      final viewports = [
        const Size(320, 568), // iPhone SE / ultra compacto
        const Size(360, 640), // Android compacto
        const Size(412, 915), // Samsung Galaxy A54 5G
      ];

      for (final size in viewports) {
        for (final isDark in [true, false]) {
          await tester.pumpWidget(
            createTestApp(
              child: const ScanScreen(mode: ScanMode.invoice),
              licenseProvider: licenseProv,
              isDark: isDark,
              screenSize: size,
              viewPadding: const EdgeInsets.only(bottom: 48),
              textScale: 1.3,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow detectado en viewport ${size.width}x${size.height} con isDark=$isDark y scale=1.3',
          );
          expect(find.text('Procesa tu Compra'), findsOneWidget);
        }
      }
    });

    testWidgets('6. Preservación intacta de Escanear Lista (ScanMode.quotation)', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ScanScreen(mode: ScanMode.quotation),
        ),
      );
      await tester.pumpAndSettle();

      // Debe conservar título de Lista
      expect(find.text('Escanear Lista'), findsOneWidget);
      expect(find.text('Digitaliza tu Lista'), findsOneWidget);

      // Chips multi-rubro intactos
      expect(find.text('Compras / Pedido'), findsOneWidget);
      expect(find.text('Mayorista / Negocio'), findsOneWidget);
      expect(find.text('Lista Escolar'), findsOneWidget);

      // NO debe tener el bloque pedagógico exclusivo de factura
      expect(find.text('¿Qué procesa la IA automáticamente?'), findsNothing);
      expect(find.text('Ítems y Cantidades'), findsNothing);

      // 0 errores
      expect(tester.takeException(), isNull);
    });
  });
}
