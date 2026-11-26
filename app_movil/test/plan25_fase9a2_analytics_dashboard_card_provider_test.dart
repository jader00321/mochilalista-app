import 'dart:io';

import 'package:app_movil/core/database/database_connection_factory.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/commercial_radar_card.dart';
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

AnalyticsData _buildRichAnalyticsData() {
  final now = DateTime.now();
  return AnalyticsData(
    totalSales: 4850.50,
    netProfit: 1640.25,
    estimatedMarginPercentage: 33.8,
    recoveredLiquidity: 320.0,
    topProducts: const [
      {
        'producto_id': 1,
        'nombre': 'Cuaderno A4 Rayado Especial Escolar',
        'marca_nombre': 'Stanford',
        'presentacion_id': 1,
        'presentacion_nombre': 'Unidad',
        'unidad_venta': 'Unidad',
        'unidades_por_venta': 1,
        'modo_stock': 'COMPARTIDO',
        'total_vendido': 120,
        'monto_vendido': 900.0,
      },
      {
        'producto_id': 2,
        'nombre': 'Plumón Pizarra Recargable Azul',
        'marca_nombre': 'Faber',
        'presentacion_id': 2,
        'presentacion_nombre': 'Caja x 12',
        'unidad_venta': 'Caja',
        'unidades_por_venta': 12,
        'modo_stock': 'INDEPENDIENTE',
        'total_vendido': 45,
        'monto_vendido': 1260.0,
      },
    ],
    lowStockProducts: const [
      {
        'presentacion_id': 1,
        'producto_id': 1,
        'nombre': 'Cuaderno A4 Rayado Especial',
        'marca_nombre': 'Stanford',
        'presentacion_nombre': 'Unidad',
        'stock_actual': 2,
        'stock_alerta': 10,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 2,
        'unidades_por_venta': 1,
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 2,
      },
    ],
    topClients: const [
      {
        'cliente_id': 1,
        'nombre_completo': 'Colegio Particular San Martín de Porres',
        'total_comprado': 1850.0,
        'num_compras': 6,
      },
    ],
    monthlySales: const [
      {'month': '09/2026', 'amount': 3100.0},
      {'month': '10/2026', 'amount': 3950.0},
      {'month': '11/2026', 'amount': 4850.5},
    ],
    dailySalesData: const [
      {'date': '2026-11-24', 'amount': 420.0},
      {'date': '2026-11-25', 'amount': 580.0},
      {'date': '2026-11-26', 'amount': 690.5},
    ],
    averageTicket: 125.0,
    nextMonthPrediction: 5400.0,
    totalTransactions: 38,
    salesGrowthRate: 22.8,
    topCategories: const [
      {'nombre': 'Útiles Escolares', 'total_vendido': 180, 'total_ingresos': 3200.0},
      {'nombre': 'Oficina y Archivo', 'total_vendido': 75, 'total_ingresos': 1650.5},
    ],
    salesByDayOfWeek: const [
      {'name': 'Lun', 'amount': 650.0},
      {'name': 'Mar', 'amount': 520.0},
      {'name': 'Mié', 'amount': 780.0},
      {'name': 'Jue', 'amount': 840.0},
      {'name': 'Vie', 'amount': 1120.0},
      {'name': 'Sáb', 'amount': 740.5},
      {'name': 'Dom', 'amount': 200.0},
    ],
    salesByOrigin: const [
      {'name': 'Caja Rápida', 'amount': 2850.0},
      {'name': 'Cotización', 'amount': 2000.5},
    ],
    salesByPaymentMethod: const [
      {'name': 'Efectivo', 'amount': 2400.0},
      {'name': 'Yape/Plin', 'amount': 1650.5},
      {'name': 'Transferencia', 'amount': 800.0},
    ],
    inventoryValue: 8420.0,
    inventoryTurnoverRatio: 1.85,
    immobilizedCapital: 480.0,
    deadStockCount: 1,
    deadStockList: const [
      {
        'id': 3,
        'producto_id': 3,
        'nombre_especifico': 'Pool Compartido',
        'producto_nombre': 'Archivador Oficio Lomo Ancho',
        'marca_nombre': 'Artesco',
        'stock_actual': 24,
        'costo_unitario_calculado': 20.0,
        'dias_estancado': 95,
      },
    ],
    insights: [
      BusinessInsight(
        'Tendencia al Alza',
        'Tus ventas crecieron un 22.8% respecto al periodo previo.',
        Icons.trending_up,
        InsightType.success,
        suggestedAction: 'Refuerza stock de cuadernos y útiles de campaña.',
        actionLabel: 'Ir a Reponer Stock',
        actionRoute: 'smart_restock',
      ),
    ],
    financialHealth: FinancialHealthSummary(
      balanceHeadline: 'Crecimiento Sostenido',
      balanceDescription: 'Tu margen de 33.8% supera el promedio del sector.',
      healthDiagnosis: 'Excelente margen de ganancia y rotación saludable.',
      healthLevel: 'excellent',
      marginContext: 'Rentabilidad firme sobre ingresos netos.',
    ),
    categoryInsight: 'Útiles Escolares lidera tanto en volumen como en ingresos.',
    effectiveCollectionRate: 94.5,
    averageMarginPerSale: 33.8,
    previousPeriodSales: 3950.0,
    periodStartDate: now.subtract(const Duration(days: 30)),
    periodEndDate: now,
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
    SharedPreferences.setMockInitialValues({
      CommercialRadarService.legacyMigratedPrefKey: true,
    });
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

  group('Plan 25 Fase 9A Completo (9A-1 + 9A-2) — Límites, Paridad y API', () {
    test('9A-2 respeta topes estrictos (<550 / <400 / <600 / <550) y 9A completo <650 L', () {
      final root = _resolveAppMovilRoot();

      // Coordinadores 9A-2 (< 550 L) y fachada Provider (< 400 L)
      expect(
        _lineCount(
          root,
          'lib/features/analytics/screens/analytics_dashboard_screen.dart',
        ),
        lessThan(550),
      );
      expect(
        _lineCount(
          root,
          'lib/features/analytics/widgets/dashboard/commercial_radar_card.dart',
        ),
        lessThan(550),
      );
      expect(
        _lineCount(
          root,
          'lib/features/analytics/providers/analytics_provider.dart',
        ),
        lessThan(400),
      );

      // Sub-módulos 9A-2 Dashboard y RadarCard (< 600 L)
      const screenAndCardSubModules = [
        'lib/features/analytics/screens/analytics_dashboard/analytics_dashboard_states_and_actions.dart',
        'lib/features/analytics/screens/analytics_dashboard/analytics_dashboard_sections_and_tabs.dart',
        'lib/features/analytics/widgets/dashboard/commercial_radar_card/radar_card_header_and_pickers.dart',
        'lib/features/analytics/widgets/dashboard/commercial_radar_card/radar_card_news_item.dart',
      ];
      for (final rel in screenAndCardSubModules) {
        expect(_lineCount(root, rel), lessThan(600), reason: rel);
      }

      // Sub-módulos Provider (< 550 L)
      const providerParts = [
        'lib/features/analytics/providers/analytics_provider_models.dart',
        'lib/features/analytics/providers/analytics_provider_queries.dart',
        'lib/features/analytics/providers/analytics_provider_inventory_snapshots.dart',
        'lib/features/analytics/providers/analytics_provider_calculations.dart',
      ];
      for (final rel in providerParts) {
        expect(_lineCount(root, rel), lessThan(550), reason: rel);
      }

      // Verificación completa Fase 9A (9A-1 + 9A-2): todos < 650 L
      const fase9aAllFiles = [
        'lib/features/analytics/screens/commercial_radar_screen.dart',
        'lib/features/analytics/screens/commercial_radar/location_picker_sheet.dart',
        'lib/features/analytics/screens/commercial_radar/location_picker_district_step.dart',
        'lib/features/analytics/screens/commercial_radar/radar_pulse_and_actions.dart',
        'lib/features/analytics/screens/commercial_radar/radar_header_and_filters.dart',
        'lib/features/analytics/screens/commercial_radar/radar_news_card.dart',
        'lib/features/analytics/screens/predictive_analytics_screen.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_summary_and_diagnosis_cards.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_diagnosis_and_confidence_cards.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_simulator_section.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_simulator_result_panel.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_patrimony_chart_section.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_patrimony_detail_panel.dart',
        'lib/features/analytics/screens/predictive_analytics/predictive_explain_modals.dart',
        'lib/features/analytics/screens/smart_restock_screen.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_item.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_data_and_export.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_header_and_kpis.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_product_card.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_card_controls.dart',
        'lib/features/analytics/screens/smart_restock/smart_restock_modals_and_summary.dart',
        'lib/features/analytics/screens/analytics_dashboard_screen.dart',
        ...screenAndCardSubModules,
        'lib/features/analytics/widgets/dashboard/commercial_radar_card.dart',
        'lib/features/analytics/providers/analytics_provider.dart',
        ...providerParts,
      ];
      expect(fase9aAllFiles.length, 32);
      for (final rel in fase9aAllFiles) {
        expect(_lineCount(root, rel), lessThan(650), reason: rel);
      }

      // Paridad de símbolos públicos desde rutas originales
      expect(AnalyticsDashboardScreen, isNotNull);
      expect(CommercialRadarCard, isNotNull);
      expect(AnalyticsProvider, isNotNull);
      expect(AnalyticsStep.values, containsAll([AnalyticsStep.idle, AnalyticsStep.done]));
      expect(InsightType.values, containsAll([InsightType.success, InsightType.warning]));
      expect(AnalyticsPeriod.values, containsAll([AnalyticsPeriod.today, AnalyticsPeriod.custom]));
    });

    test('AnalyticsProvider mantiene ChangeNotifier único, contexto y cálculo SQLite completo', () async {
      final prov = AnalyticsProvider();
      expect(prov, isA<ChangeNotifier>());
      expect(prov.currentStep, AnalyticsStep.idle);
      expect(prov.selectedPeriod, AnalyticsPeriod.sixMonths);
      expect(prov.deadStockThresholdDays, 30);

      int notifications = 0;
      prov.addListener(() => notifications++);

      // Guard sin negocioId no debe fallar
      await prov.runStaggeredAnalysis();
      expect(prov.currentStep, AnalyticsStep.idle);

      // Sembrar datos reales en SQLite para probar queries, cálculos y snapshots
      await testDb.insert('usuarios', {'id': 1, 'nombre_completo': 'Vendedor'});
      await testDb.insert('negocios', {
        'id': 1,
        'nombre_comercial': 'Librería Central',
        'id_dueno': 1,
      });
      await testDb.insert('categorias', {
        'id': 1,
        'negocio_id': 1,
        'nombre': 'Útiles Escolares',
        'activo': 1,
      });
      await testDb.insert('marcas', {
        'id': 1,
        'negocio_id': 1,
        'nombre': 'Stanford',
        'activo': 1,
      });
      await testDb.insert('clientes', {
        'id': 1,
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'nombre_completo': 'Colegio San Martín',
        'telefono': '999000111',
      });
      final prodId = await testDb.insert('productos', {
        'negocio_id': 1,
        'categoria_id': 1,
        'marca_id': 1,
        'nombre': 'Cuaderno A4',
        'modo_stock': 'INDEPENDIENTE',
        'costo_base': 4.5,
      });
      final presId = await testDb.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'costo_unitario_calculado': 4.5,
        'precio_venta_final': 8.0,
        'stock_actual': 3,
        'stock_alerta': 10,
        'usa_stock_compartido': 0,
        'activo': 1,
      });
      final ventaId = await testDb.insert('ventas', {
        'negocio_id': 1,
        'creado_por_usuario_id': 1,
        'cliente_id': 1,
        'origen_venta': 'pos_rapido',
        'is_archived': 0,
        'metodo_pago': 'Efectivo',
        'monto_total': 80.0,
        'monto_pagado': 80.0,
        'fecha_venta': DateTime.now().toIso8601String(),
      });
      await testDb.insert('venta_items', {
        'venta_id': ventaId,
        'presentation_id': presId,
        'product_id': prodId,
        'cantidad': 10,
        'precio_unitario': 8.0,
        'subtotal': 80.0,
        'nombre_producto': 'Cuaderno A4',
      });

      prov.updateContext(1);
      await prov.runStaggeredAnalysis();

      expect(prov.currentStep, AnalyticsStep.done);
      expect(prov.progress, 1.0);
      expect(prov.data, isNotNull);
      expect(prov.data!.totalSales, closeTo(80.0, 0.01));
      expect(prov.data!.netProfit, closeTo(35.0, 0.01));
      expect(prov.data!.inventoryValue, closeTo(13.5, 0.01));
      expect(prov.data!.lowStockProducts, isNotEmpty);
      expect(prov.data!.monthlySales, isNotEmpty);
      expect(prov.data!.dailySalesData, isNotEmpty);
      expect(notifications, greaterThanOrEqualTo(4));

      final snapshots = await testDb.query(
        'business_snapshots',
        where: 'negocio_id = ?',
        whereArgs: [1],
      );
      expect(snapshots, isNotEmpty);

      prov.setDataForTesting(_buildRichAnalyticsData());
      expect(prov.data!.totalSales, closeTo(4850.50, 0.01));

      prov.reset();
      expect(prov.currentStep, AnalyticsStep.idle);
      expect(prov.data, isNull);
    });
  });

  group('Plan 25 Fase 9A-2 — Paridad Visual 0px Overflow @ TextScaler 1.3x', () {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets(
        'AnalyticsDashboardScreen y CommercialRadarCard en ${size.width.toInt()}x${size.height.toInt()}dp @ 1.3x',
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
            // 1. AnalyticsDashboardScreen Idle (con rango personalizado AppDateFormatter.ddMM)
            currentStage = 'AnalyticsDashboardScreen Idle';
            final analyticsProvider = AnalyticsProvider();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                  ChangeNotifierProvider<AnalyticsProvider>.value(
                    value: analyticsProvider,
                  ),
                ],
                child: _wrapWithTextScaler(
                  const AnalyticsDashboardScreen(autoTriggerTour: false),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 150));

            analyticsProvider.setCustomDateRange(
              DateTimeRange(
                start: DateTime(2026, 11, 1),
                end: DateTime(2026, 11, 26),
              ),
            );
            await tester.pump(const Duration(milliseconds: 150));
            expect(find.text('Generar Reporte Integral'), findsOneWidget);

            // 2. AnalyticsDashboardScreen Poblado + scroll secciones
            currentStage = 'AnalyticsDashboardScreen Populated';
            analyticsProvider.setDataForTesting(_buildRichAnalyticsData());
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.byType(CustomScrollView), findsOneWidget);

            for (int step = 0; step < 5; step++) {
              await tester.drag(
                find.byType(CustomScrollView),
                const Offset(0, -450),
              );
              await tester.pump(const Duration(milliseconds: 250));
            }

            // 3. CommercialRadarCard + selector de región modal + diálogo personalizado
            currentStage = 'CommercialRadarCard Loaded';
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<AuthProvider>.value(
                    value: _MockAuthProvider(),
                  ),
                ],
                child: _wrapWithTextScaler(
                  const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(12),
                      child: CommercialRadarCard(
                        isDark: false,
                        defaultRegion: 'San Juan de Lurigancho, Lima',
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 250));
            await tester.pump(const Duration(milliseconds: 250));
            expect(find.text('Radar Comercial'), findsOneWidget);

            currentStage = 'CommercialRadarCard RegionPicker Modal';
            final regionBtn = find.byIcon(Icons.arrow_drop_down);
            await tester.ensureVisible(regionBtn);
            await tester.tap(regionBtn);
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Enfoque Geográfico'), findsAtLeastNWidgets(1));

            currentStage = 'CommercialRadarCard CustomRegion Dialog';
            final sheetList = find.byType(ListView).last;
            await tester.drag(sheetList, const Offset(0, -350));
            await tester.pump(const Duration(milliseconds: 350));
            final customTile = find.text('Otra / Personalizada...');
            await tester.tap(customTile);
            await tester.pump(const Duration(milliseconds: 350));
            await tester.pump(const Duration(milliseconds: 350));
            expect(find.text('Ciudad o Región'), findsOneWidget);

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
