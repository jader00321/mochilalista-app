import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/models/provider_model.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/invoice_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante Prueba',
    phone: '999888777',
    isActive: true,
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
  String get businessName => 'Librería Central';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInvoiceProvider extends ChangeNotifier implements InvoiceProvider {
  InvoiceModel? invoiceToReturn;

  @override
  Future<InvoiceModel?> getInvoiceDetail(int id) async => invoiceToReturn;

  @override
  Future<List<Map<String, dynamic>>> getLinkedPresentations(int id) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  String getProviderName(int? id) =>
      'DISTRIBUIDORA Y LIBRERÍA CORPORATIVA DEL NORTE PERÚ S.A.C.';

  @override
  List<ProviderModel> get providers => [
        ProviderModel(
          id: 1,
          idNegocio: 1,
          nombreEmpresa: 'DISTRIBUIDORA Y LIBRERÍA CORPORATIVA DEL NORTE',
          ruc: '20543219876',
        ),
      ];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Plan 25 Fase 9B-1 — Censo, Paridad de Símbolos y ScannerProvider', () {
    test('Cumple topes estrictos de líneas (<600 / <400 / <650) y expone símbolos públicos', () {
      final root = _resolveAppMovilRoot();

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

      const subModules = [
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
      for (final rel in subModules) {
        expect(_lineCount(root, rel), lessThan(650), reason: rel);
      }

      // Paridad de símbolos públicos desde rutas originales
      expect(InvoiceDetailScreen, isNotNull);
      expect(VariantEditorRow, isNotNull);
      expect(VariantEditorRowState, isNotNull);
      expect(MiniInput, isNotNull);
      expect(ResumenTag, isNotNull);
      expect(ScannerProvider, isNotNull);
      expect(ScannerState, isNotNull);
    });

    test('ScannerProvider actúa como instancia única ChangeNotifier en flujo de staging', () {
      final provider = ScannerProvider();
      expect(provider, isA<ChangeNotifier>());
      expect(provider.isLoading, isFalse);
      expect(provider.countNew, 0);
      expect(provider.countLinked, 0);
      expect(provider.totalActiveVariants, 0);
      expect(provider.hasUnresolvedStock, isFalse);

      int notifications = 0;
      provider.addListener(() => notifications++);

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
          proveedorTexto: 'Editorial Norte',
          productosAgrupados: [],
        ),
      );
      provider.updateStagingProvider(
        nombre: 'Distribuidora Andina',
        ruc: '20123456789',
        fecha: '2026-11-26',
      );
      expect(provider.stagingData!.proveedorTexto, 'Distribuidora Andina');

      provider.addNewProductGroup();
      expect(provider.stagingData!.productosAgrupados.length, 1);
      final grp = provider.stagingData!.productosAgrupados.first;
      expect(provider.totalActiveVariants, 1);
      expect(provider.countNew, 1);

      provider.addNewVariantToGroup(grp.uuidTemporal);
      expect(grp.variantes.length, 2);
      provider.setGroupStockStrategy(grp.uuidTemporal, 'COMPARTIDO');
      expect(grp.modoStock, 'COMPARTIDO');
      expect(grp.variantes.every((v) => v.usaStockCompartido), isTrue);

      provider.saveProgress();
      expect(provider.hasSavedProgress, isTrue);
      expect(notifications, greaterThanOrEqualTo(5));

      provider.clearData();
      expect(provider.stagingData, isNull);
      expect(provider.hasSavedProgress, isFalse);
    });
  });

  group('Plan 25 Fase 9B-1 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'InvoiceDetailScreen y VariantEditorRow en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
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
            // 1. InvoiceDetailScreen con ítems IA, Toggle JSON y Modales
            currentStage = 'InvoiceDetailScreen Rendered';
            final mockInv = _MockInvoiceProvider()
              ..invoiceToReturn = InvoiceModel(
                id: 19,
                numeroSecuencial: 19,
                negocioId: 1,
                imagenUrl: 'sample_path.jpg',
                estado: 'completado',
                fechaCarga: DateTime(2026, 11, 26, 10, 30),
                proveedorId: 1,
                montoTotalFactura: 1435.40,
                fechaEmision: DateTime(2026, 11, 25),
                cantidadItemsExtraidos: 2,
                datosCrudosIaJson: {
                  'items': [
                    {
                      'descripcion_detectada':
                          'CUADERNO A4 RAYADO ESPECIAL TAPA DURA 100 HOJAS',
                      'producto_padre_estimado': 'Cuaderno A4 Especial',
                      'variante_detectada': 'Rayado 100H',
                      'marca_detectada': 'Stanford',
                      'codigo_detectado': '7750011223344',
                      'unidad_venta': 'Unidad',
                      'ump_compra': 'Docena',
                      'cantidad_ump_comprada': 2,
                      'unidades_por_lote': 12,
                      'precio_ump_proveedor': 72.0,
                      'total_pago_lote': 144.0,
                    },
                  ],
                },
              );

            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                  ChangeNotifierProvider<InvoiceProvider>.value(value: mockInv),
                  ChangeNotifierProvider<InventoryProvider>.value(
                    value: _MockInventoryProvider(),
                  ),
                ],
                child: _wrapWithTextScaler(
                  const InvoiceDetailScreen(invoiceId: 19),
                ),
              ),
            );
            await tester.pump();
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 150));
            expect(find.text('Factura #19'), findsOneWidget);

            // Desplazar zona inferior para verificar tarjetas IA y Toggle JSON
            final detailList = find.byType(ListView).first;
            currentStage = 'InvoiceDetailScreen JSON Toggle';
            final jsonToggle = find.text('Código JSON');
            await tester.dragUntilVisible(
              jsonToggle,
              detailList,
              const Offset(0, -180),
            );
            await tester.pump(const Duration(milliseconds: 250));
            await tester.tap(jsonToggle);
            await tester.pump(const Duration(milliseconds: 250));
            await tester.tap(find.text('Vista Detallada'));
            await tester.pump(const Duration(milliseconds: 250));

            await tester.drag(detailList, const Offset(0, -260));
            await tester.pump(const Duration(milliseconds: 250));

            // 2. VariantEditorRow (Existente MATCH + Sobrante + Nueva MIXTO/COMPARTIDO)
            currentStage = 'VariantEditorRow Existing Match';
            final scannerProv = ScannerProvider();
            final matchedVariant = StagingVariant(
              uuidTemporal: 'var-match-1',
              nombreEspecifico: 'Docena Escolar Premium',
              umpCompra: 'Caja',
              cantidadUmpComprada: 1.0,
              precioUmpProveedor: 120.0,
              totalPagoLote: 120.0,
              unidadesPorLote: 14,
              unidadVenta: 'Docena',
              unidadesPorVenta: 12,
              costoUnitarioSugerido: 102.85,
              factorGananciaVentaSugerido: 1.35,
              precioVentaSugerido: 138.85,
              matchPresentacion: MatchResult(
                estado: 'MATCH_EXACTO',
                confianza: 100,
                datos: MatchData(
                  id: 10,
                  nombre: 'Docena Escolar Premium',
                  unidadVenta: 'Docena',
                  unidadesPorVenta: 12,
                  stockActual: 12,
                  precioVentaFinal: 138.0,
                  costoUnitarioCalculado: 100.0,
                  availablePresentations: const [
                    {
                      'id': 10,
                      'nombre_especifico': 'Docena Escolar Premium',
                      'unidad': 'Docena',
                      'factor_conversion': 12,
                      'stock_actual': 12,
                      'precio_venta': 138.0,
                      'precio_oferta': 130.0,
                      'precio_costo': 100.0,
                    },
                  ],
                ),
              ),
            );

            final sharedVariant = StagingVariant(
              uuidTemporal: 'var-new-shared',
              nombreEspecifico: 'Unidad Compartida',
              umpCompra: 'Ciento',
              cantidadUmpComprada: 1.0,
              precioUmpProveedor: 85.0,
              totalPagoLote: 85.0,
              unidadesPorLote: 100,
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
              costoUnitarioSugerido: 0.85,
              factorGananciaVentaSugerido: 1.40,
              precioVentaSugerido: 1.20,
              matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
            )..usaStockCompartido = true;

            final mixedGroup = StagingProductGroup(
              uuidTemporal: 'grp-mixto',
              nombrePadre: 'Cuaderno Universitario Espiral',
              marcaTexto: 'Stanford',
              matchProducto: MatchResult(
                estado: 'MATCH_EXACTO',
                confianza: 100,
                datos: MatchData(
                  id: 5,
                  nombre: 'Cuaderno Universitario Espiral',
                  availablePresentations: matchedVariant
                      .matchPresentacion.datos!.availablePresentations,
                ),
              ),
              matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
              variantes: [matchedVariant, sharedVariant],
              modoStock: 'MIXTO',
              stockCompartido: 100,
              costoBase: 0.85,
            );

            scannerProv.setStagingDataForTesting(
              StagingResponse(
                proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
                proveedorTexto: 'Distribuidora',
                productosAgrupados: [mixedGroup],
              ),
            );

            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        VariantEditorRow(
                          group: mixedGroup,
                          variant: matchedVariant,
                          provider: scannerProv,
                          isDark: false,
                          onDelete: () {},
                        ),
                        const SizedBox(height: 12),
                        VariantEditorRow(
                          group: mixedGroup,
                          variant: sharedVariant,
                          provider: scannerProv,
                          isDark: true,
                          onDelete: () {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final cupoFinder = find.byKey(const ValueKey('cupo_var-new-shared_100'));
            await tester.ensureVisible(cupoFinder);
            expect(cupoFinder, findsOneWidget);

            // Expandir detalles avanzados de variante nueva en viewport estrecho
            currentStage = 'VariantEditorRow New Shared Expanded';
            final advToggle = find.textContaining('Costo Unit.:');
            if (advToggle.evaluate().isNotEmpty) {
              await tester.ensureVisible(advToggle.first);
              await tester.tap(advToggle.first);
              await tester.pumpAndSettle();
            }

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
