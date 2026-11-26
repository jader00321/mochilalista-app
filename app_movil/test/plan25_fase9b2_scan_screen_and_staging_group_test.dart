import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/catalog/models/brand_model.dart';
import 'package:app_movil/features/catalog/models/category_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/scanner/widgets/staging/staging_product_group_card.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Directory _resolveAppMovilRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}${Platform.pathSeparator}pubspec.yaml').existsSync() &&
      Directory('${cwd.path}${Platform.pathSeparator}lib').existsSync()) {
    return cwd;
  }
  final nested = Directory('${cwd.path}${Platform.pathSeparator}app_movil');
  if (nested.existsSync() &&
      File('${nested.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
    return nested;
  }
  throw StateError('No se pudo localizar la raíz app_movil desde ${cwd.path}');
}

int _lineCount(Directory root, String relPath) {
  final sep = Platform.pathSeparator;
  final file = File('${root.path}$sep${relPath.replaceAll('/', sep)}');
  expect(file.existsSync(), isTrue, reason: 'Falta archivo $relPath');
  return file.readAsLinesSync().length;
}

class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final int? _businessId;

  _MockAuthProvider({int? businessId = 1}) : _businessId = businessId;

  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante 9B-2',
    phone: '999888777',
    isActive: true,
  );

  @override
  UserModel? get user => _user;

  @override
  bool get isAuthenticated => true;

  @override
  bool get hasActiveContext => _businessId != null;

  @override
  int? get activeBusinessId => _businessId;

  @override
  int? get activeUserId => 1;

  @override
  String get businessName => 'Librería Central 9B-2';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockLicenseProvider extends ChangeNotifier implements LicenseProvider {
  final int _scans;
  final bool _byok;

  _MockLicenseProvider({int scans = 69, bool byok = false})
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSmartQuotationProvider extends ChangeNotifier
    implements SmartQuotationProvider {
  @override
  String get errorMessage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier
    implements InventoryProvider {
  @override
  List<Brand> get brands => [
        Brand(id: 1, nombre: 'Stanford'),
        Brand(id: 2, nombre: 'Faber-Castell'),
      ];

  @override
  List<Category> get categories => [
        Category(id: 1, nombre: 'Cuadernos y Block'),
        Category(id: 2, nombre: 'Escritura Escolar'),
      ];

  @override
  String getBrandName(int? id) => 'Stanford';

  @override
  String getCategoryName(int? id) => 'Cuadernos y Block';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithTextScaler(Widget home) {
  return MaterialApp(
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(
        textScaler: const TextScaler.linear(1.3),
      ),
      child: child!,
    ),
    home: home,
  );
}

StagingProductGroup _buildMatchedLowConfidenceGroup() {
  final variant = StagingVariant(
    uuidTemporal: 'var-matched-1',
    nombreEspecifico: 'Docena Escolar Premium',
    umpCompra: 'Caja',
    cantidadUmpComprada: 2.0,
    precioUmpProveedor: 120.0,
    totalPagoLote: 240.0,
    unidadesPorLote: 12,
    unidadVenta: 'Docena',
    unidadesPorVenta: 12,
    costoUnitarioSugerido: 120.0,
    factorGananciaVentaSugerido: 1.35,
    precioVentaSugerido: 162.0,
    matchPresentacion: MatchResult(
      estado: 'MATCH_EXACTO',
      confianza: 42,
      datos: MatchData(
        id: 10,
        nombre: 'Docena Escolar',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        stockActual: 8,
        precioVentaFinal: 160.0,
        costoUnitarioCalculado: 118.0,
        availablePresentations: const [
          {
            'id': 10,
            'nombre_especifico': 'Docena Escolar',
            'unidad': 'Docena',
            'factor_conversion': 12,
            'stock_actual': 8,
            'precio_venta': 160.0,
            'precio_costo': 118.0,
          },
        ],
      ),
    ),
  );

  return StagingProductGroup(
    uuidTemporal: 'grp-matched-low',
    nombrePadre: 'Cuaderno A4 Rayado Tapa Dura 100H',
    nombreOriginalFactura: 'CUAD A4 RAY 100H STANFORD X12',
    marcaTexto: 'DISTRIBUIDORA CORPORATIVA DEL NORTE S.A.C.',
    matchProducto: MatchResult(
      estado: 'MATCH_SIMILAR',
      confianza: 42,
      datos: MatchData(
        id: 55,
        nombre: 'Cuaderno A4 Rayado Stanford',
        marcaNombre: 'DISTRIBUIDORA CORPORATIVA DEL NORTE S.A.C.',
        categoriaNombre: 'Útiles Escolares y Oficina',
        stockActual: 24,
      ),
    ),
    matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
    variantes: [variant],
    modoStock: 'COMPARTIDO',
    stockCompartido: 24,
    costoBase: 10.0,
    isMatchVerified: false,
  );
}

StagingProductGroup _buildNewGroupWithAdvisor({
  required String uuid,
  required String modoStock,
  required int poolUnits,
}) {
  final variant = StagingVariant(
    uuidTemporal: '$uuid-var',
    nombreEspecifico: 'Paquete x12 Unidades',
    umpCompra: 'Caja',
    cantidadUmpComprada: 1.0,
    precioUmpProveedor: 84.0,
    totalPagoLote: 84.0,
    unidadesPorLote: poolUnits,
    unidadVenta: 'Paquete',
    unidadesPorVenta: 12,
    costoUnitarioSugerido: poolUnits > 0 ? (84.0 / poolUnits) * 12 : 84.0,
    factorGananciaVentaSugerido: 1.30,
    precioVentaSugerido: 110.0,
    matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
  )..usaStockCompartido = true;

  return StagingProductGroup(
    uuidTemporal: uuid,
    nombrePadre: 'Folder Manila A4 Reforzado Color Pastel',
    nombreOriginalFactura: 'FOLDER MANILA A4 PASTEL X$poolUnits',
    marcaTexto: 'Stanford',
    matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
    matchMarca: MatchResult(
      estado: 'MATCH_MANUAL',
      confianza: 100,
      datos: MatchData(id: 1, nombre: 'Stanford'),
    ),
    categoriaSugeridaId: 1,
    variantes: [variant],
    modoStock: modoStock,
    stockCompartido: poolUnits,
    costoBase: poolUnits > 0 ? 84.0 / poolUnits : 1.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Plan 25 Fase 9B — Censo Completo (9B-1 + 9B-2) y Paridad de Símbolos', () {
    test('Cumple topes estrictos en 9B-1 (<600/<400/<650) y 9B-2 (<550/<600)', () {
      final root = _resolveAppMovilRoot();

      // Topes 9B-1
      expect(
        _lineCount(
          root,
          'lib/features/scanner/screens/invoice_detail_screen.dart',
        ),
        lessThan(600),
      );
      expect(
        _lineCount(
          root,
          'lib/features/scanner/widgets/staging/variant_editor_row.dart',
        ),
        lessThan(600),
      );
      expect(
        _lineCount(
          root,
          'lib/features/scanner/providers/scanner_provider.dart',
        ),
        lessThan(400),
      );
      const subModules9b1 = [
        'lib/features/scanner/screens/invoice_detail/invoice_detail_modals_and_downloads.dart',
        'lib/features/scanner/screens/invoice_detail/invoice_detail_photo_and_header.dart',
        'lib/features/scanner/screens/invoice_detail/invoice_detail_audit_section.dart',
        'lib/features/scanner/screens/invoice_detail/invoice_detail_audit_cards.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_inputs_and_tags.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_math_and_modals.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_stock_panels.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_cards_and_mixto.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_form_body.dart',
        'lib/features/scanner/widgets/staging/variant_editor/variant_editor_new_purchase_section.dart',
        'lib/features/scanner/providers/scanner_provider_queue_and_ai.dart',
        'lib/features/scanner/providers/scanner_provider_matching.dart',
        'lib/features/scanner/providers/scanner_provider_leftover_and_stock.dart',
        'lib/features/scanner/providers/scanner_provider_staging.dart',
      ];
      for (final rel in subModules9b1) {
        expect(_lineCount(root, rel), lessThan(650), reason: rel);
      }

      // Topes 9B-2 (<550 coordinadores, <600 sub-módulos)
      expect(
        _lineCount(root, 'lib/features/scanner/screens/scan_screen.dart'),
        lessThan(550),
      );
      expect(
        _lineCount(
          root,
          'lib/features/scanner/widgets/staging/staging_product_group_card.dart',
        ),
        lessThan(550),
      );
      const subModules9b2 = [
        'lib/features/scanner/screens/scan/scan_actions_and_modals.dart',
        'lib/features/scanner/screens/scan/scan_quotation_and_error_panels.dart',
        'lib/features/scanner/screens/scan/scan_invoice_panel.dart',
        'lib/features/scanner/widgets/staging/product_group/staging_group_header_and_modals.dart',
        'lib/features/scanner/widgets/staging/product_group/staging_group_parent_details.dart',
        'lib/features/scanner/widgets/staging/product_group/staging_group_stock_strategy.dart',
      ];
      for (final rel in subModules9b2) {
        expect(_lineCount(root, rel), lessThan(600), reason: rel);
      }

      // Paridad de importación directa
      expect(ScanScreen, isNotNull);
      expect(ScanMode.quotation, isNotNull);
      expect(ScanMode.invoice, isNotNull);
      expect(StagingProductGroupCard, isNotNull);
      expect(InvoiceDetailScreen, isNotNull);
      expect(VariantEditorRow, isNotNull);
      expect(ScannerProvider, isNotNull);
    });
  });

  group('Plan 25 Fase 9B-2 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'ScanScreen (quotation/invoice/BYOK/guest) y StagingProductGroupCard en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            capturedMessages.add(
              msg.toLowerCase().contains('overflowed')
                  ? '[$currentStage] ${details.toString()}'
                  : '[$currentStage] $msg',
            );
          };

          try {
            // 1. ScanScreen modo Quotation (invitado con banner exploración)
            currentStage = 'ScanScreen Quotation Guest';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(businessId: null),
                  ),
                  ChangeNotifierProvider<ScannerProvider>(
                    create: (_) => ScannerProvider(),
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: _MockSmartQuotationProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: _MockLicenseProvider(scans: 69, byok: false),
                  ),
                ],
                child: _wrapWithTextScaler(
                  const ScanScreen(
                    mode: ScanMode.quotation,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Digitaliza tu Lista'), findsOneWidget);
            expect(find.text('Compras / Pedido'), findsOneWidget);

            // 2. ScanScreen modo Invoice (autenticado, cuota oficial + luego BYOK)
            currentStage = 'ScanScreen Invoice OfficialQuota';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(businessId: 1),
                  ),
                  ChangeNotifierProvider<ScannerProvider>(
                    create: (_) => ScannerProvider(),
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: _MockSmartQuotationProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: _MockLicenseProvider(scans: 69, byok: false),
                  ),
                ],
                child: _wrapWithTextScaler(
                  const ScanScreen(
                    mode: ScanMode.invoice,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('69 escaneos IA disponibles'), findsOneWidget);
            expect(
              find.text('¿Qué procesa la IA automáticamente?'),
              findsOneWidget,
            );

            currentStage = 'ScanScreen Invoice BYOK Guest';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(businessId: null),
                  ),
                  ChangeNotifierProvider<ScannerProvider>(
                    create: (_) => ScannerProvider(),
                  ),
                  ChangeNotifierProvider<SmartQuotationProvider>.value(
                    value: _MockSmartQuotationProvider(),
                  ),
                  ChangeNotifierProvider<LicenseProvider>.value(
                    value: _MockLicenseProvider(scans: 0, byok: true),
                  ),
                ],
                child: _wrapWithTextScaler(
                  const ScanScreen(
                    mode: ScanMode.invoice,
                    autoTriggerTour: false,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('IA Ilimitada (Clave Propia)'), findsOneWidget);

            // 3. StagingProductGroupCard: Matched baja confianza + Nuevo Mixto déficit + Compartido sobrantes
            currentStage = 'StagingProductGroupCard MultiState';
            final scannerProv = ScannerProvider();
            final matchedLow = _buildMatchedLowConfidenceGroup();
            final deficitGroup = _buildNewGroupWithAdvisor(
              uuid: 'grp-deficit',
              modoStock: 'MIXTO',
              poolUnits: 7,
            );
            final leftoverGroup = _buildNewGroupWithAdvisor(
              uuid: 'grp-leftover',
              modoStock: 'COMPARTIDO',
              poolUnits: 14,
            );

            scannerProv.setStagingDataForTesting(
              StagingResponse(
                proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
                proveedorTexto: 'Distribuidora Central',
                productosAgrupados: [matchedLow, deficitGroup, leftoverGroup],
              ),
            );

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<ScannerProvider>.value(
                    value: scannerProv,
                  ),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _MockInventoryProvider(),
                  ),
                ],
                child: _wrapWithTextScaler(
                  Scaffold(
                    body: ListView(
                      children: [
                        StagingProductGroupCard(
                          groupIndex: 0,
                          provider: scannerProv,
                          isDark: false,
                        ),
                        StagingProductGroupCard(
                          groupIndex: 1,
                          provider: scannerProv,
                          isDark: true,
                        ),
                        StagingProductGroupCard(
                          groupIndex: 2,
                          provider: scannerProv,
                          isDark: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('✓ Sí es el mismo'), findsOneWidget);
            expect(
              find.text('Añadir otra presentación (Fraccionamiento)'),
              findsWidgets,
            );

            // Desplazar hacia tarjetas 2 y 3 para validar renderizado de Asesor Rojo y Ámbar
            final advisorCritical = find.textContaining('para vender sueltas');
            await tester.dragUntilVisible(
              advisorCritical,
              find.byType(ListView).first,
              const Offset(0, -250),
            );
            await tester.pumpAndSettle();
            expect(advisorCritical, findsOneWidget);

            final advisorRecommended = find.textContaining('(Recomendado)');
            await tester.dragUntilVisible(
              advisorRecommended,
              find.byType(ListView).first,
              const Offset(0, -250),
            );
            await tester.pumpAndSettle();
            expect(advisorRecommended, findsOneWidget);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();

            final overflowErrors = capturedMessages
                .where((m) => m.toLowerCase().contains('overflowed'))
                .toList();
            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow detectado en ${size.width}x${size.height} @ 1.3x:\n${overflowErrors.join('\n')}',
            );
            expect(tester.takeException(), isNull);
          } finally {
            FlutterError.onError = prevOnError;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  });
}
