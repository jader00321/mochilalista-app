import 'dart:convert';
import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/services/predictive_service.dart';
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
  final UserModel _user = UserModel(
    id: 1,
    fullName: 'Comerciante Prueba',
    phone: '999888777',
    isActive: true,
  );

  final BusinessModel _business = BusinessModel(
    id: 1,
    commercialName: 'Librería Central',
    address: 'Jr. Comercio 456',
    moneda: 'PEN',
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
  String get userName => 'Comerciante Prueba';

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

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

PredictiveData _buildSamplePredictiveData() {
  final baseDate = DateTime(2026, 11, 1);
  final points = List<Map<String, dynamic>>.generate(14, (index) {
    final dt = baseDate.add(Duration(days: index));
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return {
      'date': '${dt.year}-$mm-$dd',
      'inventoryValue': 4200.0 + (index * 150.0),
      'netProfit': 800.0 + (index * 110.0),
      'dailySales': 320.0 + (index * 25.0),
      'dailyProfit': 95.0 + (index * 8.0),
    };
  });

  return PredictiveData(
    historicalPoints: points,
    predictedNext30DaysSales: 12450.0,
    salesVelocity: 18.4,
    currentInventoryValue: 6150.0,
    explanationText:
        'Tus ventas crecieron un 18.4% respecto a la quincena previa. Mantén stock de alta rotación.',
    actionText:
        'Revisa 3 productos críticos en Abastecimiento Inteligente antes de campaña.',
    totalSnapshots: 14,
    dailyAverageSales: 415.0,
    trendSlopeM: 12.5,
    interceptB: 300.0,
    previous15Sales: 4200.0,
    current15Sales: 4972.8,
    confidenceLevel: 'Media',
    conservativeEstimate: 9960.0,
    expectedEstimate: 12450.0,
    optimisticEstimate: 14940.0,
    historicalProfitMargin: 0.32,
    isInitialPhase: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDb;

  setUpAll(() async {
    await initializeDateFormatting('es', null);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseConnectionFactory.isTestMode = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    testDb = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 36,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await LocalDatabase.createDBForTesting(db);
        },
      ),
    );
    LocalDatabase.setCustomDatabase(testDb);
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    if (testDb.isOpen) {
      await testDb.close();
    }
  });

  group('Plan 25 Fase 9A-1 — Censo de líneas y paridad de símbolos/keys', () {
    test('Coordinadores < 600 L y todos los sub-módulos 9A-1 < 650 L', () {
      final root = _resolveAppMovilRoot();

      const coordinators = [
        'lib/features/analytics/screens/commercial_radar_screen.dart',
        'lib/features/analytics/screens/predictive_analytics_screen.dart',
        'lib/features/analytics/screens/smart_restock_screen.dart',
      ];
      for (final coord in coordinators) {
        expect(_lineCount(root, coord), lessThan(600), reason: coord);
      }

      const subModules = [
        // commercial_radar/
        'lib/features/analytics/screens/commercial_radar/location_picker_sheet.dart',
        'lib/features/analytics/screens/commercial_radar/location_picker_district_step.dart',
        'lib/features/analytics/screens/commercial_radar/radar_pulse_and_actions.dart',
        'lib/features/analytics/screens/commercial_radar/radar_header_and_filters.dart',
        'lib/features/analytics/screens/commercial_radar/radar_news_card.dart',
        // predictive_analytics/
        'lib/features/analytics/screens/predictive_analytics/predictive_summary_and_diagnosis_cards.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_diagnosis_and_confidence_cards.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_simulator_section.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_simulator_result_panel.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_patrimony_chart_section.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_patrimony_detail_panel.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_explain_modals.dart',
        // smart_restock/
        'lib/features/analytics/screens/smart_restock/smart_restock_item.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_data_and_export.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_header_and_kpis.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_product_card.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_card_controls.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_modals_and_summary.dart',
      ];

      for (final mod in subModules) {
        expect(_lineCount(root, mod), lessThan(650), reason: mod);
      }

      final sep = Platform.pathSeparator;
      for (final dirRel in const [
        'lib/features/analytics/screens/commercial_radar',
        'lib/features/analytics/screens/predictive_analytics',
        'lib/features/analytics/screens/smart_restock',
      ]) {
        final dir = Directory('${root.path}$sep${dirRel.replaceAll('/', sep)}');
        expect(dir.existsSync(), isTrue, reason: dirRel);
        for (final f in dir.listSync().whereType<File>()) {
          if (f.path.endsWith('.dart')) {
            expect(
              f.readAsLinesSync().length,
              lessThan(650),
              reason: f.path,
            );
          }
        }
      }

      // Paridad exacta de exports y símbolos públicos en rutas originales
      expect(CommercialRadarScreen, isNotNull);
      expect(LocationPickerSheet, isNotNull);
      expect(RadarTab.values, containsAll([RadarTab.noticiasDelDia, RadarTab.guardadas]));
      expect(PredictiveAnalyticsScreen, isNotNull);
      expect(SmartRestockScreen, isNotNull);

      final sampleItem = SmartRestockItem(
        presentationId: 1,
        productId: 1,
        productName: 'Cuaderno A4',
        brandName: 'Stanford',
        presentationName: 'Unidad',
        currentStock: 2,
        cost: 4.5,
        velocityPerDay: 1.2,
        velocityDisplay: '1.2/d',
        safetyStock: 3,
        rop: 6,
        suggestedQty: 8,
        orderQty: 8,
        daysToStockout: 1.6,
        stockoutDate: '2026-11-28',
        status: 'critico',
        statusColor: Colors.redAccent,
        statusText: 'Stock Crítico',
        hasZeroCost: false,
      );
      expect(sampleItem.productName, 'Cuaderno A4');
      expect(sampleItem.modoStock, 'INDEPENDIENTE');
    });

    testWidgets(
      'LocationPickerSheet preserva ValueKeys btn_apply_district y btn_use_province',
      (tester) async {
        RadarLocation? picked;
        final deptPiura = PeruUbigeoCatalog.findDepartment('Piura')!;
        final provHuancabamba = deptPiura.provinces.firstWhere(
          (p) => p.name == 'Huancabamba',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocationPickerSheet(
                isDark: false,
                sheetBg: Colors.white,
                initialStagedDepartment: deptPiura,
                initialStagedProvince: provHuancabamba,
                currentLocation: const RadarLocation(
                  department: 'Piura',
                  province: 'Huancabamba',
                  district: 'Sondorillo',
                  corridor: 'Eje Andino Norte',
                ),
                onLocationSelected: (loc) => picked = loc,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final applyBtn = find.byKey(const ValueKey('btn_apply_district'));
        final provBtn = find.byKey(const ValueKey('btn_use_province'));
        expect(applyBtn, findsOneWidget);
        expect(provBtn, findsOneWidget);

        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pump();
        expect(picked?.district, 'Sondorillo');

        await tester.ensureVisible(provBtn);
        await tester.tap(provBtn);
        await tester.pump();
        expect(picked?.district, isNull);
        expect(picked?.province, 'Huancabamba');
      },
    );
  });

  group('Plan 25 Fase 9A-1 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'CommercialRadarScreen, LocationPickerSheet, PredictiveAnalyticsScreen y SmartRestockScreen en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final capturedMessages = <String>[];
          String currentStage = 'init';
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            if (msg.toLowerCase().contains('overflowed')) {
              capturedMessages.add('[$currentStage] ${details.toString()}');
            } else {
              capturedMessages.add('[$currentStage] $msg');
            }
          };

          try {
            // Semilla SQLite para SmartRestockScreen (pool compartido + agotado sin costo + mixto)
            await tester.runAsync(() async {
              await testDb.insert('negocios', {
                'id': 1,
                'nombre_comercial': 'Librería Central',
                'moneda': 'S/ (Soles)',
              });
              await testDb.insert('marcas', {
                'id': 1,
                'negocio_id': 1,
                'nombre': 'Stanford',
              });

              // Producto 1: Pool compartido con quiebre de formato
              final prodShared = await testDb.insert('productos', {
                'negocio_id': 1,
                'marca_id': 1,
                'nombre': 'Cuaderno A4 Rayado Especial Escolar',
                'modo_stock': 'COMPARTIDO',
                'stock_compartido': 8,
                'costo_base': 4.20,
              });
              final presUnit = await testDb.insert('presentaciones_producto', {
                'producto_id': prodShared,
                'nombre_especifico': 'Unidad',
                'unidad_venta': 'Unidad',
                'unidades_por_venta': 1,
                'costo_unitario_calculado': 4.20,
                'precio_venta_final': 7.50,
                'stock_actual': 8,
                'stock_alerta': 10,
                'usa_stock_compartido': 1,
                'activo': 1,
              });
              await testDb.insert('presentaciones_producto', {
                'producto_id': prodShared,
                'nombre_especifico': 'Docena',
                'unidad_venta': 'Docena',
                'unidades_por_venta': 12,
                'costo_unitario_calculado': 50.40,
                'precio_venta_final': 84.00,
                'stock_actual': 0,
                'stock_alerta': 2,
                'usa_stock_compartido': 1,
                'activo': 1,
              });

              // Producto 2: Independiente agotado y sin costo
              await testDb.insert('productos', {
                'negocio_id': 1,
                'marca_id': 1,
                'nombre': 'Plumón Pizarra Recargable Azul',
                'modo_stock': 'INDEPENDIENTE',
              });
              await testDb.insert('presentaciones_producto', {
                'producto_id': 2,
                'nombre_especifico': 'Caja x 12',
                'unidad_venta': 'Caja',
                'unidades_por_venta': 12,
                'costo_unitario_calculado': 0.0,
                'precio_venta_final': 28.00,
                'stock_actual': 0,
                'stock_alerta': 5,
                'usa_stock_compartido': 0,
                'activo': 1,
              });

              // Producto 3: Estrategia MIXTA con ventas en stock_ledger
              await testDb.insert('productos', {
                'negocio_id': 1,
                'marca_id': 1,
                'nombre': 'Borrador Blanco Técnico',
                'modo_stock': 'MIXTO',
              });
              final presMixto = await testDb.insert('presentaciones_producto', {
                'producto_id': 3,
                'nombre_especifico': 'Display x 20',
                'unidad_venta': 'Display',
                'unidades_por_venta': 20,
                'costo_unitario_calculado': 14.50,
                'precio_venta_final': 22.00,
                'stock_actual': 4,
                'stock_alerta': 8,
                'usa_stock_compartido': 0,
                'activo': 1,
              });

              final nowIso = DateTime.now()
                  .subtract(const Duration(days: 2))
                  .toIso8601String();
              await testDb.insert('stock_ledger', {
                'presentation_id': presUnit,
                'negocio_id': 1,
                'tipo_transaccion': 'VENTA',
                'cantidad': -12,
                'fecha_registro': nowIso,
              });
              await testDb.insert('stock_ledger', {
                'presentation_id': presMixto,
                'negocio_id': 1,
                'tipo_transaccion': 'VENTA',
                'cantidad': -6,
                'fecha_registro': nowIso,
              });
            });

            // 1A. CommercialRadarScreen con noticias + guardadas
            final sampleNews = CommercialNewsItem(
              id: 'news_9a1_1',
              title: 'Actualización de fletes en corredor Panamericana Norte',
              summary:
                  'Transporte interprovincial reporta ajustes moderados en tarifas de carga pesada.',
              impactAnalysis:
                  'Considera anticipar reposición de cuadernos y útiles de volumen.',
              actionableAdvice:
                  'Revisa stock crítico y consolida pedidos esta semana.',
              category: 'Proveedores y Abastecimiento',
              sourceName: 'Diario Oficial El Peruano Economía',
              sourceUrl: 'https://elperuano.pe',
              publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
              region: 'San Juan de Lurigancho, Lima (Lima)',
              isLive: true,
              scope: RadarNewsScope.local,
            );
            const longLoc = RadarLocation(
              department: 'Lima',
              province: 'Lima',
              district: 'San Juan de Lurigancho',
              corridor: 'Panamericana / Eje Central',
            );
            SharedPreferences.setMockInitialValues({
              CommercialRadarService.legacyMigratedPrefKey: true,
              CommercialRadarService.locationJsonPrefKey(99): jsonEncode(
                longLoc.toJson(),
              ),
              CommercialRadarService.regionPrefKey(99): longLoc.displayName,
              CommercialRadarService.savedNewsPrefKey(99): jsonEncode([
                sampleNews.toJson(),
              ]),
            });
            CommercialRadarService.mergeNewsItems([], [sampleNews]);

            currentStage = 'CommercialRadarScreen';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                const CommercialRadarScreen(
                  autoTriggerTour: false,
                  profileId: 99,
                ),
              ),
            );
            for (int i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 120));
            }
            expect(find.text('Radar Comercial IA'), findsOneWidget);

            // Cambiar a pestaña Guardadas (1) y verificar 0 overflow
            currentStage = 'CommercialRadarScreen Guardadas';
            final savedTab = find.text('Guardadas (1)');
            if (savedTab.evaluate().isNotEmpty) {
              await tester.tap(savedTab, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 250));
            }

            // 1B. LocationPickerSheet (Paso Provincia + Paso Distrito)
            currentStage = 'LocationPickerSheet Provincias';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: LocationPickerSheet(
                    key: ValueKey('picker_provinces_${size.width}'),
                    isDark: false,
                    sheetBg: Colors.white,
                    currentLocation: longLoc,
                    onLocationSelected: (_) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Enfoque Geográfico del Radar'), findsOneWidget);

            currentStage = 'LocationPickerSheet Distritos';
            final deptPiura = PeruUbigeoCatalog.findDepartment('Piura')!;
            final provHuancabamba = deptPiura.provinces.firstWhere(
              (p) => p.name == 'Huancabamba',
            );
            await tester.pumpWidget(
              _wrapWithTextScaler(
                Scaffold(
                  body: LocationPickerSheet(
                    key: ValueKey('picker_districts_${size.width}'),
                    isDark: true,
                    sheetBg: const Color(0xFF1E293B),
                    initialStagedDepartment: deptPiura,
                    initialStagedProvince: provHuancabamba,
                    currentLocation: const RadarLocation(
                      department: 'Piura',
                      province: 'Huancabamba',
                      district: 'Sondorillo',
                      corridor: 'Eje Andino Norte',
                    ),
                    onLocationSelected: (_) {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('btn_apply_district')), findsOneWidget);

            // 2. PredictiveAnalyticsScreen (simulador con descuento + pestaña Beneficio + modal)
            currentStage = 'PredictiveAnalyticsScreen';
            await tester.pumpWidget(
              _wrapWithTextScaler(
                PredictiveAnalyticsScreen(
                  initialData: _buildSamplePredictiveData(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Proyección a 30 Días'), findsOneWidget);

            final liqChip = find.text('Liquidación (+20% ventas, -5% dto.)');
            await tester.ensureVisible(liqChip);
            await tester.tap(liqChip);
            await tester.pumpAndSettle();
            expect(
              find.textContaining('Descuento Comercial: -5%'),
              findsOneWidget,
            );

            final beneficioTab = find.text('Beneficio');
            await tester.ensureVisible(beneficioTab);
            await tester.tap(beneficioTab);
            await tester.pumpAndSettle();

            currentStage = 'PredictiveAnalyticsScreen Explain Modal';
            final firstExplain = find.text('¿Cómo funciona?').first;
            await tester.ensureVisible(firstExplain);
            await tester.pumpAndSettle();
            await tester.tap(firstExplain);
            await tester.pumpAndSettle();
            expect(find.text('Entendido'), findsOneWidget);
            await tester.tap(find.text('Entendido'));
            await tester.pumpAndSettle();

            // 3. SmartRestockScreen (con 3 productos reales en BD)
            currentStage = 'SmartRestockScreen';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                ],
                child: _wrapWithTextScaler(const SmartRestockScreen()),
              ),
            );
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 250));
            });
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 250));

            expect(
              find.text('Motor Inteligente de Abastecimiento'),
              findsOneWidget,
            );
            expect(find.text('Exportar OC'), findsOneWidget);
            expect(find.text('Sin costo • Asignar'), findsOneWidget);

            final helpBtn = find.text('¿Cómo leer esta pantalla e interpretar ROP?');
            await tester.tap(helpBtn);
            await tester.pumpAndSettle();

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
